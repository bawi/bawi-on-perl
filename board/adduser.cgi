#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board::UI;

my $ui = new Bawi::Board::UI(-template=>'adduser.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

$ui->tparam(HTMLTitle => "계정 추가");

if ($auth->uid == 1) {
    $ui->tparam(is_root=>1);
    if ($ui->cparam('add') && $ui->cparam('add') eq '1') {
        my @field = qw(id name email);
        my %f = $ui->form(@field);
        my $check = 0;
        foreach my $i (@field) {
            ++$check unless (exists $f{$i} && $f{$i});
        }
    
        if ($check) {
            $ui->msg(qq(All fields are required.));
        } elsif ($f{id} !~ /^[a-zA-Z]([0-9a-zA-Z])+$/ 
                    || length($f{id}) < 3 || length($f{id}) > 8) {
            $ui->tparam(id=>'');
            $ui->msg(qq(ID must be at least 3-8 characters of alphabet/number starting with an alphabet.));
            ++$check;
        } elsif ($auth->exists_id(-id=>$f{id}) || $auth->exists_new_id(-id=>$f{id})) {
            $ui->tparam(id=>'');
            $ui->msg(qq(<strong>$f{id}</strong> is already registered.));
            ++$check;
        }

        if ($check == 0) {
            my $passwd = $auth->random_passwd; 
            my $rv = $auth->adduser(-id=>$f{id}, 
                                    -name=>$f{name}, 
                                    -passwd=>$passwd, 
                                    -email=>$f{email});
            if ($rv) {
                $ui->msg(qq(<strong>$f{name} ($f{id})</strong> is registered with temporary password '$passwd'.));
                $ui->tparam(id=>'');
                $ui->tparam(name=>'');
                $ui->tparam(email=>'');
                # send mail
                $auth->send_mail(-from=>'Bawi::Board', 
                                 -to=>qq($f{name} <$f{email}>),
                                 -subject=>'Password',
                                 -body=>$passwd,
                                );
            }
        }
    }
} else {
    $ui->msg('Please login as root.');
}

print $ui->output;

1;
