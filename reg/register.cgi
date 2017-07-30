#!/usr/bin/perl -w
use lib '../lib';
use Bawi::Auth;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI(-template=>'register.tmpl', -main_dir=>'reg');

my $cfg = $ui->cfg;
my $dbh = $ui->dbh; 
my $auth = new Bawi::Auth(-cfg=>$cfg, -dbh=>$dbh);

# check id in both existing users & applied users

my @field = qw(id ki name affiliation email birth_year birth_month birth_day recom_id recom passwd1 passwd2 submit);
my %f = $ui->form(@field);

my $recom_ki = 27;
$ui->tparam(recom_ki=>$recom_ki);
my $check = 0;
foreach my $i (@field) {
    ++$check unless (exists $f{$i} && $f{$i});
}

if ($check) { 
    $ui->tparam(msg=>qq(빠진 항목을 모두 입력해 주세요.));
} elsif ($f{passwd1} ne $f{passwd2}) {
    ++$check;
    $ui->tparam(passwd1=>undef);
    $ui->tparam(passwd2=>undef);
    $ui->tparam(msg=>qq(비밀번호가 서로 일치하지 않습니다.));
} elsif ($f{id} !~ /^[a-z]([0-9a-z])+$/ || length($f{id}) < 3 || length($f{id}) > 8) {
    ++$check;
    $ui->tparam(id=>undef);
    $ui->tparam(msg=>qq(아이디는 알파벳 소문자로 시작하고 알파벳 소문자와 숫자로 된 3-8글자이어야 합니다.));
} elsif ($auth->exists_id(-id=>$f{id}) || $auth->exists_new_id(-id=>$f{id})) {
    ++$check;
    $ui->tparam(id=>undef);
    $ui->tparam(msg=>qq($f{id}는 사용할 수 없는 아이디입니다.));
} elsif ($f{email} !~ /^[a-z0-9._%-]+@[a-z0-9.-]+\.[a-z]{2,4}$/) {
    ++$check;
    $ui->tparam(id=>undef);
    $ui->tparam(msg=>qq(이메일 주소가 올바르지 않습니다.));
} elsif ($f{birth_year} !~ /^\d+$/ || $f{birth_year} < 1970) {
    ++$check;
    $ui->tparam(birth_year=>undef);
    $ui->tparam(msg=>qq(생일 연도 형식이 맞지 않습니다.));
} elsif ($f{birth_month} !~ /^\d+$/ || $f{birth_month} < 1 || $f{birth_month} > 12) {
    ++$check;
    $ui->tparam(birth_month=>undef);
    $ui->tparam(msg=>qq(생일 월 형식이 맞지 않습니다.));
} elsif ($f{birth_day} !~ /^\d+$/ || $f{birth_day} < 1 || $f{birth_day} > 31) {
    ++$check;
    $ui->tparam(birth_day=>undef);
    $ui->tparam(msg=>qq(생일 일 형식이 맞지 않습니다.));
} elsif ($auth->exists_id(-id=>$f{recom_id}) == 0) {
    ++$check;
    $ui->tparam(recom_id=>undef);
    $ui->tparam(msg=>qq($f{recom_id}는 천년바위 회원의 아이디가 아닙니다.));
} elsif (&get_ki($f{recom_id}, $dbh) > $recom_ki) {
    ++$check;
    $ui->tparam(recom_id=>undef);
    $ui->tparam(msg=>qq($recom_ki 기 이상만 추천할 수 있습니다.));
} elsif (&is_sshs($f{ki}, $f{name}, $dbh) == 0) {
    ++$check;
    $ui->tparam(ki=>undef);
    $ui->tparam(name=>undef);
    $ui->tparam(msg=>qq($f{name}님은 동창회원 명단에 등록되어있지 않습니다.));
} elsif (&is_sshs($f{ki}, $f{name}, $dbh) <= &is_registered($f{ki}, $f{name}, $dbh) ) {
    ++$check;
    $ui->tparam(msg=>qq($f{name}님은 이미 가입되어 있습니다.<br>webmaster\@bawi.org로 비밀번호를 문의해 주세요.));
} elsif (&is_sshs($f{ki}, $f{name}, $dbh) <= &is_applied($f{ki}, $f{name}, $f{birth_year}, $f{birth_month}, $f{birth_day}, $dbh) ) {
    ++$check;
    $ui->tparam(msg=>qq($f{name}님은 이미 가입신청을 하셨습니다.<br>추천인이 회원추천을 하도록 말씀해주세요.));
}

if ($check == 0) {
    my $birth = sprintf("%4d-%02d-%02d", $f{birth_year}, $f{birth_month}, $f{birth_day});
    my $sql = qq(insert into bw_xauth_new_passwd 
                 (name, id, passwd, recom_id, recom_passwd, ki, 
                 affiliation, email, birth, created) 
                 values (?, ?, ENCRYPT(?), ?, ?, ?, ?, ?, ?, NOW()));
    my $rv = $dbh->do($sql, undef, @f{qw(name id passwd1 recom_id recom ki affiliation email)}, $birth);
    if ($rv) {
        $ui->tparam(registered=>1);
        my $recom_name = &get_name($f{recom_id}, $dbh);
        my $msg = qq(안녕하세요, 바위지기 권형규입니다.\n$f{ki}기 $f{name} ($f{id})님이 가입신청을 했습니다. http://www.bawi.org/reg/recom.cgi 에서 신입회원 추천을 해주세요.);
        $sql = qq(insert into bw_note (from_id, from_name, sent_time, read_time, to_id, to_name, msg) values ('doslove', '권형규', now(), now(), ?, ?, ?));
        $rv = $dbh->do($sql, undef, $f{recom_id}, $recom_name, $msg);
    }
}

print $ui->output;

sub is_sshs {
    my ($ki, $name, $dbh) =@_;
    my $sql = qq(select ki, name from registers where ki=? && name=?);
    my $rv = $dbh->selectall_arrayref($sql, undef, $ki, $name);
    if ($rv) {
        return scalar(@$rv);
    } else {
        return 0;
    }
}

sub is_registered {
    my ($ki, $name, $dbh) =@_;
    my $sql = qq(select a.ki, b.name, b.id from bw_user_ki as a, bw_xauth_passwd as b where a.uid=b.uid && a.ki=? && b.name=?);
    my $rv = $dbh->selectall_arrayref($sql, undef, $ki, $name);
    if ($rv) {
        return scalar(@$rv);
    } else {
        return 0;
    }
}

sub is_applied {
    my ($ki, $name, $birth_year, $birth_month, $birth_day, $dbh) =@_;
    my $birth = sprintf("%4d-%02d-%02d", $birth_year, $birth_month, $birth_day);
    my $sql = qq(select ki, name, id, birth from bw_xauth_new_passwd where ki=? && name=? && birth=?);
    my $rv = $dbh->selectall_arrayref($sql, undef, $ki, $name, $birth);
    if ($rv) {
        return scalar(@$rv);
    } else {
        return 0;
    }
}

sub get_name {
    my ($id, $dbh) = @_;
    my $sql = qq(select name from bw_xauth_passwd where id=?);
    my $rv = $dbh->selectrow_array($sql, undef, $id);
    return $rv;
}

sub get_ki {
    my ($id, $dbh) = @_;
    my $sql = qq(select a.ki from bw_user_ki as a, bw_xauth_passwd as b where a.uid=b.uid && b.id=?);
    my $rv = $dbh->selectrow_array($sql, undef, $id);
    return $rv;
}
