#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User::UI;

my $ui = new Bawi::User::UI();
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $dbh = $ui->dbh; 

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}

my $has_photo = $dbh->selectrow_array(qq(select uid from bw_user_photo where uid=?), undef, $auth->uid);
my $id = $ui->cparam('id');

my $photo;
if ($has_photo && $id) {
    my $sql = qq(select a.thumb from bw_user_photo as a, bw_xauth_passwd as b where a.uid=b.uid && b.id=?);
    $photo = $dbh->selectrow_array($sql, undef, $id) ||
        $dbh->selectrow_array(qq(select thumb from bw_user_photo where uid=1));
} else {
    $photo = $dbh->selectrow_array(qq(select thumb from bw_user_photo where uid=0));

}
print $ui->cgi->header(-type=>'image/jpeg', -attachment=>$id, -expires=>'+1m');
print $photo;
1;
