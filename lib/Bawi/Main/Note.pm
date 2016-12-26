# Copyright (c) 2002 BAWI. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Bawi::Main::Note;

$VERSION = 0.1;
use strict;
use warnings;
use Carp;
use Bawi::DBI;

use vars qw($DBTABLE);
$DBTABLE = "bw_note";

sub new {
    my ($class,%args) = @_;
    bless {
        -dbh => $args{-dbh},
        mbox => $args{-mbox} || "inbox",
        notes => 0,
        page => 0,
        note_per_page => 8,
        page_per_page => 8,
    },$class;
}

sub DESTROY {
    my $self = shift;
    $self->{'-dbh'}->disconnect;
}

sub note_per_page {
    my $self = shift;
    if (@_) { $self->{note_per_page} = shift }
    return $self->{note_per_page};
}

sub page_per_page {
    my $self = shift;
    if (@_) { $self->{page_per_page} = shift }
    return $self->{page_per_page};
}

sub id {
    my $self = shift;
    if (@_) { $self->{id} = shift }
    return $self->{id};
}

sub notes {
    my $self = shift;
    if (@_) { $self->{notes} = shift }
    return $self->{notes};
}

sub tot_page {
    my $self = shift;
    if (@_) { $self->{tot_page} = shift }
    return $self->{tot_page};
}

sub page {
    my $self = shift;
    if (@_) { $self->{page} = shift }
    return $self->{page};
}

sub mbox {
    my $self = shift;
    if (@_) { $self->{mbox} = shift }
    return $self->{mbox};
}

################################################################################
# methods

sub send_msg {
    my $self = shift;
    my $to_id = shift || "";
    my $to_name = shift || "";
    my $from_id = shift || "";
    my $from_name = shift || "";
    my $msg = shift || "";

    return if ($to_id eq "" || $to_name eq "" || $from_id eq "" || $from_name eq "" || $msg eq "");

    my $stmt = "INSERT INTO $DBTABLE (to_id, to_name, from_id, from_name, msg, sent_time) values (?, ?, ?, ?, ?, NOW());";
    my $sth = $self->{'-dbh'}->prepare($stmt);
    my $rv = $sth->execute($to_id, $to_name, $from_id, $from_name, $msg);
    return $rv;
}

sub delete_msg {
    my $self = shift;
    my $msg_id = shift;
    return if ($msg_id eq "");

    my $stmt = "DELETE FROM $DBTABLE WHERE (msg_id = $msg_id);";
    my $rv = $self->{'-dbh'}->do($stmt);
    return $rv;
}

sub save_msg {
    my $self = shift;
    my $msg_id = shift;
    return if ($msg_id eq "");

    my $stmt = "UPDATE $DBTABLE SET read_time = NOW() where msg_id = $msg_id;";
    my $rv = $self->{'-dbh'}->do($stmt);
    return $rv;
}

sub check_messages {
    my ($self, %arg) = @_;
    my $mbox = $arg{-mbox} || "inbox";
    my $id = $arg{-id};
    my $correspondent = $arg{-correspondent} || $id;
    my $note_per_page = $self->note_per_page;

    return unless $id;


    my $sql;
    $sql = qq( select count(*) from $DBTABLE
where to_id = ? && read_time IS NULL order by msg_id DESC ) if $mbox eq "inbox";
    $sql = qq( select count(*) from $DBTABLE
where to_id = ? && read_time != sent_time order by msg_id DESC ) if $mbox eq "saved";
    $sql = qq( select count(*) from $DBTABLE
where from_id = ? && read_time IS NULL order by msg_id DESC ) if $mbox eq "sent";
    $sql = qq/ select count(*) from $DBTABLE
               where (from_id like ? && to_id like ?) || (from_id like ? && to_id like ?)/ if $mbox eq "conversation";

    my $rv;
    if ($mbox ne "conversation") {
        $rv = $self->{'-dbh'}->selectrow_array($sql, undef, $id);
    } else {
        $rv = $self->{'-dbh'}->selectrow_array($sql, undef, $id, $correspondent, $correspondent, $id);
    }

    $self->id($id);
    $self->mbox($mbox);
    $self->notes($rv);
    $self->tot_page(&get_tot_page($self->notes,$self->note_per_page));

    return $rv;
}

