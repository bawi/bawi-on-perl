package Bawi::Auth;

use 5.006;
use strict;
use warnings;

use CGI;
use CGI::Cookie;
use URI::Escape;

use Bawi::DBI;
#use Bawi::Board::Config;
#use Bawi::User::Config;

require Exporter;

our $VERSION = '0.01';
our $DefaultClass = 'Bawi::Auth';

my (%OPT, %TBL, $DBH);

%OPT = (
  login_url       => 'http://www.bawi.org/login.cgi',
  denied_url      => CGI::url(-base=>1).'/denied.cgi',
  #passwd_url      => 'passwd.cgi',
  session_path    => '/',
  session_expires => '+1M',
  online          => '3',
);

%TBL = (
  passwd     => 'bw_xauth_passwd',
  session    => 'bw_xauth_session',
  new_passwd => 'bw_xauth_new_passwd',
);

sub new {
    my ($class, %arg) = @_;

    #my $cfg = $arg{-cfg} || new Bawi::Board::Config;
    #print STDERR $cfg->LogoutURL,"\n";
    #$DBH = $arg{-dbh} || new Bawi::Board::DBI(-cfg=>$cfg);
    my $cfg = $arg{-cfg};
    $DBH = $arg{-dbh} || new Bawi::DBI(-cfg=>$cfg);
    bless {
        success_url     => $cfg->LoginSuccess, 
        login_url       => $cfg->LoginURL, 
        denied_url      => $OPT{denied_url},
        logout_url      => $cfg->LogoutURL,
        passwd_url      => $cfg->PasswdURL,
        passwd_expire   => $cfg->PasswdExpire,
        session_cookie  => {
            -name    => $cfg->SessionName,
            -domain  => $cfg->SessionDomain,
            -path    => $OPT{session_path},
            -expires => $OPT{session_expires},
        }
            
    }, $class;
}

sub DESTROY {
    my $self = shift;
    $DBH->disconnect if defined $DBH;
    $DBH = undef;
}

sub uid {
    my $self = shift;
    if (@_) { $self->{uid} = shift }
    return $self->{uid};
}

sub id {
    my $self = shift;
    if (@_) { $self->{id} = shift }
    return $self->{id};
}

sub name {
    my $self = shift;
    if (@_) { $self->{name} = shift }
    return $self->{name};
}

sub email {
    my $self = shift;
    if (@_) { $self->{email} = shift }
    return $self->{email};
}

sub passwd {
    my $self = shift;
    if (@_) { $self->{passwd} = shift }
    return $self->{passwd};
}

sub modified {
    my $self = shift;
    if (@_) { $self->{modified} = shift }
    return $self->{modified};
}

sub  success_url {
    my $self = shift;
    if (@_) { $self->{success_url} = shift }
    return $self->{success_url};
}

sub login_url {
    my $self = shift;
    if (@_) { $self->{login_url} = shift }
    return $self->{login_url};
}

sub logout_url {
    my $self = shift;
    if (@_) { $self->{logout_url} = shift }
    return $self->{logout_url};
}

sub passwd_url {
    my $self = shift;
    if (@_) { $self->{passwd_url} = shift }
    return $self->{passwd_url};
}

sub passwd_expire {
    my $self = shift;
    if (@_) { $self->{passwd_expire} = shift }
    return $self->{passwd_expire};
}

sub session_key{
    my $self = shift;
    if (@_) { $self->{session_key} = shift }
    return $self->{session_key};
}

sub session_cookie {
    my $self = shift;
    if (@_) { $self->{session_cookie} = shift }
    return $self->{session_cookie};
}

sub auth {
    my ($self, %arg) = @_;

    my $session_key;
    if ($arg{-session_key}) {
        $session_key = $arg{-session_key};
    } else {
        my %cookie = fetch CGI::Cookie;
        return 0 unless exists $cookie{ $self->session_cookie->{-name} };
        $session_key = $cookie{ $self->session_cookie->{-name} }->value;
    }
    
    return 0 unless ($session_key);
    my $session = &get_session($session_key);

    if ($session) {
        $self->uid($session->{uid});
        $self->id($session->{id});
        $self->name($session->{name});
        $self->session_key($session_key);
        &update_log($session->{uid});
        return 1;
    } else {
        return 0;
    }
}

sub auth_admin {
    my ($self, %arg) = @_;

    unless ($self->auth) {
        return 0;
    }
    return 1 if $self->is_admin($self->id);
    return 0;
}

