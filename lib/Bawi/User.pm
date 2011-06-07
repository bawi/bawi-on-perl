package Bawi::User;

use 5.006;
use strict;
use warnings;

require Exporter;

our $VERSION = '0.01';

my (%OPT, %TBL, $DBH);

%TBL = (
passwd     => 'bw_xauth_passwd',
session    => 'bw_xauth_session',
new_passwd => 'bw_xauth_new_passwd',
sig        => 'bw_user_sig',
);

sub new {
    my ($class, %arg) = @_;

    my $ui = $arg{-ui};
    $DBH = $ui->dbh;
    bless {
        ui => $ui,
    }, $class;
}

sub DESTROY {
    my $self = shift;
    $DBH->disconnect if defined $DBH;
    $DBH = undef;
}

sub ui {
    my $self = shift;
    if (@_) { $self->{ui} = shift }
    return $self->{ui};
}

sub note {
    my ($self, $from_id, $from_name, $msg, $id) = @_;
    $msg = "[단체쪽지] $msg";
    my $id_list = "'" . join("', '", @$id) . "'";
    my $sql = qq(insert into bw_note (sent_time, read_time, from_id, from_name, msg, to_id, to_name) select now(), now(), '$from_id', '$from_name', ?, id, name from bw_xauth_passwd where id in ($id_list));
    my $rv = $DBH->do($sql, undef, $msg);
    return $rv;
}

sub modified {
    my ($self, $uid) = @_;
    my $sql = qq(update bw_user_basic set modified=now() where uid=?);
    my $rv = $DBH->do($sql, undef, $uid);
    return $rv;
}

sub update_user {
    my ($self, $uid, $field, $value) = @_;
    $value = $self->ui->cgi->escapeHTML($value);
    my $table = $field eq 'email' ? 'bw_xauth_passwd' : 'bw_user_basic';
    my $sql = qq(update $table set modified=now(), $field=? where uid=?);
    my $rv = $DBH->do($sql, undef, $value, $uid);
    return $rv;
}

sub add_count {
    my ($self, $uid) = @_;
    my $sql = qq(update bw_user_basic set count=count+1, count_today=count_today+1, modified=modified where uid=?);
    my $rv = $DBH->do($sql, undef, $uid);
    return $rv;
}

sub get_total_count {
    my ($self) = @_;
    my $sql = qq(select sum(count) from bw_user_basic);
    my $rv = $DBH->selectrow_array($sql);
    return $rv;
}

sub get_total_count_today {
    my ($self) = @_;
    my $sql = qq(select sum(count_today) from bw_user_basic);
    my $rv = $DBH->selectrow_array($sql);
    return $rv;
}

