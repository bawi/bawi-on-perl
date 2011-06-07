package Bawi::Board::Group;

use 5.006;
use strict;
use warnings;

use Bawi::DBI;
use Bawi::Board::Config;

require Exporter;

our $VERSION = '0.01';

my (%TBL, $DBH);

%TBL = (
group       => 'bw_group',
group_user  => 'bw_group_user',
);

sub new {
    my ($class, %arg) = @_;

    my $cfg = $arg{-cfg} || new Bawi::Board::Config;
    $DBH = $arg{-dbh} || new Bawi::DBI(-cfg=>$cfg);

    my $self;
    if (exists $arg{-gid} && defined $arg{-gid}) {
        $self = &init(%arg);
    }
    $$self{cfg} = $cfg;
    bless $self, $class;
    return $self;
}

sub DESTROY {
    my $self = shift;
    $DBH->disconnect if defined $DBH;
    $DBH = undef;
}

sub gid {
    my $self = shift;
    if (@_) { $self->{gid} = shift }
    return $self->{gid};
}

sub pgid {
    my $self = shift;
    if (@_) { $self->{pgid} = shift }
    return $self->{pgid};
}

sub title {
    my $self = shift;
    if (@_) { $self->{title} = shift }
    return $self->{title};
}

sub keyword {
    my $self = shift;
    if (@_) { $self->{keyword} = shift }
    return $self->{keyword};
}

sub uid {
    my $self = shift;
    if (@_) { $self->{uid} = shift }
    return $self->{uid};
}

sub type {
    my $self = shift;
    if (@_) { $self->{type} = shift }
    return $self->{type};
}

sub created {
    my $self = shift;
    if (@_) { $self->{created} = shift }
    return $self->{created};
}

sub g_sub {
    my $self = shift;
    if (@_) { $self->{g_sub} = shift }
    return $self->{g_sub};
}

sub m_sub {
    my $self = shift;
    if (@_) { $self->{m_sub} = shift }
    return $self->{m_sub};
}

sub a_sub {
    my $self = shift;
    if (@_) { $self->{a_sub} = shift }
    return $self->{a_sub};
}

sub g_board {
    my $self = shift;
    if (@_) { $self->{g_board} = shift }
    return $self->{g_board};
}

sub m_board {
    my $self = shift;
    if (@_) { $self->{m_board} = shift }
    return $self->{m_board};
}

sub a_board {
    my $self = shift;
    if (@_) { $self->{a_board} = shift }
    return $self->{a_board};
}

sub x {
    my $self = shift;
    if (@_) { $self->{x} = shift }
    return $self->{x};
}

sub authz {
    my ($self, %arg) = @_;

    my $uid = $arg{-uid} || 0;
    my $gid = $self->gid || $arg{-gid} || 0;
    my $ouid = $arg{-ouid} || -1;
    my $gperm = $arg{-gperm} || 0; 
    my $mperm = $arg{-mperm} || 0;
    my $aperm = $arg{-aperm} || 0;

    my $is_root = $uid == 1 ? 1 : 0;
    my $is_owner = $is_root || ($uid == $ouid) ? 1 : 0;
    my $is_group = ($is_owner || $self->is_group_member(-uid=>$uid) ) 
                       && $gperm == 1 ? 1 : 0;
    my $is_member = ($is_group || $uid) && $mperm == 1 ? 1 : 0;
    my $is_anon = $is_member || $aperm == 1 ? 1 : 0;

    my $rv = $is_root || $is_owner || $is_group || $is_member || $is_anon || 0;
    return $rv;
}

sub is_group_member {
    my ($self, %arg) = @_;
    return unless (exists $arg{-uid}); 

    my $gid = $self->gid || $arg{-gid} || 0;
    my $uid = $arg{-uid} || 0;
    return $self->{is_group_member}->{$gid}->{$uid}
        if (exists $self->{is_group_member}->{$gid}->{$uid});

    my $sql = qq(SELECT uid FROM $TBL{group_user} 
                 WHERE uid=? && gid=? && status='active');
    my $rv = $DBH->selectrow_array($sql, undef, $arg{-uid}, $gid);
    if ($rv) {
        $self->{is_group_member}->{$gid}->{$uid} = 1;
        return 1;
    } else {
        $self->{is_group_member}->{$gid}->{$uid} = 0;
        return 0;
    }
}

sub get_subgroup {
    my ($self, %arg) = @_;

    my $gid = $arg{-gid} || $self->gid || 1;
    my $sql = qq(SELECT gid, title, seq FROM $TBL{group} WHERE pgid=?);
    my $rv = $DBH->selectall_hashref($sql, 'gid', undef, $gid);
    my @rv = map { $$rv{$_} }
                 sort { $$rv{$a}->{seq} <=> $$rv{$b}->{seq} || $a <=> $b }
                     keys %$rv;
    return \@rv;
}

sub get_path {
    my ($self, %arg) = @_;

    my $sql = qq(SELECT gid, pgid, title FROM $TBL{group});
    my $rv = $DBH->selectall_hashref($sql, 'gid');
    my $gid = $arg{-gid} || $self->gid || 1;
    my @path = ();
    while ($gid > 1) {
        unshift @path, $$rv{$gid};
        my $pgid = $$rv{$gid}->{pgid} || 0;
        delete $$rv{$gid}->{pgid};
        $gid = $pgid;
    }
    delete $$rv{1}->{pgid};
    unshift @path, $$rv{1};
    return \@path;
}

################################################################################
# internal subroutines

sub init {
    my %arg = @_;

    my $sql = qq(SELECT * FROM $TBL{group} WHERE gid=?);
    my $rv = $DBH->selectrow_hashref($sql, undef, $arg{-gid});
    return $rv;
}

1;