sub login {
    my ($self, %arg) = @_;
    return 0 unless (exists $arg{-id} && exists $arg{-passwd});
    return 1 if ($self->auth);

    my $user = &check_passwd($arg{-id}, $arg{-passwd}); 
    if ($user) {
        &expire_session($user->{uid}) unless $arg{-simultaneous};
        my $session_key = &add_session($user->{uid}, 
                                       $user->{id}, 
                                       $user->{name});
        if ($session_key) {
            $self->session_key($session_key);
            $self->uid($user->{uid});
            $self->id($user->{id});
            $self->name($user->{name});
            $self->email($user->{email});
            $self->passwd($user->{passwd});
            $self->modified($user->{modified});
            if ($self->passwd_expire 
                && $user->{elapsed} >= $self->passwd_expire) {
                return 2; # login successed but passwd expired
            } else {
                return 1; # login successed
            } 
        } else {
            return -1; # failed session creation
        }
    } else {
        return 0; # invalid id/passwd
    }
}

sub logout {
    my $self = shift;

    my %cookie = fetch CGI::Cookie;
    return 0 unless exists $cookie{ $self->session_cookie->{-name} };
    
    my $session_key = $cookie{ $self->session_cookie->{-name} }->value;
    my $session = &del_session($session_key);
    $self->uid(undef);
    $self->id(undef);
    $self->name(undef);

    return 1;
}

sub adduser {
    my ($self, %arg) = @_;
    return 0 unless (exists $arg{-id} && 
                     exists $arg{-name} && 
                     exists $arg{-passwd} &&
                     exists $arg{-email});

    my $sql = qq(INSERT INTO $TBL{passwd} 
                 (id, name, passwd, email, modified) 
                 VALUES (?, ?, ENCRYPT(?), ?, NOW()));
    my $rv = $DBH->do($sql, undef, $arg{-id}, 
                                   $arg{-name}, 
                                   $arg{-passwd}, 
                                   $arg{-email});
    my $uid = $rv ? &last_insert_id() : undef;
    return $uid;
}

sub get_user {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid} || exists $arg{-id});

    my $where = $arg{-uid} ? 'a.uid=?' : 'a.id=?';
#    my $where = $arg{-uid} ? 'uid=?' : 'id=?';
    my $ph = $arg{-uid} ? $arg{-uid} : $arg{-id};
    my $sql = qq(SELECT a.id, a.name, a.email, a.uid, a.access, a.accessed, a.modified, b.ki
                 FROM $TBL{passwd} as a, bw_user_ki as b WHERE a.uid=b.uid && $where);
#    my $sql = qq(SELECT id, name, email, uid, access, accessed, modified
#                 FROM $TBL{passwd} WHERE $where);
    my $rv = $DBH->selectrow_hashref($sql, undef, $ph);
    return $rv;
}

sub eduser {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $uid = $arg{-uid} || $self->uid || 0;
    my $id = $arg{-id} || $self->id || '';
    my $name = $arg{-name} || $self->name || '';
    my $email = $arg{-email} || $self->email || '';
    my $sql = qq(UPDATE $TBL{passwd} SET id=?, name=?, email=?, modified=NOW() 
                 WHERE uid=?);
    my $rv = $DBH->do($sql, undef, $id, $name, $email, $uid);
    return $rv;
}

sub deluser {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid});

    my $sql = qq(DELETE FROM $TBL{passwd} WHERE uid=?);
    my $rv = $DBH->do($sql, undef, $arg{-uid});
    return $rv;
}

sub chpasswd {
    my ($self, %arg) = @_;
    return 0 unless (exists $arg{-id} && 
                     exists $arg{-oldpasswd} && 
                     exists $arg{-newpasswd});

    my $sql = qq(UPDATE $TBL{passwd} SET passwd=ENCRYPT(?), modified=now() 
                 WHERE id=? && passwd=ENCRYPT(?, passwd));
    my $rv = $DBH->do($sql, undef, $arg{-newpasswd}, 
                                   $arg{-id}, 
                                   $arg{-oldpasswd});
    return $rv;
}

sub online {
    my $self = shift;

    my $sql = qq(SELECT id, name FROM $TBL{passwd}
                 WHERE accessed > DATE_SUB(NOW(),INTERVAL $OPT{online} MINUTE));
    my $rv = $DBH->selectall_arrayref($sql);
    @$rv = map { { id=>$$_[0], name=>$$_[1] } } sort { $$a[1] cmp $$b[1] } @$rv;
    return $rv;
}