sub get_user {
    my ($self, $uid) = @_;
    my $sql = qq(select a.uid, a.name, a.id, b.ki, c.ename, c.affiliation, c.title, 
                        DATE_FORMAT(a.accessed, "%Y-%m") as accessed,
                        c.death, a.email, c.homepage, c.birth, c.mobile_tel, 
                        c.home_tel, c.office_tel, c.temp_tel,  
                        c.wedding, c.home_address,
                        c.office_address, c.temp_address,
                        c.home_map, c.office_map, c.temp_map, c.greeting, 
                        c.class1, c.class2, c.class3,
                        c.im_msn, c.im_nate, c.im_yahoo, c.im_google,
						c.twitter, c.facebook,
                        date_format(c.modified, "%Y-%m-%d") as modified
                 from bw_xauth_passwd as a, bw_user_ki as b, bw_user_basic as c
                 where a.uid=b.uid && a.uid=c.uid && a.uid=?);
    my $p = $DBH->selectrow_hashref($sql, undef, $uid);
    delete $$p{uid};
    if ($$p{wedding} ne '0000-00-00') {
        my @d = split(/-/, $$p{wedding});
        $$p{wedding_y} = $d[0];
        $$p{wedding_m} = $d[1];
        $$p{wedding_d} = $d[2];
    }
    delete $$p{wedding};
    delete $$p{death} if ($$p{death} eq '0000-00-00');

    foreach my $t (qw(home mobile office temp)) {
        my $tel = $t . "_tel";
        if ($$p{$tel}) {
            my @t = split(/-/, $$p{$tel});
            foreach my $i (qw(4 3 2 1 )) {
                $$p{"$tel$i"} = pop @t;
            }
        }
        delete $$p{$t . "_tel"}; 
    }
    foreach my $c (1..3) {
        delete $$p{"class$c"} unless $$p{"class$c"};
    }
    $$p{degree} = $self->get_degree($uid);
    $$p{major} = $self->get_major($uid);
    $$p{circle} = $self->get_circle($uid);
    return $p;
}
sub has_phone {
    my ($self, $uid) = @_;
    my $sql = qq(select length(concat(mobile_tel, home_tel, office_tel )) as has_tel from bw_user_basic where uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_phone = $rv && $rv > 6 ? 1 : 0;
    return $has_phone;
}

sub has_address {
    my ($self, $uid) = @_;
    my $sql = qq(select length(concat(home_address, office_address)) as has_address from bw_user_basic where uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_address = $rv && $rv > 25 ? 1 : 0;
    return $has_address;
}

sub user_ki {
    my ($self, $ki) = @_;
    my $sql = qq(select a.ki, b.name, b.id 
                 from bw_user_ki as a, bw_xauth_passwd as b 
                 where a.uid=b.uid && a.ki=?);
    my $rv = $DBH->selectall_hashref($sql, 'id', undef, $ki);
    my @rv = map { $$rv{$_} }
                sort { $$rv{$a}->{name} cmp $$rv{$b}->{name} }
                    keys %$rv;
    return \@rv;
}

sub ki_list {
    my ($self, $ki) = @_;
    my $sql = qq(select a.ki, count(*) as count 
                 from bw_user_ki as a, bw_xauth_passwd as b 
                 where a.uid=b.uid && a.ki > 0 
                 group by ki);
    my $rv = $DBH->selectall_hashref($sql, 'ki');
    my @rv = map {$$rv{$_}->{current} = $ki eq $_ ? 1 : 0; $$rv{$_} }
                sort { $$rv{$a}->{ki} <=> $$rv{$b}->{ki} }
                    keys %$rv;
    return \@rv;
}

sub get_class {
    my ($self, $ki, $grade, $class) = @_;
    my $sql = qq(select a.ki, b.id, b.name from bw_user_ki as a, bw_xauth_passwd as b, bw_user_basic as c where a.uid=b.uid && b.uid=c.uid && a.ki=? && c.class$grade=?);
    my $rv = $DBH->selectall_hashref($sql, 'id', undef, $ki, $class);
    my @rv = map { $$rv{$_} }
                sort { $$rv{$a}->{name} cmp $$rv{$b}->{name} }
                    keys %$rv;
    return \@rv;
}

sub has_class {
    my ($self, $uid) = @_;
    my $sql = qq(select class1, class2, class3 from bw_user_basic where uid=?);
    my @rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_class= $rv[0] || $rv[1] || $rv[2] ? 1 : 0; 
    return $has_class;
}

sub is_class {
    my ($self, $uid, $ki, $grade, $class) = @_;
    my $sql = qq(select a.uid 
                 from bw_xauth_passwd as a, bw_user_ki as b, bw_user_basic as c 
                 where a.uid=b.uid && b.uid=c.uid && a.uid=? && b.ki=? && 
                       c.class$grade = ?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid, $ki, $class);
    if ($rv && $rv eq $uid) {
        return 1;
    } else {
        return 0;
    }
}

sub circle_member {
    my ($self, $cid) = @_;
    my $sql = qq(select c.ki, a.circle_id, b.name, b.id 
                 from bw_user_circle as a, bw_xauth_passwd as b, bw_user_ki as c
                 where a.uid=b.uid && b.uid=c.uid && a.circle_id=?);
    my $rv = $DBH->selectall_hashref($sql, 'id', undef, $cid);
    my @rv = map { $$rv{$_} }
                sort { $$rv{$a}->{ki} <=> $$rv{$b}->{ki} ||
                       $$rv{$a}->{name} cmp $$rv{$b}->{name} }
                    keys %$rv;
    return \@rv;
}

sub add_circle_member {
    my ($self, $cid, $uid) = @_;
    my $sql = qq(replace into bw_user_circle (circle_id, uid) values (?,?));
    my $rv = $DBH->do($sql, undef, $cid, $uid);
    return $rv;
}

sub del_circle_member {
    my ($self, $cid, $uid) = @_;
    my $sql = qq(delete from bw_user_circle where circle_id=? && uid=?);
    my $rv = $DBH->do($sql, undef, $cid, $uid);
    return $rv;
}

sub get_circle {
    my ($self, $uid) = @_;
    my $sql = qq(select a.id as circle_id, a.name from circles as a, bw_user_circle as b where a.id=b.circle_id && b.uid=?);
    my $rv = $DBH->selectall_hashref($sql, 'circle_id', undef, $uid);
    my @rv = map { $$rv{$_} }
                 sort { $$rv{$a}->{name} cmp $$rv{$b}->{name} }
                    keys %$rv;
    return \@rv;
}

sub get_degree {
    my ($self, $uid) = @_;

    my $sql = qq(select degree_id, a.type, b.id as school_id, b.full_name as school, b.brief_name as school_short, a.department, a.advisors, date_format(a.start_date,"%Y-%m") as start_date, date_format(a.end_date, "%Y-%m") as end_date, a.status as status from bw_user_degree as a, schools as b where a.school_id=b.id && a.uid=?);
    my $d = $DBH->selectall_hashref($sql, 'degree_id', undef, $uid);
    if ($d) {
        my @degree = 
            map {
                $$d{$_}->{end_date} =~ s/0000-00/현재/g;
                $$d{$_}->{type_brief} = "학사" if $$d{$_}->{type} eq "Bachelor";
                $$d{$_}->{type_brief} = "석사" if $$d{$_}->{type} eq "Master";
                $$d{$_}->{type_brief} = "박사" if $$d{$_}->{type} eq "Doctor";
                $$d{$_}->{status_brief} = "재학" if $$d{$_}->{status} eq "attending";
                $$d{$_}->{status_brief} = "졸업" if $$d{$_}->{status} eq "graduated";
                $$d{$_}->{status_brief} = "수료" if $$d{$_}->{status} eq "course_completed";
                $$d{$_}->{status_brief} = "입학예정" if $$d{$_}->{status} eq "admitted";
                $$d{$_}->{status_brief} = "기타" if $$d{$_}->{status} eq "other";
                $$d{$_}
            } sort {
                $$d{$a}->{start_date} cmp $$d{$b}->{start_date}
            } keys %$d;
        return \@degree;
    }

}

sub get_major {
    my ($self, $uid) = @_;

    my $sql = qq(select a.major, a.major_id, a.parent_id from bw_data_major as a, bw_user_major as b where a.major_id=b.major_id && b.uid=?);

    my $m = $DBH->selectall_arrayref($sql, undef, $uid);
    if ($m) {
        my @major = map {{ major=>$$_[0], major_id=>$$_[1], parent_id=>$$_[2] }} @$m;
        return \@major;
    }
}
sub has_photo {
    my ($self, $uid) = @_;
    my $sql = qq(select uid from bw_user_photo where uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_photo = $rv ? 1 : 0;
    return $has_photo;
}

sub has_im {
    my ($self, $uid, $type) = @_;
    my $sql = qq(select im_$type from bw_user_basic where im_$type !='' && uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_im = $rv ? 1 : 0;
    return $has_im;
}
sub has_twitter {
    my ($self, $uid, $type) = @_;
    my $sql = qq(select twitter from bw_user_basic where twitter !='' && uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_twitter = $rv ? 1 : 0;
    return $has_twitter;
}
sub has_facebook {
    my ($self, $uid, $type) = @_;
    my $sql = qq(select facebook from bw_user_basic where facebook !='' && uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_facebook = $rv ? 1 : 0;
    return $has_facebook;
}
sub has_circle {
    my ($self, $uid) = @_;
    my $sql = qq(select count(*) from bw_user_circle where uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_circle = $rv ? 1 : 0;
    return $has_circle;
}

sub has_major {
    my ($self, $uid) = @_;
    my $ki = $self->ki($uid);
    my $max_ki = $self->max_ki;
    my $sql = qq(select count(*) from bw_user_major where uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_major = $rv || $max_ki - $ki < 5 ? 1 : 0;
    return $has_major;
}

sub has_degree {
    my ($self, $uid) = @_;
    my $ki = $self->ki($uid);
    my $max_ki = $self->max_ki;
    my $sql = qq(select count(*) from bw_user_degree where uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    my $has_degree = $rv || $max_ki - $ki < 5 ? 1 : 0;
    return $has_degree;
}

sub max_ki {
    my ($self) = @_;
    my $sql = qq(select max(ki) from bw_user_ki);
    my $rv = $DBH->selectrow_array($sql);
    return $rv;
}

sub ki {
    my ($self, $uid) = @_;
    my $sql = qq(select ki from bw_user_ki where uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    return $rv;
}

sub degree_set {
    my ($self, $uid) = @_;
    my $sql = qq(select * from bw_user_degree where uid=?);
    my $rv = $DBH->selectall_hashref($sql, 'degree_id', undef, $uid);
    my @rv;
    push @rv, { school_list => $self->school_list,
                start_year  => $self->year_list,
                end_year  => $self->year_list,
                start_month  => $self->month_list,
                end_month  => $self->month_list,
              };
    foreach my $i (sort { $$rv{$a}->{start_date} cmp $$rv{$b}->{start_date} } 
                       keys %$rv) {
        my %d = %{ $$rv{$i} };
        my @s = split(/-/, $d{start_date});
        my @e = split(/-/, $d{end_date});
        my %rv = (
            degree_id   => $d{degree_id},
            "$d{type}"  => 1,
            school_list => $self->school_list(-school_id=>$d{school_id}),
            department  => $d{department},
            advisors    => $d{advisors},
            content     => $d{content},
            start_year  => $self->year_list(-current=>$s[0]),
            end_year    => $self->year_list(-current=>$e[0]),
            start_month => $self->month_list(-current=>$s[1]),
            end_month   => $self->month_list(-current=>$e[1]),
            "$d{status}"  => 1,
        );
        push @rv, \%rv;
    }
    return \@rv;
}

sub year_list {
    my ($self, %arg) = @_;
    my $year = exists $arg{-current} ? $arg{-current} : '';
    my $current_year = (localtime)[5] + 1900;
    my @year = map {
                        my $c = $year eq $_ ? 1 : 0;
                        my $y2 = $_ eq '0000' ? '현재' : "$_년";
                        { year=>$_, year2=>$y2, current=>$c}
                   } reverse (1991 .. $current_year, '0000');
    return \@year;
}

sub month_list {
    my ($self, %arg) = @_;
    my $month = exists $arg{-current} ? $arg{-current} : '';
    my @month = map {
                      my $m1 = sprintf("%02d", $_);
                      my $c = $month eq $m1 ? 1 : 0;
                      my $m2 = $_ == 0 ? '현재' : "$_월";
                      { month=>$m1, month2=>$m2, current=>$c }
                    } 0 .. 12;
    return \@month;
}

sub school_list {
    my ($self, %arg) = @_;
    my $school_id = exists $arg{-school_id} ? $arg{-school_id} : '';
    my $sql = qq(select id as school_id, full_name from schools);
    my $rv = $DBH->selectall_hashref($sql, 'school_id');
    my @rv = map { $$rv{$_}->{current} = $school_id eq $_ ? 1 : 0; $$rv{$_} }
                sort { $$rv{$a}->{full_name} cmp $$rv{$b}->{full_name} }
                    keys %$rv;
    return \@rv;
}
sub degree {
    my ($self, $uid, $did) = @_;
    my $sql = qq(select * from bw_user_degree where uid=? && degree_id=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $uid, $did);
    return $rv;
}

sub update_degree {
    my ($self, @field) = @_;
    my $sql = qq(replace into bw_user_degree
                 (degree_id, uid, type, school_id, department, advisors, content,start_date,end_date, status) 
                 value (?, ?, ?, ?, ?, ?, ?, ?, ?, ?));
    my $rv = $DBH->do($sql, undef, @field);
    return $rv;
}

sub add_degree {
    my ($self, @field) = @_;
    my $sql = qq(insert into bw_user_degree
                 (uid, type, school_id, department, advisors, content,start_date,end_date, status) 
                 value (?, ?, ?, ?, ?, ?, ?, ?, ?));
    my $rv = $DBH->do($sql, undef, @field);
    return $rv;
}

sub del_degree {
    my ($self, $uid, $degree_id) = @_;
    my $sql = qq(delete from bw_user_degree where uid=? && degree_id=?);
    my $rv = $DBH->do($sql, undef, $uid, $degree_id);
    return $rv;
}

sub is_circle_member {
    my ($self, $cid, $uid) = @_;
    my $sql = qq(select uid from bw_user_circle where circle_id=? && uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $cid, $uid);
    if ($rv) {
        return 1;
    } else {
        return 0;
    }
}

sub im_list_msn_ki {
    my ($self, $ki) = @_;
    my $sql = qq(select a.im_msn 
                 from bw_user_basic as a, bw_user_ki as b
                 where a.uid=b.uid && a.im_msn != '' && b.ki=?);
    my $rv = $DBH->selectall_arrayref($sql, undef, $ki);
    my @rv = map { { contact => $$_[0] } } @$rv;
    return \@rv;
}

sub im_list_msn_circle {
    my ($self, $circle_id) = @_;
    my $sql = qq(select a.im_msn 
                 from bw_user_basic as a, bw_user_circle as b
                 where a.uid=b.uid && a.im_msn != '' && b.circle_id=?);
    my $rv = $DBH->selectall_arrayref($sql, undef, $circle_id);
    my @rv = map { { contact => $$_[0] } } @$rv;
    return \@rv;
}

sub circle_list {
    my ($self, $cid) = @_;
    my $sql = qq(select a.id as circle_id, count(*) as count
                 from circles as a, bw_user_circle as b 
                 where a.id=b.circle_id
                 group by a.id);
    my $count = $DBH->selectall_hashref($sql, 'circle_id');
    $sql = qq(select a.id as circle_id, a.name
                 from circles as a
                 group by a.id);
    my $rv = $DBH->selectall_hashref($sql, 'circle_id');
    my @rv = map { $$rv{$_}->{current} = $cid eq $_ ? 1 : 0; 
                   $$rv{$_}->{count} = $$count{$_}->{count} || 0;
                   $$rv{$_} }
                sort { $$rv{$a}->{name} cmp $$rv{$b}->{name} }
                    keys %$rv;
    return \@rv;
}

sub modified_user {
    my ($self) = @_;
    my $sql = qq(select a.ki, b.id, b.name, c.greeting, c.im_msn, c.modified,
                        date_format(c.modified, "%m/%d %H:%i") as f_modified,
                        c.affiliation, c.title
                 from bw_user_ki as a, bw_xauth_passwd as b, bw_user_basic as c
                 where a.uid=b.uid && b.uid=c.uid && 
                       c.modified > DATE_SUB(NOW(), INTERVAL 24 HOUR)
                 order by modified desc);
    my $rv = $DBH->selectall_hashref($sql, 'id');
    my @rv = map { $$rv{$_}->{modified} = $$rv{$_}->{f_modified}; 
                   delete $$rv{$_}->{f_modified}; $$rv{$_} }
                 sort { $$rv{$b}->{modified} cmp $$rv{$a}->{modified} ||
                        $$rv{$a}->{ki} <=> $$rv{$b} ||
                        $$rv{$a}->{name} <=> $$rv{$b}->{name} }
                    keys %$rv;
    return \@rv;
}

sub get_guestbook_count {
    my ($self, $uid) = @_;
    my $sql = qq(select count(*) from bw_user_gbook where uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    return $rv;
}

sub get_left_guestbook_count {
    my ($self, $uid) = @_;
    my $sql = qq(select count(*) from bw_user_gbook where guest_uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $uid);
    return $rv;
}

sub add_guestbook {
    my ($self, $uid, $guest_uid, $body) = @_;
    my $sql = qq(insert into bw_user_gbook (uid, guest_uid, body, created)
                 values (?, ?, ?, now()));
    my $rv = $DBH->do($sql, undef, $uid, $guest_uid, $body);
    return $rv;
}

sub add_guestbook_reply {
    my ($self, $gbook_id, $reply) = @_;
    my $sql = qq(update bw_user_gbook set reply=? where gbook_id = ?);
    my $rv = $DBH->do($sql, undef, $reply, $gbook_id);
    return $rv;
}

sub del_guestbook {
    my ($self, $gbook_id, $guest_uid) = @_;
    my $sql = qq(delete from bw_user_gbook 
                 where gbook_id=? && guest_uid=? && reply='');
    my $rv = $DBH->do($sql, undef, $gbook_id, $guest_uid);
    return $rv;
}

sub del_guestbook_reply {
    my ($self, $gbook_id, $guest_uid) = @_;
    my $sql = qq(update bw_user_gbook set reply='' where gbook_id=? && uid=?);
    my $rv = $DBH->do($sql, undef, $gbook_id, $guest_uid);
    return $rv;
}

sub get_guestbookset {
    my ($self, $uid, $guest_uid, $page) = @_;
    my $gbook_per_page = 5; 
    my $start = ($page - 1) * $gbook_per_page;
    my $sql = qq(select c.ki, a.name, a.id, b.gbook_id, b.body, b.reply, 
                        b.created, b.guest_uid, b.uid, $page as page
                 from bw_xauth_passwd as a, bw_user_gbook as b, bw_user_ki as c
                 where a.uid=b.guest_uid && c.uid=b.guest_uid && b.uid=? 
                 order by gbook_id desc limit $start, $gbook_per_page);
    my $rv = $DBH->selectall_hashref($sql, 'gbook_id', undef, $uid);
    my @rv = map { $$rv{$_}->{is_guest} = $guest_uid == $$rv{$_}->{guest_uid} ? 1 : 0; 
                   delete $$rv{$_}->{guest_uid}; 
                   $$rv{$_}->{is_owner} = $guest_uid == $uid ? 1 : 0;
                   $$rv{$_}->{body} =~ s/\n/<br>/g;
                   $$rv{$_}->{reply} =~ s/\n/<br>/g;
                   $$rv{$_} }
                sort { $$rv{$b}->{gbook_id} <=> $$rv{$a}->{gbook_id} }
                    keys %$rv;
    return \@rv;
}

sub get_left_guestbookset {
    my ($self, $uid, $guest_uid, $page) = @_;
    my $gbook_per_page = 5; 
    my $start = ($page - 1) * $gbook_per_page;
    my $sql = qq(select c.ki, a.name, a.id, b.gbook_id, b.body, b.reply, 
                        b.created, b.guest_uid, b.uid, $page as page, 
                        1 as 'left'
                 from bw_xauth_passwd as a, bw_user_gbook as b, bw_user_ki as c
                 where a.uid=b.uid && c.uid=b.uid && b.guest_uid=? 
                 order by gbook_id desc limit $start, $gbook_per_page);
    my $rv = $DBH->selectall_hashref($sql, 'gbook_id', undef, $uid);
    my @rv = map { $$rv{$_}->{is_guest} = $guest_uid == $$rv{$_}->{guest_uid} ? 1 : 0; 
                   delete $$rv{$_}->{guest_uid}; 
                   $$rv{$_}->{is_owner} = 0; 
                   $$rv{$_}->{body} =~ s/\n/<br>/g;
                   $$rv{$_}->{reply} =~ s/\n/<br>/g;
                   $$rv{$_} }
                sort { $$rv{$b}->{gbook_id} <=> $$rv{$a}->{gbook_id} }
                    keys %$rv;
    return \@rv;
}

sub get_guestbook_pagenav {               
    my ($self, $uid, $page, $left) = @_;

    $left = 0 unless ($left);
    my $tot_gbook = $left ? 
        $self->get_left_guestbook_count($uid): $self->get_guestbook_count($uid);
    my $gbook_per_page = 5; 
    my $page_per_page = 15; 
    my $tot_page = &tot_page($tot_gbook, $gbook_per_page);
    $page = 1 unless ($page);
    $page = $tot_page < $page ? $tot_page : $page;
    my $start = $page % $page_per_page ?
        int($page / $page_per_page) * $page_per_page + 1 :
        ($page / $page_per_page - 1) * $page_per_page + 1;
    my $end = $start + $page_per_page - 1;
    $end = $tot_page if ($end > $tot_page);

    my @pages;
    for (my $i = $start; $i <= $end; $i++) {
        my $current = $page == $i ? 1 : 0;
        push @pages, { page     => $i,
                       current  => $current,
                       uid      => $uid,
                       left     => $left,
                     };
    }
    my %rv;
    $rv{pages} = \@pages;
    $rv{next_page} = $end + 1 if ($end + 1 <= $tot_page);
    $rv{prev_page} = $start - 1 if ($start > $page_per_page);
    $rv{first_page} = 1 if ($page > $page_per_page);
    $rv{last_page} = $tot_page if ($page <= $tot_page - $page_per_page + 1);

    return \%rv;
}

sub get_guestbook_stat {
    my ($self, $uid) = @_;
    my $r_sql = qq(select a.ki, b.name, b.id, count(*) as received 
                   from bw_user_ki as a, bw_xauth_passwd b, bw_user_gbook as c 
                   where a.uid=b.uid && b.uid=c.guest_uid && c.uid=? 
                   group by b.id order by a.ki, b.name, b.id);
    my $s_sql = qq(select a.ki, b.name, b.id, count(*) as sent 
                   from bw_user_ki as a, bw_xauth_passwd b, bw_user_gbook as c 
                   where a.uid=b.uid && b.uid=c.uid && c.guest_uid=? 
                   group by b.id order by a.ki, b.name, b.id);
    my $r = $DBH->selectall_hashref($r_sql, 'id', undef, $uid);
    my $s = $DBH->selectall_hashref($s_sql, 'id', undef, $uid);
    if ($r || $s) {
        my %id;
        foreach my $i (keys %$r, keys %$s) {
            ++$id{ $i };
        }
        my @rv;
        my ($tot_r, $tot_s) = (0, 0);
        foreach my $i (keys %id) {
            my $received = $$r{$i}->{received} || 0;
            my $sent = $$s{$i}->{sent} || 0;
            $tot_r += $received;
            $tot_s += $sent;
            my $ki = $$r{$i}->{ki} || $$s{$i}->{ki};
            my $name = $$r{$i}->{name} || $$s{$i}->{name};
            my $id = $$r{$i}->{id} || $$s{$i}->{id};
            my $arrow = '';
            $arrow .= 'l' if ($received);
            $arrow .= 'r' if ($sent);
            push @rv, { ki      =>$ki,
                        name    => $name,
                        id      => $id,
                        received=> $received,
                        sent    => $sent,
                        arrow   => $arrow,
                      };
        }
        @rv = sort { ($$a{sent} - $$a{received}) <=> ($$b{sent} - $$b{received}) ||
                     $$a{sent} <=> $$b{sent} ||
                     $$a{ki} <=> $$b{ki} || 
                     $$a{name} cmp $$b{name} || 
                     $$a{id} cmp $$b{id} } @rv
            if (@rv);
        my $arrow = '';
        $arrow .= 'l' if ($tot_r);
        $arrow .= 'r' if ($tot_s);

        return (\@rv, $tot_s, $tot_r, $arrow);
    }
}

sub search_affiliation {
    my ($self, $keyword) = @_;
    my $sql = qq(select a.id, a.name, b.ki, c.affiliation
                 from bw_xauth_passwd as a, bw_user_ki as b, bw_user_basic as c
                 where a.uid=b.uid && a.uid=c.uid && 
                 (c.affiliation like ? || a.id like ? || a.name like ?) ); 
    my $rv = $DBH->selectall_hashref($sql, 'id', undef, ("\%$keyword\%") x 3);
    my @rv = map { $$rv{$_} }
                 sort { $$rv{$a}->{ki} <=> $$rv{$b}->{ki} ||
                        $$rv{$a}->{name} cmp $$rv{$b}->{name} ||
                        $$rv{$a}->{id} cmp $$rv{$b}->{id} 
                      } keys %$rv;
    return \@rv;
}

sub get_mapset {
    my ($self, %arg) = @_;
    my $sql = qq(SELECT a.ki, b.uid, b.id, b.name, c.home_map, c.office_map
                 FROM bw_user_ki as a, bw_xauth_passwd as b, bw_user_basic as c
                 WHERE a.uid=b.uid && b.uid=c.uid &&
                       (c.home_map != '' || c.office_map !=''));
    my $rv = $DBH->selectall_hashref($sql, 'uid');
    my @rv = sort { $a->{ki} <=> $b->{ki} ||
                    $a->{name} cmp $b->{name} ||
                    $a->{id} cmp $b->{id} }
             map { $$rv{$_} } keys %$rv;
    my @rv2;
    foreach my $i (@rv) {
        my $h = $i->{home_map} || '';
        my $o = $i->{office_map} || '';
        my ($h_lng, $h_lat, $o_lng, $o_lat) = ('') x 4;
        ($h_lat, $h_lng) = split(/,/, $1)
            if ($h =~ /ll=([\d\.,-]{5,})\&/);
        ($o_lat, $o_lng) = split(/,/, $1)
            if($o =~ /ll=([\d\.,-]{5,})\&/);
        $i->{o_lng} = $o_lng;
        $i->{o_lat} = $o_lat;
        $i->{h_lng} = $h_lng;
        $i->{h_lat} = $h_lat;
    }
    return \@rv;
}

sub get_mapset2 {
    my ($self, %arg) = @_;
    my $sql = qq(SELECT a.ki, b.uid, b.id, b.name, c.home_map, c.office_map,
                        c.temp_map
                 FROM bw_user_ki as a, bw_xauth_passwd as b, bw_user_basic as c
                 WHERE a.uid=b.uid && b.uid=c.uid &&
                       (c.home_map != '' || c.office_map !=''));
    my $rv = $DBH->selectall_hashref($sql, 'uid');
    my @rv = sort { $a->{ki} <=> $b->{ki} ||
                    $a->{name} cmp $b->{name} ||
                    $a->{id} cmp $b->{id} }
             map { $$rv{$_} } keys %$rv;
    my @rv2;
    foreach my $i (@rv) {
        my $h = $i->{home_map} || '';
        my $o = $i->{office_map} || '';
        my $t = $i->{temp_map} || '';
        my ($h_lng, $h_lat, $o_lng, $o_lat, $t_lng, $t_lat) = ('') x 6;
        ($h_lat, $h_lng) = split(/,/, $1)
            if ($h =~ /ll=([\d\.,-]{5,})\&/);
        ($o_lat, $o_lng) = split(/,/, $1)
            if ($o =~ /ll=([\d\.,-]{5,})\&/);
        ($t_lat, $t_lng) = split(/,/, $1)
            if ($t =~ /ll=([\d\.,-]{5,})\&/);
        if ($o_lng && $o_lat) {
            push @rv2, { ki=>$i->{ki}, name=>$i->{name}, id=>$i->{id}, 
                         type=>'office', lng=>$o_lng, lat=>$o_lat };
        }
        if ($h_lng && $h_lat) {
            push @rv2, { ki=>$i->{ki}, name=>$i->{name}, id=>$i->{id}, 
                         type=>'home', lng=>$h_lng, lat=>$h_lat };
        }
        if ($t_lng && $t_lat) {
            push @rv2, { ki=>$i->{ki}, name=>$i->{name}, id=>$i->{id}, 
                         type=>'temp', lng=>$t_lng, lat=>$t_lat };
        }
    }
    return \@rv2;
}

################################################################################
# internal subroutines

sub tot_user {
    my $sql = qq(SELECT count(*) FROM $TBL{passwd});
    my $rv = $DBH->selectrow_array($sql);
    return $rv;
}

sub tot_page {
    my ($tot_gbook, $gbook_per_page) = @_;
    return 1 unless ($tot_gbook && $gbook_per_page);

    my $tot_page = int( $tot_gbook / $gbook_per_page );
    ++$tot_page if ($tot_gbook % $gbook_per_page);
    $tot_page = 1 if ($tot_page < 1);
    return $tot_page;
}

sub get_sig {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $sql = qq(SELECT sig FROM $TBL{sig} WHERE uid=?);
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-uid});

    return $rv;
}

sub edit_sig {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid} && exists $arg{-sig});

    my $sql = qq(REPLACE INTO $TBL{sig} (uid, sig) VALUES (?, ?));
    my $rv = $DBH->do($sql, undef, $arg{-uid}, $arg{-sig});
    if ($rv) {
        return 1;
    } else {
        return 0;
    }

}

sub make_hyperlink {
    my $self = shift;
    $_ = shift;
    {
        local $^W = 0; # turn off the warning switch
        s!(\s|^)(http://)(\S+)\.(jpg|gif|png)(\s|$)!$1<a href=\"$2$3.$4\" target=\"_blank\"><img src=\"$2$3.$4\" border=\"0\"></a>!ogi;
        s!(\s|^)(mailto:)(\S+)!$1<a href=\"$2$3\" target=\"_blank\">$2$3</a>!og;
        my @protocol = qw( http https ftp mms mmst );
        foreach my $p (@protocol) {
            $_ =~ s!(\s|^)($p://)(\S{1,50})(\s|$)!$1<a href="$2$3" target="_blank">$2$3</a>$4!gx;
            $_ =~ s!(\s|^)($p://)(\S{50})(\S+)(\s|$)!$1<a href="$2$3$4" target="_blank">$2$3 ...</a>$5!gx;
        }
    }
    return $_;
}

sub escape_tags {
    my $self = shift;
    $_ = shift;
    my $escaped_tags = $self->{escaped_tags} || 'html body embed iframe applet script bgsound object meta head style link';
    my $tags = '(' . join("|", split(/\s+/, $escaped_tags) ) . ')'; 
    $_ =~ s/<(\/?$tags)/&lt;$1/igox;
    return $_;
}

1;