sub get_messages {
    my ($self, %arg) = @_;
    my $id = $arg{-id} || return;
    my $mbox = $arg{-mbox} || "inbox";
    my $page = $arg{-page} || 0;
    my $correspondent = $arg{-correspondent} || $id;

    my $notes = $self->check_messages(-mbox=>$mbox,-id=>$id, -correspondent=>$correspondent);
    my $note_per_page = $self->note_per_page;
    my $tot_page = $self->tot_page || &get_tot_page($notes, $note_per_page);
    $page = $page ? $page : $tot_page;
    $self->page($page);

    my $start = &get_start($page, $tot_page, $note_per_page);
    #warn("mbox=>$mbox,page=$page,start=$start,tot_page=$tot_page,note_per_page=$note_per_page");
    my $sql;
    if ($mbox ne "conversation") {
        $sql = qq( select msg_id, from_id as id, from_name as name,
                          msg, sent_time, read_time from $DBTABLE
                   where to_id = ? && read_time IS NULL
                   order by msg_id desc limit ?, ? ) if $mbox eq "inbox";
        $sql = qq( select msg_id, from_id as id, from_name as name,
                          msg, sent_time, read_time from $DBTABLE
                   where to_id = ? && read_time != sent_time order
                   by msg_id desc limit ?, ? ) if $mbox eq "saved";
        $sql = qq( select msg_id, to_id as id, to_name as name,
                          msg, sent_time, read_time from $DBTABLE
                   where from_id = ? && read_time IS NULL
                   order by msg_id desc limit ?, ? ) if $mbox eq "sent";
        
        my $rv = $self->{'-dbh'}->selectall_hashref($sql, 'msg_id', undef, $id, $start, $note_per_page);
        my @rv = sort { $b->{msg_id} <=> $a->{msg_id} } 
             map { $$rv{$_} } keys %$rv;
        return \@rv;

    } else {
        $sql = qq/ select msg_id, from_id as id, to_id, from_name as name, to_name,
                          msg, sent_time, read_time from $DBTABLE
               where (from_id like ? && to_id like ?) || (from_id like ? && to_id like ?)
               order by sent_time desc limit ?, ?/ if $mbox eq "conversation";
        
        my $rv = $self->{'-dbh'}->selectall_hashref($sql, 'msg_id', undef, $id, $correspondent, $correspondent, $id, $start, $note_per_page);
        #my $rv = $self->{'-dbh'}->selectall_hashref($sql, 'msg_id', undef, $id, $correspondent, $correspondent, $id);
        my @rv = sort { $b->{msg_id} <=> $a->{msg_id} } 
             map { $$rv{$_} } keys %$rv;

        return \@rv;
    }
   
}

sub check_new_msg {
    my $self = shift;
    my $to_id = shift;
    return unless $to_id;

    my $sql = qq(
select msg_id, /* to_id, to_name, */ from_id as id, from_name as name,
       msg, sent_time, read_time from $DBTABLE
where to_id = ? && read_time IS NULL order by sent_time DESC );
    my $rv = $self->{'-dbh'}->selectall_hashref($sql, 'msg_id', undef, $to_id);
    my @rv = sort { $b->{msg_id} <=> $a->{msg_id} }
             map { $$rv{$_} } keys %$rv;
    return \@rv;
}

sub check_saved_msg {
    my $self = shift;
    my $to_id = shift;
    return unless $to_id;
    
    my $sql = qq(
select msg_id, /* to_id, to_name, */ from_id as id, from_name as name,
       msg, sent_time, read_time from $DBTABLE
where to_id = ? && read_time != sent_time order by sent_time DESC );
    my $rv = $self->{'-dbh'}->selectall_hashref($sql, 'msg_id', undef, $to_id);
    my @rv = sort { $b->{msg_id} <=> $a->{msg_id} }
             map { $$rv{$_} } keys %$rv;
    return \@rv;
}

sub check_sent_msg {
    my $self = shift;
    my $from_id = shift;
    return unless $from_id;

    my $sql = qq(
select msg_id, to_id as id, to_name as name, /* from_id as id, from_name as name, */
       msg, sent_time, read_time from $DBTABLE
where from_id = ? && read_time IS NULL order by sent_time DESC );
    my $rv = $self->{'-dbh'}->selectall_hashref($sql, 'msg_id', undef, $from_id);
    my @rv = sort { $b->{msg_id} <=> $a->{msg_id} }
             map { $$rv{$_} } keys %$rv;
    return \@rv;
}

