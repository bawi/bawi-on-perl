#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-template=>'login.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

$ui->tparam(background_image_URL => $ui->cfg->BackgroundImageURL);

my ($id, $passwd, $permanent, $simultaneous,
    $url, $error) = map { $ui->cparam($_) || "" } 
                    qw(id passwd permanent simultaneous url);
$url = $auth->success_url unless ($url);
$simultaneous = "" unless $auth->is_admin($id);
warn("id=$id,simul=$simultaneous");

if ($auth->auth) {
    print $ui->cgi->redirect($url);
} else {
    if ($id && $passwd && $ui->cgi->request_method() eq 'POST') {
        my $login = $auth->login(-id=>$id, -passwd=>$passwd,
                                 -permanent=>$permanent,
                                 -simultaneous=>$simultaneous);
warn("id=$id,simul=$simultaneous");
        if ($login > 0) {
            my %cookie = %{ $auth->session_cookie };
            $cookie{-value} = $auth->session_key;
            delete $cookie{-expires} 
                unless ($ui->cfg->KeepLogin && $permanent && $permanent eq "1");
            my $cookie = $ui->cgi->cookie(%cookie);
            if ($login == 2) { # passwd is expired.
                $url = $auth->passwd_url . "?expired=1";
            }
            print $ui->cgi->redirect(-cookie=>$cookie, -uri=>$url);
        } else {
            $ui->tparam(id=>$id);
            $ui->msg('Incorrect ID/Password.');
            $ui->tparam(url=>$url);
            $ui->tparam(KeepLogin=>$ui->cfg->KeepLogin);
            $ui->tparam(SelfRegistration=>$ui->cfg->SelfRegistration);
            print $ui->output;
        }
    } else {
      $ui->tparam(url=>$url);
      $ui->tparam(KeepLogin=>$ui->cfg->KeepLogin);
      $ui->tparam(SelfRegistration=>$ui->cfg->SelfRegistration);
      print $ui->output;
    }
}
1;
