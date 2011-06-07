package Bawi::Main::UI;

use strict;
use warnings;

use Carp;
use CGI;
use File::Spec;
use HTML::Template;
use Text::Iconv;

use Bawi::DBI;
use Bawi::Main::Config;
use Bawi::Main::L10N;

# constructor
sub new {
    my ($class, %arg) = @_;

    my $cfg = new Bawi::Main::Config(%arg);
    my $dbh = $cfg->DBName && $cfg->DBUser && $cfg->DBPasswd ?
            new Bawi::DBI(-cfg=>$cfg) : undef;
    my $lh = Bawi::Main::L10N->get_handle() || undef;
    my $self = {
        cgi      => new CGI,
        template => undef,
        cfg      => $cfg, 
        dbh      => $dbh,
        lh       => $lh,
    };
    bless $self, $class;
    $self->cgi->charset($cfg->CharSet); # for proper escapeHTML.

    if (exists $arg{-template}) {
        my $skin = exists $arg{-skin} && $arg{-skin} ? $arg{-skin} : '';
        $self->init(-template=>$arg{-template}, -skin=>$skin);
    }

    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->{dbh}->disconnect if defined $self->{dbh};
    $self->{dbh} = undef;
}

################################################################################
# accessors
sub template {
    my $self = shift;
    if (@_) { $self->{template} = shift }
    return $self->{template};
}

sub cgi {
    my $self = shift;
    if (@_) { $self->{cgi} = shift }
    return $self->{cgi};
}

sub cfg {
    my $self = shift;
    if (@_) { $self->{cfg} = shift }
    return $self->{cfg};
}

sub dbh {
    my $self = shift;
    if (@_) { $self->{dbh} = shift }
    return $self->{dbh};
}

sub lh {
    my $self = shift;
    if (@_) { $self->{lh} = shift }
    return $self->{lh};
}


################################################################################
# methods
sub cparam {
    my ($self, @arg) = @_;
    $self->cgi->param(@arg);
}

sub tparam {
    my ($self, %arg) = @_;
    $self->template->param(%arg);
}

sub cgiurl {
    my $self = shift;
    return $self->cgi->url(-query=>1, -path_info=>1);
}

sub output {
    my ($self, %arg) = @_;
    my $type = $arg{-type} ? $arg{-type} : 'text/html';
    my $last_url_cookie = $self->cgi->cookie( -name => 'last_url', 
                                              -value => $self->cgiurl );
    my $output = $self->cgi->header( -charset => $self->cfg->CharSet, 
                                     -type => $type,
                                     -cookie => $last_url_cookie)
                 . $self->template->output;
    return  $output;
}

sub form {
    my ($self, @arg) = @_;
    return unless @arg && $#arg >= 0;
    
    my %form;
    foreach my $i (@arg) {
        $form{$i} = $self->cparam($i) || '';
        $form{$i} =~ s/^\s+//g;
        $form{$i} =~ s/\s+$//g;
        $self->tparam($i=>$form{$i})
            if ($form{$i} && $self->template);
    }
    return %form;
}

sub init {
    my ($self, %arg) = @_;
    return unless exists $arg{-template};

    my $cfg = $self->cfg;
    my @path;
    #warn("SkinDIR : ",$cfg->SkinDir);

    push @path, File::Spec->catdir($cfg->SkinDir, $arg{-skin})
        if (exists $arg{-skin} && $arg{-skin});
    push @path, File::Spec->catdir($cfg->SkinDir, $cfg->DefaultSkin)
        if $cfg->DefaultSkin;
    push @path, File::Spec->catdir($cfg->SkinDir, 'default'); 
    my $t = HTML::Template->new(filename                => $arg{-template},
                                encoding                => ':encoding(UTF-8)', 
                                cache                   => 1, 
                                path                    => \@path,
                                search_path_on_include  => 1,
                                loop_context_vars       => 1,
                                global_vars             => 1,
                                die_on_bad_params       => 0);
    my $skin = $arg{-skin} || $cfg->DefaultSkin || 'default';
    $t->param(skin            =>$skin);
    $t->param(mod_perl        =>&is_mod_perl);
    $t->param(mobile_device   =>&is_mobile_device);
    $t->param(remote_address  =>$self->cgi->remote_addr);
    $t->param(user_agent      =>$self->cgi->user_agent);
    $t->param(google_analytics=>$cfg->GoogleAnalytics);
    $t->param(note_url        =>$cfg->NoteURL);
    $t->param(news_url        =>$cfg->NewsURL);
    $t->param(main_url        =>$cfg->MainURL);
    $t->param(board_url       =>$cfg->BoardURL);
    $t->param(user_url        =>$cfg->UserURL);
    $t->param(HTMLTitle=>$cfg->HTMLTitle) if ($cfg->HTMLTitle);
    $self->template($t);
}

sub multi_column {
    my ($self, %arg) = @_;
    return unless (exists $arg{-array} && exists $arg{-column});

    my $col = $arg{-column};
    my $array = $arg{-array};
    my @formatted;
    my @row;
    for (my $i = 0; $i < scalar(@$array); $i++) {
        push @row, ${$array}[$i];
        if ($i % $col == $col - 1) {
            my @tmp = @row;
            push @formatted, { row=>\@tmp };
            @row = ();
        }
    }
    push @formatted, { row=>\@row } if (@row);
    return \@formatted;
}

sub get_skinset {
    my ($self, %arg) = @_;
    
    my $dir = $self->cfg->SkinDir;
    opendir(DIR, $dir) || die "can't opendir $dir: $!";
    my @skin = grep { /^[^\.]/ && -d File::Spec->catdir($dir, $_) && !/CVS/ } readdir(DIR);
    closedir DIR;
    my @rv = map { my $s = $_ eq 'default' ? 1 : 0; 
                   { selected => $s, skin => $_ } 
             } 
                sort { $a cmp $b } @skin;
    return \@rv;
}

sub substrk {
    my ($self, $text, $length) = @_;
    if( length($text) > $length ) {
        $text = substr($text, 0, $length);
        $text =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;
    }
    return $text;
}

sub substrk2 { #utf-8 version
    my ($self, $text, $length) = @_;

    my $converter = Text::Iconv->new("utf8", "euckr");
    my $euckr_text = $converter->convert($text);

    if ( length($euckr_text) > $length ) {
        $euckr_text = substr($euckr_text, 0, $length);
        $euckr_text =~ s/(([\x80-\xff].)*)[\x80-\xff]?$/$1/;

        $converter = Text::Iconv->new("euckr", "utf8");
        $text = $converter->convert($euckr_text);
    }

    return $text;
}

sub msg {
    my ($self, @msg) = @_;
    my $msg = $self->lh ? $self->lh->maketext(@msg) : join("", @msg);
    $self->template->param(msg=>$msg);
    return 1;
}

sub term {
    my ($self, @term) = @_;
    return unless ($self->lh && $self->template);
    
    foreach my $i (@term) {
        my $term = $self->lh->maketext($i);
        $self->tparam($i=>$term);
    }
    return 1;
}

sub is_mobile_device {
    my $user_agent = CGI::user_agent() || "";
    
    return "iphone os4" if $user_agent =~ m/iPhone OS 4/i;
    return "iphone os3" if $user_agent =~ m/iPhone OS 3/i;
    return "iphone" if $user_agent =~ m/iPhone OS/i;
    return undef;
}

################################################################################
# internal subroutines
sub is_mod_perl {
    if ( exists $ENV{GATEWAY_INTERFACE}
         and $ENV{GATEWAY_INTERFACE} =~ /perl/i ) {
        return 1;
    } else {
        return 0;
    }
}

1;
