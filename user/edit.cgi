#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI( -template=>'edit.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

$ui->tparam(menu_profile=>1);
my $uid = $auth->uid;
my $is_root = $uid eq '1' ? 1 : 0;
$ui->tparam(is_root=>$is_root);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

my @field = qw(
ename
affiliation
title
homepage
facebook
twitter
email
im_google
im_nate
im_yahoo
home_address
office_address
temp_address
home_map
office_map
temp_map
greeting
class1
class2
class3
orcid
gscholar
linkedin
);

if ($uid) {
    my $save = $ui->cparam('save') || '';
    if ($save && $save eq '1') {
        my @update;
        my $error = 0;
        foreach my $i (@field) {
            my $field = $i;
            my $value = $ui->cparam($i) || '';
            # save only one address
            if ($i eq 'email' || $i =~ /im_/ || $i eq 'homepage') {
                my @tmp = split(/\s+|,/, $value);
                if ($tmp[0]) {
                    $tmp[0] =~ s/^\s+//g;
                    $tmp[0] =~ s/\s+$//g;
                    $value = $tmp[0];
                }
            }
            if ($i =~ /email|im_/ && $value && ($value !~ /@/ || $value =~ /.+@.+@/) ) {
                ++$error;
            }
            my $len = length($value);
            if ( ($i eq 'affiliation' && $len < 2) || 
                 ($i eq 'email' && ($len < 10 || $value !~ /@/ ) ) ) {
                 ++$error;
            }
            if ($i =~ /_map/ && ($value !~ /^https:\/\/maps.google.com\/.+q=.+ll=/) and ($value !~ /^https:\/\/www.google.com\/maps\/place\//)) {
                $value = '';
            }
            push @update, [$uid, $field, $value] unless ($error);
        }
        my @phone;
        my $phone = 0;
        foreach my $i (qw(mobile_tel home_tel office_tel temp_tel)) {
            my @value;
            foreach my $j (1..4) {
                my $f = $i . $j;
                my $v = $ui->cparam($f) || '';
                $v =~ s/\D//g;
                push @value, $v if ($v);
            }
            my $value = join("-", @value);
            # Reject obvious invalid phone patterns
            if ($value eq '000-0000-0000' ||                    # Default value
                $value =~ /^(\d)\1+-\1+-\1+$/ ||               # Same digit repeated (111-111-1111)
                $value =~ /^0+-0+-0+$/ ||                      # All zeros
                $value =~ /^0123-4567/ ||                      # Sequential pattern
                $value =~ /^1234-5678/) {                      # Sequential pattern
                # Don't count as valid phone
            } else {
                ++$phone if (length($value) > 5);
            }
            push @phone, [$uid, $i, $value];
        }
        # update only if there is at least one tel number
        @update = (@update, @phone) if ($phone);
        ++$error unless $phone;
        
        # Display error message if no valid phone number
        if (!$phone) {
            $ui->tparam(msg => '전화번호를 입력해주세요. 휴대전화, 거주지전화, 직장전화 중 최소 하나는 반드시 입력하셔야 합니다.');
        }
        
        my ($y, $m, $d) = map { $ui->cparam($_) || '' } qw(wedding_y wedding_m wedding_d);
        if ($y && $m && $d && $y =~ /\d{4}/ && $m =~ /\d{1,2}/ && $d =~ /\d{1,2}/) {
            $m = "0".$m if ($m =~ /\d{1}/);
            $d = "0".$d if ($d =~ /\d{1}/);
            my $wedding = join("-", $y, $m, $d);
            push @update, [$uid, 'wedding', $wedding];
        } else {
            push @update, [$uid, 'wedding', '1001-01-01'];
        }
        if ($error == 0 && $#update >= 0) {
            foreach my $i (@update) {
                $user->update_user(@$i);
            }
        }
    }
    my $p = $user->get_user($uid);
    # own edit page: always show own careers (profile.cgi gates viewers, not owners)
    $$p{career} = $user->get_career($uid);
    $ui->tparam(profile=>[$p]);
    $ui->tparam(has_affiliation=>$user->has_affiliation($auth->uid));
    $ui->tparam(has_phone=>$user->has_phone($auth->uid));
}

print $ui->output;

1;
