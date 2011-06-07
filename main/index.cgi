#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-template=>'index.tmpl');

my $cfg = $ui->cfg;
my $dbh = $ui->dbh; 
my $auth = new Bawi::Auth(-cfg=>$cfg, -dbh=>$dbh);

$ui->tparam(background_image_URL => $cfg->BackgroundImageURL);
$ui->tparam(login_URL => $cfg->LoginURL);
$ui->tparam(passwd_URL => $cfg->PasswdURL);

if ($auth->auth) {
    $ui->tparam(login=>1);
    $ui->tparam(id=>$auth->id);

    my $uid = $auth->uid;

    my $day = &datediff($dbh,$uid);
    if ($day < 180) {
        $ui->tparam(uptodate=>1);
        print $ui->cgi->redirect("news.cgi"); exit;
    } else {
        $ui->tparam(HTMLTitle => "개인정보 수정안내");
    }
}

print $ui->output;

sub datediff {
    my ($dbh,$uid) = @_;
    my $sql = qq(select datediff(now(), modified ) 
                 from bw_user_basic 
                 where uid=?);
    my $rv = $dbh->selectrow_array($sql, undef, $uid);
    if (defined $rv && $rv >= 0) {
        return $rv;
    } else {
        return 10000;
    }
}

1;
