#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Main::UI;
use Bawi::Auth;

my $ui = new Bawi::Main::UI( -main_dir=>'admin');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $dbh = $ui->dbh; 

unless ($auth->auth) {
    print $auth->login_page;
    exit(1);
}

my $has_photo = $dbh->selectrow_array(qq(select uid from bw_user_photo where uid=?), undef, $auth->uid);
my $id = $ui->cparam('id');

my $photo;
if ($has_photo && $id) {
    my $sql = qq(select a.photo from bw_user_photo as a, bw_xauth_passwd as b where a.uid=b.uid && b.id=?);
    $photo = $dbh->selectrow_array($sql, undef, $id) ||
        $dbh->selectrow_array(qq(select photo from bw_user_photo where uid=0));
} else {
    $photo = $dbh->selectrow_array(qq(select photo from bw_user_photo where uid=0));

}
print $ui->cgi->header(-type=>'image/jpeg', -expires=>'-1d');
print $photo;
1;