sub online_bawi {
    my $self = shift;

    my $sql = qq(SELECT a.id, a.name, b.ki 
                 FROM $TBL{passwd} as a, bw_user_ki as b
                 WHERE a.uid=b.uid && 
                       a.accessed > DATE_SUB(NOW(),INTERVAL $OPT{online} MINUTE));
    my $rv = $DBH->selectall_arrayref($sql);
    @$rv = map { { id=>$$_[0], name=>$$_[1], ki=>$$_[2] } } 
                sort { $$a[2] <=> $$b[2] || $$a[1] cmp $$b[1] } @$rv;
    return $rv;
}

sub userlist {
    my ($self, %arg) = @_;

    my $users = &tot_user;
    my $user_per_page = $arg{-user_per_page} || 20;
    my $tot_page = &tot_page($users, $user_per_page);
    my $page = $arg{-page} || 1;
    my $sort = $arg{-sort} || 'accessed';
    my $sort2 = $sort eq 'name' ? 'id' : 'name';
    my $order = $arg{-order} eq '1' ? 'ASC' : 'DESC';
    my $start = ($page - 1) * $user_per_page;

    my $sql = qq(SELECT uid, id, name, DATE_FORMAT(modified, '%Y-%m-%d') as 
                        modified, DATE_FORMAT(accessed, '%Y-%m-%d %H:%i') as 
                        accessed, access, email
                 FROM $TBL{passwd}
                 ORDER BY $sort $order, $sort2 $order
                 LIMIT $start, $user_per_page);
    my $rv = $DBH->selectall_hashref($sql, 'uid');
    my @rv;
    if ($order eq 'ASC') {
        if ($sort eq 'access' || $sort eq 'uid') {
            @rv = map { $$rv{$_} } 
                      sort { $$rv{$a}->{$sort} <=> $$rv{$b}->{$sort} ||
                             $$rv{$a}->{$sort2} cmp $$rv{$b}->{$sort2} }
                          keys %$rv;
        } else {
            @rv = map { $$rv{$_} } 
                      sort { $$rv{$a}->{$sort} cmp $$rv{$b}->{$sort} ||
                             $$rv{$a}->{$sort2} cmp $$rv{$b}->{$sort2} }
                          keys %$rv;
        }
    } else {
        if ($sort eq 'access' || $sort eq 'uid') {
            @rv = map { $$rv{$_} } 
                      sort { $$rv{$b}->{$sort} <=> $$rv{$a}->{$sort} ||
                             $$rv{$b}->{$sort2} cmp $$rv{$a}->{$sort2} }
                          keys %$rv;
        } else {
            @rv = map { $$rv{$_} } 
                      sort { $$rv{$b}->{$sort} cmp $$rv{$a}->{$sort} ||
                             $$rv{$b}->{$sort2} cmp $$rv{$a}->{$sort2} }
                          keys %$rv;
        }
    }
    return \@rv;
}

sub get_pagenav {               
    my ($self, %arg) = @_;      
                                
    my $users = &tot_user;
    my $user_per_page = $arg{-user_per_page} || 20;
    my $page_per_page = $arg{-page_per_page} || 10;
    my $tot_page = &tot_page($users, $user_per_page);
    my $page = $arg{-page} || 1;
    my $sort = $arg{-sort} || 'accessed';
    my $order = $arg{-order} eq '1' ? 1 : 0; 
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
                       sort     => $sort,
                       order    => $order };
    }
    my %rv;
    $rv{pages} = \@pages;
    $rv{sort} = $sort;
    $rv{order} = $order;
    $rv{next_page} = $end + 1 if ($end + 1 <= $tot_page);
    $rv{prev_page} = $start - 1 if ($start > $page_per_page);
    $rv{first_page} = 1 if ($page > $page_per_page);
    $rv{last_page} = $tot_page if ($page <= $tot_page - $page_per_page + 1);

    return \%rv;
}

sub exists_id {
    my ($self, %arg) = @_;
    return unless (exists $arg{-id});

    my $sql = qq(SELECT id FROM $TBL{passwd} WHERE id=?);
    my $id = $DBH->selectrow_array($sql, undef, $arg{-id});
    if ($id && $id eq $arg{-id}) {
        return 1;
    } else {
        return 0;
    } 
}

sub exists_new_id {
    my ($self, %arg) = @_;
    return unless (exists $arg{-id});

    my $sql = qq(SELECT id FROM $TBL{new_passwd} WHERE id=?);
    my $id = $DBH->selectrow_array($sql, undef, $arg{-id});
    if ($id && $id eq $arg{-id}) {
        return 1;
    } else {
        return 0;
    } 
}

sub login_page {
    my ($self, $url) = @_;

    my $rurl = $self->{login_url}; 
    if ($url) {
        $url = uri_escape($url);
        $rurl .= "?url=$url";
    }

    my $q = new CGI;
    return $q->redirect($rurl);
}

