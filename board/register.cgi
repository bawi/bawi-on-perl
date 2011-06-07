#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Board::UI;

my $ui = new Bawi::Board::UI(-template=>'register.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

if ($auth->auth) {
    $ui->tparam(registered=>1);
    $ui->msg('Already registered.');
} elsif($ui->cfg->SelfRegistration) {
    my ($email, $code, $name, $id, $passwd1, $passwd2) 
        = map { $ui->cparam($_) || '' } qw(email code name id passwd1 passwd2);

    if ($email || $code || $name || $id || $passwd1 || $passwd2) {
        if ($code) {
            $ui->tparam(email=>$email);
            if ($code eq crypt($email . $ui->cfg->DBPasswd, $code)) {
                $ui->tparam(step3=>1);
                $ui->tparam(code=>$code);
                if ($name && $id && $passwd1 && $passwd2) {
                    $ui->tparam(id=>$id, name=>$name);
                    if ($passwd1 ne $passwd2) {
                        $ui->msg('Passwords does not match. Please try again.');
                    } elsif ($id !~ /^[a-zA-Z]([0-9a-zA-Z])+$/
                        || length($id) < 3 || length($id) > 8) {
                        $ui->tparam(id=>'');
                        $ui->msg(qq(ID must be at least 3-8 characters of alphabet/number starting with an alphabet.));
                    } elsif ($auth->exists_id(-id=>$id)
                        || $auth->exists_new_id(-id=>$id)) {
                        $ui->msg(qq('$id' is already registered. Please try different one.));
                        $ui->tparam(id=>'');
                    } else {
                        my $uid = $auth->adduser(-id     => $id,
                                                 -name   => $name,
                                                 -passwd => $passwd1,
                                                 -email  => $email
                                                );
                        if ($uid) {
                            $ui->tparam(step4=>1);
                            $ui->tparam(step3=>'');
                            $ui->msg('You are registered. Please login with your ID and password.');
                        } else {
                            $ui->tparam(name=>$name, id=>$id);
                            $ui->msg('Unknown error. Please try again.');
                        }
                    }
                } else {
                    $ui->tparam(name=>$name, id=>$id);
                    $ui->msg('All fields are required.');
                }
            } else {
                $ui->msg('Verification Code is invalid.');
                $ui->tparam(code=>'');
                $ui->tparam(step3=>'');
                $ui->tparam(step2=>1);
            }
        } elsif ($email) {
            $ui->tparam(step2=>1);
            my $seed = join('', ('a'..'z')[rand 26, rand 26]);
            my $code = crypt($email . $ui->cfg->DBPasswd, $seed); 
            my $root = $auth->get_user(-uid=>1);
            my $from = qq($$root{name} <$$root{email}>);
            # send verification
            $auth->send_mail(-from=>$from,
                             -to=>$email,
                             -subject=>'Verification Code',
                             -body=>$code,
                            );
            $ui->tparam(email=>$email);
            $ui->msg("Verification Code sent to your email address.");
        }
    } else {
        $ui->tparam(step1=>1);
    }
} else {
    $ui->tparam(registered=>1);
    $ui->msg(qq(Self-Registration is not allowed.));
}

print $ui->output;
1;
