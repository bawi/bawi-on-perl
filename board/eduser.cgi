#!/usr/bin/perl -w
use strict;
use lib '../lib';

use Bawi::Auth;
use Bawi::Board::UI;

use Digest::MD5 qw(md5_base64);

my $ui = new Bawi::Board::UI(-template=>'eduser.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}

my $t = $ui->template;

my $uid = $auth->uid || 0;
my $is_root = $uid == 1 ? 1 : 0;
$t->param(is_root=>$is_root);

# get uid from CGI only if is_root, otherwise, get uid from Auth
if ($is_root) {
    my $c_uid = $ui->cparam('uid') || 0;
    if ($c_uid && $c_uid =~ /^\d+$/) {
        $uid = $c_uid;
        $t->param(uid=>$uid) unless ($uid == 1);
    }
}

my $seed = $ui->cfg->DBPasswd . $ui->cfg->AttachDir|| '';
my $user = $auth->get_user(-uid=>$uid);
if ($user) {
    my $email = $$user{email} || '';
    if ($email) {
        my $code = md5_base64($email, $seed); 
        $$user{code} = $code;
    }
    $$user{is_root} = $is_root;
} else {
    $ui->msg(qq(User does not exist.));
}
my $save = $ui->cparam('save') || 0;
if ($save && $save eq '1' && $user) {
    my ($email, $code) = map { $ui->cparam($_) || ''} qw(email code);
    my ($name, $id) = map { $ui->cparam($_) || $user->{$_} || ''} qw(name id)
        if ($is_root);
    if ($email) {
        my $e_code = md5_base64($email, $seed);
        if ( ($code && $code eq $e_code) || $is_root) { # email verified, save
            my $rv = $auth->eduser(-uid   => $user->{uid},
                                   -id    => $id,
                                   -name  => $name,
                                   -email => $email);
            if ($rv && $rv eq '1') {
                my $rv = $auth->get_user(-uid=>$uid);
                $$user{id} = $$rv{id};
                $$user{name} = $$rv{name};
                $$user{email} = $$rv{email};
                $$user{modified} = $$rv{modified};
                $ui->msg(qq(Saved.));
            } else {
                $ui->msg(qq(Error. Not saved.));
            }
        } else { # email not verified, send code
            $$user{email} = $email;
            $$user{code} = '';
            $ui->msg(qq(Email is not verified. Email code is sent to '$email'.));
        }
    } else { # no email
        $$user{email} = '';
        $$user{code} = '';
        $ui->msg(qq(Email is required.));
    }
}

$t->param(user=>[$user]) if ($user);

print $ui->output;
1;
