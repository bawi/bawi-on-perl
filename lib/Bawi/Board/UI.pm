package Bawi::Board::UI;

use strict;
use warnings;

use Carp;
use CGI;
use CGI::Cookie; # for mobile status
use File::Spec;
use HTML::Template;
use Text::Iconv;

use Bawi::DBI;
use Bawi::Board::Config;
use Bawi::Board::L10N;

# constructor
sub new {
    my ($class, %arg) = @_;

    my $cfg = new Bawi::Board::Config(%arg);
    my $dbh = $cfg->DBName && $cfg->DBUser && $cfg->DBPasswd ?
            new Bawi::DBI(-cfg=>$cfg) : undef;
    my $lh = Bawi::Board::L10N->get_handle() || undef;
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
    my $auth_id = $self->template->param('id');
    my $output = $self->cgi->header( -charset => $self->cfg->CharSet, 
                                     -type => $type, 
                                     -cookie => $last_url_cookie,
                                     -bawiuser => ($auth_id||"undef") )
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
	# 2014. 01. 07. -WWolf
	# check cookie. if no cookie exist, determine mobile device according to
	# detect mobilebrowsers.com script.
	# cookie should be changeable: _menu.tmpl should have one link.

    my $user_agent = CGI::user_agent();
#    #http://www.bawi.org/board/read.cgi?bid=990;aid=1586189;p=7
#    my @android_list = ("SAMSUNG SGH","SAMSUNG SHV","NEXUS 5","SHV-E","SHW-M","IM-A850K","SGH-T","LG-F","Nexus 4","KM-E100","SM-N900","HTC6435LVW","IM-A870S","SAMSUNG-SGH","SCH-I535");

	my %cookies;
	%cookies = CGI::Cookie->fetch;

	my @mobile_list = ("iphone os4", "iphone os3", "iphone");
	if (exists $cookies{'bawi_mobile'}) {
		foreach my $tmp_mobile_cookie_enum (@mobile_list) {
			return $tmp_mobile_cookie_enum if ($cookies{'bawi_mobile'}->value eq $tmp_mobile_cookie_enum);
		}

		return undef;
	}

	# no cookie exist, make one and return appropriately. how?
	# not here, the representation should be stored in this instance. (UI)

	my $is_mobile_device = "none";
    
    $is_mobile_device = "iphone os4" if $user_agent =~ m/iPhone OS 4/i;
    $is_mobile_device = "iphone os3" if $user_agent =~ m/iPhone OS 3/i;
    $is_mobile_device = "iphone" if $user_agent =~ m/iPhone OS/i;
   	$is_mobile_device = "iphone" if ($user_agent =~ m/(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i || substr($user_agent, 0, 4) =~ m/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i);

	return $is_mobile_device if $is_mobile_device ne "none";
	return undef;
#    foreach my $tmp_android_regex (@android_list) {
#      return "iphone" if( $user_agent =~ /$tmp_android_regex/i );
#    }
#    return undef;
}

################################################################################
# internal subroutines
sub is_mod_perl {
    if ( exists $ENV{MOD_PERL}
         and $ENV{MOD_PERL} =~ /mod_perl/i ) {
        return 1;
    } else {
        return 0;
    }
}

1;
