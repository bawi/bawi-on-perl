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
email
im_google
im_msn
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
            if ($i =~ /_map/ && $value !~ /^http:\/\/maps.google.com\/.+q=.+ll=/) {
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
            ++$phone if (length($value) > 5);
            push @phone, [$uid, $i, $value];
        }
        # update only if there is at least one tel number
        @update = (@update, @phone) if ($phone);
        ++$error unless $phone;
        
        my ($y, $m, $d) = map { $ui->cparam($_) || '' } qw(wedding_y wedding_m wedding_d);
        if ($y && $m && $d && $y =~ /\d{4}/ && $m =~ /\d{1,2}/ && $d =~ /\d{1,2}/) {
            $m = "0".$m if ($m =~ /\d{1}/);
            $d = "0".$d if ($d =~ /\d{1}/);
            my $wedding = join("-", $y, $m, $d);
            push @update, [$uid, 'wedding', $wedding];
        } else {
            push @update, [$uid, 'wedding', '0000-00-00'];
        }
        if ($error == 0 && $#update >= 0) {
            foreach my $i (@update) {
                $user->update_user(@$i);
            }
        }
    }
    $ui->tparam(profile=>[$user->get_user($uid)]);
}

print $ui->output;

1;
