#!/usr/bin/perl -w
use strict;
use lib '../lib';

use Bawi::Auth;
use Bawi::Main::UI;
use Bawi::User;

my $ui = new Bawi::Main::UI(-main_dir=>'admin', -template=>'organizations.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit(1);
}

unless ($auth->is_admin) {
    print $auth->access_denied($ui->cgiurl);
    exit(1);
}

$ui->tparam(HTMLTitle => "경력기관 관리");
$ui->tparam(id=>$auth->id);
$ui->tparam(is_admin=>$auth->is_admin);

my $user = new Bawi::User(-ui=>$ui);

if ($ui->cgi->request_method && $ui->cgi->request_method eq 'POST') {
    my ($action, $from, $to, $org_id, $alias) = map { $ui->cparam($_) || '' } qw(action org_from org_to org_id alias);
    if ($action eq 'merge') {
        if ($from && $to && $from ne $to) {
            $user->org_merge($from, $to);
            $ui->msg('기관을 병합했습니다.');
        } else {
            $ui->msg('서로 다른 기관을 선택해주세요.');
        }
    } elsif ($action eq 'add_alias') {
        if ($org_id && $alias) {
            $user->org_add_alias($org_id, $alias);
            $ui->msg('별칭을 추가했습니다.');
        } else {
            $ui->msg('기관과 별칭을 입력해주세요.');
        }
    } elsif ($action eq 'del_alias') {
        if ($org_id && $alias) {
            my $rv = $user->org_del_alias($org_id, $alias);
            $ui->msg($rv && $rv ne '0E0' ? '별칭을 삭제했습니다.' : '마지막 별칭은 삭제할 수 없습니다.');
        } else {
            $ui->msg('기관과 별칭을 입력해주세요.');
        }
    }
}

$ui->tparam(orgs=>$user->org_list);

print $ui->output;

1;
