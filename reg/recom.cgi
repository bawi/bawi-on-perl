#!/usr/bin/perl -w
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-template=>'recom.tmpl', -main_dir=>'reg');

my $cfg = $ui->cfg;
my $dbh = $ui->dbh; 
my $auth = new Bawi::Auth(-cfg=>$cfg, -dbh=>$dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url);
    exit(1);
}

my %form = $ui->form(qw(id name recom));

if ($form{id} && $form{name} && $form{recom}) {
    my $check = 0;
    # check id
    if ($form{id} !~ /^[a-z]([0-9a-z]{2,8})$/) {
        ++$check;
        $ui->tparam(msg=>'아이디는 알파벳 소문자로 시작하고, 알파벳 소문자와 숫자로 된 3-8글자이어야 합니다.');
        $ui->tparam(id=>'');
    } elsif ($auth->exists_id(-id=>$form{id}) == 1) {
        ++$check;
        $ui->tparam(msg=>qq($form{id}는 이미 가입되어 있는 아이디입니다.));
        $ui->tparam(id=>'');
    } elsif ($auth->exists_new_id(-id=>$form{id}) == 0) {
        ++$check;
        $ui->tparam(msg=>qq($form{name} ($form{id})님은 아직 가입신청을 하지 않았습니다. 가입 신청이 완료된 후에 추천해 주세요.));
    } elsif (&is_recommender($form{id}, $auth->id, $form{recom}, $dbh) == 0) {
        ++$check;
        my $recommender = $auth->name . " (" . $auth->id . ")";
        $ui->tparam(msg=>qq(이름/아이디/추천암호가 정확하지 않습니다.<br>확인 후 다시 추천해 주세요.));
    }

    # save to db
    if ($check == 0) {
        my $no = &is_recommender($form{id}, $auth->id, $form{recom}, $dbh);
        my $rv = &recom($no, $dbh);
        $ui->tparam(recommended=>1) if $rv;
    }
}

print $ui->output;

sub is_recommender {
    my ($id, $recom_id, $recom_passwd, $dbh) = @_;
    my $sql = qq(select no from bw_xauth_new_passwd 
                 where id=? && recom_id=? && recom_passwd=?);
    my $rv = $dbh->selectrow_array($sql, undef, $id, $recom_id, $recom_passwd);
    if ($rv) {
        return $rv;
    } else {
        return 0;
    }
}

sub recom {
    my ($no, $dbh) = @_;
    my $sql = qq(update bw_xauth_new_passwd set status='recommended' where no=?);
    my $rv = $dbh->do($sql, undef, $no);
    if ($rv) {
        return $rv;
    } else {
        return 0;
    }
}
