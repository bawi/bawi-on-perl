#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-main_dir=>'admin');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth_admin) {
    print $auth->access_denied($ui->cgiurl);
    exit(1);
}
$ui->init(-template=>'passwd.tmpl');
my $dbh = $ui->dbh;

my $admin = $auth->name;
my $new_passwd = &new_passwd;


my %f = $ui->form(qw(id action));

if ($f{id}) {
    my $user = &user_info($f{id});
    if ($user) {
        $ui->tparam(user=>$user);
        my ($name, $email, $uid) = ($$user[0]->{name}, $$user[0]->{email}, $$user[0]->{uid});
        my %result = ( to => "$name &lt;$email&gt;" );

        my %mail = (
www     => {
        subject => '천년바위 웹서비스 비밀번호 재설정',
        body => qq(비밀번호를 '$new_passwd'로 변경했으니, 접속해서 다른 것으로 변경한 뒤 이용하시기 바랍니다. ),
},
bawimail   => {
        subject => '천년바위 이메일계정 설정',
        body => qq(신청하신 천년바위 이메일 계정이 생성되었습니다. 아이디는 천년바위 아이디와 동일하며, 비밀번호는  입니다. http://mail.bawi.org 로 접속하시면 됩니다. ),
},
confirm => {
        subject => '천년바위 본인 확인',
        body => qq(천년바위에서는 본인임을 확인하기 위해 천년바위 개인정보에 등록된 이메일 주소를 사용합니다. 천년바위 개인정보에 등록된 $email 의 이메일 주소로 비밀번호 안내 메일을 보내드렸습니다.

위의 이메일 주소를 사용하지 않으신다면, 이 메일을 천년바위의 다른 회원에게 포워딩하여 바위지기에게 다시 전송해달라고 부탁하시면 됩니다. 다른 회원을 통하여 본인임이 확인되면 비밀번호 변경 안내메일을 보내드립니다. (아이디 도용 등의 문제를 막기 위한 것입니다. 귀찮으시더라도 천년바위의 보안을 지키기 위한 최소한의 조치이니 양해 부탁드립니다.) ),
},
    infodate => {
        subject => '천년바위 개인정보 date reset',
        body => qq(천년바위의 개인정보는 상호주의에 기반하여 회원 상호간에 공개되는 정보입니다. 개인정보를 적절하게 입력해주시기 바랍니다. ),
},
        );

        if ($f{action}) {
            my ($to, $subject, $body, $sendmail) 
                = map { $ui->cparam($_) || '' } qw(to subject body sendmail);
            if ($sendmail eq '1' && $to && $subject && $body) {
                &send_mail($to, $subject, $body);
                $ui->tparam(sent=>1);
            } else {
                if ($f{action} eq 'www') {
                    &reset_www($f{id}, $new_passwd);
                    $user = &user_info($f{id});
                    $$user[0]->{raw} = crypt($new_passwd, $$user[0]->{passwd});
                    $ui->tparam(user=>$user);
                } elsif ($f{action} eq 'infodate') {
                    &reset_infodate($uid);
                    $user = &user_info($f{id});
                    $ui->tparam(user=>$user);
                }
                $result{subject} = $mail{$f{action}}->{subject};
                $result{admin} = $admin;
                $result{body} = $mail{$f{action}}->{body};
                $ui->tparam(result=>[\%result]);
            }
        }
    }
}

print $ui->output;

sub user_info {
    my $id = shift;
    my $sql = qq(select a.id, a.name, a.accessed, a.access, a.modified,
                        a.email, c.ki, a.passwd, a.uid
                 from bw_xauth_passwd as a, 
                      bw_user_ki as c
                 where a.uid=c.uid && (a.id=? || a.name=?));
    my $rv = $dbh->selectrow_hashref($sql, undef, $id, $id);
    my $sql2 = qq(select b.modified
                 from bw_xauth_passwd as a, bw_user_basic as b
                 where a.uid=b.uid && (a.id=? || a.name=?));
    my $rv2 = $dbh->selectrow_hashref($sql2, undef, $id, $id);
    my $new_rv = { %$rv, info_modified => $rv2->{modified} };
    my @rv = ($new_rv);
    return \@rv;
}

sub reset_www {
    my ($id, $passwd) = @_;
    my $sql = qq(update bw_xauth_passwd set passwd=encrypt(?), 
                 modified='1001-01-01 00:00:00' where id=?);
    my $rv = $dbh->do($sql, undef, $passwd, $id);
    if ($rv) { return 1; }
    else { return 0; }
}

sub reset_bawimail {
    my ($id) = @_;

}

sub reset_infodate {
    my ($uid) = @_;
    my $sql = qq(update bw_user_basic set modified='1001-01-01 00:00:00' where uid=?);
    my $rv = $dbh->do($sql, undef, $uid);
    if ($rv) { return 1; }
    else { return 0; }
}

sub new_passwd {
    my $rv = join("", ('a'..'z')[rand 26, rand 26, rand 26,, rand 26, rand 26, rand 26, rand 26]);
    return $rv;
}

sub send_mail {
    my ($to, $subject, $body) = @_;

	open(SENDMAIL, "|/usr/lib/sendmail -oi -t")
		or die "Can't fork for sendmail: $!\n";
	print SENDMAIL <<"EOF";
From: Bawi Webmaster <webmaster\@bawi.org>
To: $to
Bcc: Bawi Webmaster <webmaster\@bawi.org>
Subject: $subject
Content-type: text/plain; charset=utf-8

$body
EOF
	close(SENDMAIL) or warn "sendmail didn't close nicely";

}

1;