sub get_uid {
    my $self = shift;
    my $id = shift || "";
    return if ($id eq "");

    my $stmt = "SELECT uid FROM bw_xauth_passwd WHERE id = ?";
    my $rv = $self->{'-dbh'}->selectrow_array($stmt, undef, $id);

    return $rv;
}

sub get_tot_page {
    my ($notes, $note_per_page) = @_;
    return 1 unless ($notes && $note_per_page);

    my $tot_page = int( $notes / $note_per_page );
    ++$tot_page if ($notes % $note_per_page);
    $tot_page = 1 if ($tot_page < 1);
    return $tot_page;
}

sub get_start {
    my ($page, $tot_page, $note_per_page) = @_;
    my $start = ($tot_page - $page) * $note_per_page;
    $start = 0 if ($start < 0);
    return $start;
}

sub get_user_info_by_id {
    my $self = shift;
    my $id = shift || "";
    return if ($id eq "");

    my $stmt = "SELECT * FROM bw_xauth_passwd WHERE id = ?";
    my $rv = $self->{'-dbh'}->selectrow_hashref($stmt, undef, $id);

    return $rv;
}

sub get_pagenav { 
    my ($self, %arg) = @_;

    my $mbox = $self->mbox || "inbox";
    my $tot_note = $self->notes || 0;
    my $note_per_page = $self->note_per_page;
    my $page_per_page = $self->page_per_page;
    my $tot_page = $self->tot_page || 1;
    my $page = $self->page || $tot_page || 1;
    $page = $tot_page < $page ? $tot_page : $page;

    my $start = $page % $page_per_page ? 
        ( int($page / $page_per_page) + 1 ) * $page_per_page :
        int($page / $page_per_page) * $page_per_page; 
    $start = $start > $tot_page ? $tot_page : $start;
    my $end = $start - $page_per_page + 1;
    $end = 1 if ($end < 1);
    my @pages;
    for (my $i = $start; $i >= $end; $i--) {
        my $current = $page == $i ? 1 : 0;
        push @pages, { page=>$i, 
                       mbox=>$mbox, 
                       current=>$current };
    }
    my %rv;
    $rv{pages} = \@pages;
    $rv{page} = $page;
    $rv{next_page} = $end - 1 if ($end - 1 > 0);
    $rv{prev_page} = $start + 1 if ($start + 1 <= $tot_page);
    $rv{first_page} = 1 if ($page > $page_per_page);
    $rv{last_page} = $tot_page if ($page <= $tot_page - $page_per_page + 1);

    return \%rv;
}

sub format_notes {
    my ($self, $notes) = @_;
    foreach my $n (@$notes) {
        next unless (exists $n->{msg});
        $n->{msg} = &make_hyperlink($self, $n->{msg});
    }
    return $notes;
}

sub make_hyperlink {
    my $self = shift;
    $_ = shift;
    {
        local $^W = 0; # turn off the warning switch
        s#(\s|(?<!url)\(|\<|^)(http://[^\s\)\>]+\.(?:jpg|gif|png))(?=\s|\)|\>|$)#$1<a href="$2" target="_blank" class="auto"><img src="$2" alt="$2"/></a>#ogi;
        s#(\s|\(|\<|^)(mailto:)([^\s\)\>]+)#$1<a href="$2$3" target="_blank" class="auto">$2$3</a>#og;
        s#(\s|(?<!url)\(|\<|^)((http://|https://)[^\s\)\>]{1,45})(?=\s|\)|\>|$)#$1<a href="$2" target="_blank" class="auto">$2</a>$4#ogi;
        s#(\s|(?<!url)\(|\<|^)(((http://|https://)\S{45})[^\s\)\>]+)(?=\s|\)|\>|$)#$1<a href="$2" target="_blank" class="auto">$3...$5</a>#ogi;
        s!(^|(?<=\s))(#(\d+))(?=\s|$)!<a href="#c$3" class="auto comment_no">$2</a>!ogi;
    }
    return $_;
}

1;