sub access_denied {
    my ($self, $url) = @_;

    my $rurl = $self->{denied_url}; 
    if ($url) {
        $url = uri_escape($url);
        $rurl .= "?url=$url";
    }

    my $q = new CGI;
    return $q->redirect($rurl);
}

sub send_mail {
    my ($self, %arg) = @_;
    return unless (exists $arg{-from} && 
                   exists $arg{-to} && 
                   exists $arg{-subject} && 
                   exists $arg{-body});
    
    $ENV{'PATH'} = '/bin:/usr/bin';
    delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
    open(SENDMAIL, "|/usr/sbin/sendmail -oi -t")
        or die "Can't fork for sendmail: $!\n";
print SENDMAIL <<"EOF";
From: $arg{-from} 
To: $arg{-to}
Bcc: $arg{-from} 
Subject: $arg{-subject}
Content-type: text/plain; charset=utf-8
$arg{-body}
EOF
close(SENDMAIL) or warn "sendmail didn't close nicely";
}

sub random_passwd {
    my $self = shift;
    my $rv = join("", ('a'..'z')[rand 26, rand 26, rand 26, rand 26, rand 26]);
    return $rv;
}

sub email_code {
    my ($self, %arg) = @_;
    return unless (exists $arg{-email} && exists $arg{-passwd});
    
    my $seed = join('', ('a'..'z')[rand 26, rand 26]);
    my $code = crypt($arg{-email} . $arg{-passwd}, $seed);
    return $code;
}
################################################################################
# internal subroutines

sub add_session {
    my ($uid, $id, $name) = @_;

    my $session_str = $uid . $id . $name . time();
    my $sql = qq(INSERT INTO $TBL{session} 
                 (session_key, uid, id, name, created)
                 VALUES (MD5(?), ?, ?, ?, NOW()));
   
    my $rv = $DBH->do($sql, undef, $session_str, $uid, $id, $name);

    if ($rv) {
        my $session_key = $DBH->selectrow_array('SELECT MD5(?)', undef, $session_str);
        return $session_key;
    } else {
        return undef;
    }
}

sub get_session {
    my $session_key = shift;

    my $sql = qq(SELECT uid, id, name FROM $TBL{session} WHERE session_key=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $session_key);
    return $rv;
}

sub del_session {
    my $session_key = shift;

    my $sql = qq(DELETE FROM $TBL{session} WHERE session_key=?);
    my $rv = $DBH->do($sql, undef, $session_key);
    return $rv;
}

sub expire_session {
    my $uid = shift;

    my $sql = qq(DELETE FROM $TBL{session} WHERE uid=?);
    my $rv = $DBH->do($sql, undef, $uid);
    return $rv;
}

sub update_log {
    my $uid = shift;

    my $sql = qq(UPDATE $TBL{passwd} SET accessed=NOW(), access=access+1 
                 WHERE uid=?);
    my $rv = $DBH->do($sql, undef, $uid);
    return $rv;
}

sub check_passwd {
    my ($id, $passwd) = @_;
    
    my $sql = qq(SELECT uid, id, name, email, passwd, modified, 
                        round((unix_timestamp() - unix_timestamp(modified)) / 3600 / 24, 0) as elapsed 
                 FROM $TBL{passwd} 
                 WHERE id=? && passwd=ENCRYPT(?, passwd));
    my $rv = $DBH->selectrow_hashref($sql, undef, $id, $passwd);
    return $rv;
}

sub last_insert_id {
    my $sql = qq(SELECT LAST_INSERT_ID());
    my $rv = $DBH->selectrow_array($sql);
    return $rv;
}

sub tot_user {
    my $sql = qq(SELECT count(*) FROM $TBL{passwd});
    my $rv = $DBH->selectrow_array($sql);
    return $rv;
}

sub tot_page {
    my ($users, $user_per_page) = @_;
    return 1 unless ($users && $user_per_page);

    my $tot_page = int( $users / $user_per_page );
    ++$tot_page if ($users % $user_per_page);
    $tot_page = 1 if ($tot_page < 1);
    return $tot_page;
}

sub is_admin {
    my ($self,$id) = @_; #self_or_default(@_);
    $id = $self->id unless $id;
    my @jigi = qw(root aragorn doslove linusben seouri WWolf mukluk sylee honest fantics);
    return 1 if grep { $_ eq $id } @jigi;
    return 0;
}

sub self_or_default {
    return @_ if defined($_[0]) && (!ref($_[0])) && ($_[0] eq 'Bawi::Auth');
    return ($DefaultClass,@_);
}

1;
