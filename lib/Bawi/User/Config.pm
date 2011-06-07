package Bawi::User::Config;

use strict;
use warnings;
use Carp;
use File::Spec;

sub new {
    my ($class, %arg) = @_;
    my $self = &init(%arg);
    bless $self, $class;
    return $self;
}

sub init {
    my %arg = @_;

    # path to bx.cgi configuration file
    # 1. same directory with the CGI script
    # 2. bx_dir parameter
    #my $bx_dir = $0 =~ m!(.*[/\\])! ? $1 : './';
    #$bx_dir = $arg{-bx_dir} if (exists $arg{-bx_dir} && -d $arg{-bx_dir});
    my $user_dir = File::Spec->catdir($ENV{BAWI_PERL_HOME},'user');
    my $skin_dir = File::Spec->catdir($user_dir, 'skin');
    my $attach_dir = File::Spec->catdir($ENV{BAWI_DATA_HOME},'attach');

    # initial values
    my %cfg = (
        DBName              => '',
        DBUser              => '',
        DBPasswd            => '',
        LoginSuccess        => 'bookmark.cgi',
        LogoutURL           => 'login.cgi',
        LoginURL            => 'login.cgi',
        PasswdURL           => 'passwd.cgi',
        SessionName         => 'bx_session',
        SessionDomain       => '',
        PasswdExpire        => 0,
        KeepLogin           => 0,
        SelfRegistration    => 0,
        DefaultSkin         => 'default',
        #AttachDir           => File::Spec->catdir($bx_dir, 'attach'),
        #SkinDir             => File::Spec->catdir($bx_dir, 'skin'),
        AttachDir           => $attach_dir,
        SkinDir             => $skin_dir,
        CharSet             => 'utf-8',
        GoogleAnalytics     => 0,
        BackgroundImageURL  => '',
        AllowAddBoard       => 0,
        AllowUserList       => 0,
        AllowRecomUserList  => 0,
        AllowRecomComment   => 0,
        AllowAccessControl  => 0,
        AllowAnonAccess     => 0,
        AllowAnonBoard      => 0,
        AllowAttach         => 0,
        HTMLTitle           => 'Bawi',
        NoteCheckURL        => '',
        NoteURL             => '',
        MenuURL             => '',
        NewsURL             => '',
        BoardURL            => '',
        UserURL             => '',
    );

    # update with the values in the bx.cgi
    #my $file = File::Spec->catfile($bx_dir, 'bx.cgi');
    #$file = $arg{-cfg} if (exists $arg{-cfg});
    my $file_config = File::Spec->catfile($ENV{BAWI_PERL_HOME},
                                          'conf','user.conf');
    if (-e $file_config && -r $file_config) { 
        open(FH, "< $file_config"); 
        while (<FH>) {
            chomp;
            next if !/\S/ || /^#/;
            my($var, $val) = $_ =~ /^\s*(\S+)\s+(.+)$/;
            $val =~ s/\s*$//;
            next unless $var && defined($val);
            $cfg{$var} = $val;
        }
        close FH;
    }
    return \%cfg;
}

sub DBName {
    my $self = shift;
    if (@_) { $self->{DBName} = shift }
    return $self->{DBName};
}

sub DBUser {
    my $self = shift;
    if (@_) { $self->{DBUser} = shift }
    return $self->{DBUser};
}

sub DBPasswd {
    my $self = shift;
    if (@_) { $self->{DBPasswd} = shift }
    return $self->{DBPasswd};
}

sub LoginSuccess {
    my $self = shift;
    if (@_) { $self->{LoginSuccess} = shift }
    return $self->{LoginSuccess};
}

sub LogoutURL {
    my $self = shift;
    if (@_) { $self->{LogoutURL} = shift }
    return $self->{LogoutURL};
}

sub LoginURL {
    my $self = shift;
    if (@_) { $self->{LoginURL} = shift }
    return $self->{LoginURL};
}

sub PasswdURL {
    my $self = shift;
    if (@_) { $self->{PasswdURL} = shift }
    return $self->{PasswdURL};
}

sub SessionName {
    my $self = shift;
    if (@_) { $self->{SessionName} = shift }
    return $self->{SessionName};
}

sub SessionDomain {
    my $self = shift;
    if (@_) { $self->{SessionDomain} = shift }
    return $self->{SessionDomain};
}

sub PasswdExpire {
    my $self = shift;
    if (@_) { $self->{PasswdExpire} = shift }
    return $self->{PasswdExpire};
}

sub DefaultSkin {
    my $self = shift;
    if (@_) { $self->{DefaultSkin} = shift }
    return $self->{DefaultSkin};
}

sub CharSet {
    my $self = shift;
    if (@_) { $self->{CharSet} = shift }
    return $self->{CharSet};
}

sub SkinDir {
    my $self = shift;
    if (@_) { $self->{SkinDir} = shift }
    return $self->{SkinDir};
}

sub AttachDir {
    my $self = shift;
    if (@_) { $self->{AttachDir} = shift }
    return $self->{AttachDir};
}

sub KeepLogin {
    my $self = shift;
    if (@_) { $self->{KeepLogin} = shift }
    return $self->{KeepLogin};
}

sub SelfRegistration {
    my $self = shift;
    if (@_) { $self->{SelfRegistration} = shift }
    return $self->{SelfRegistration};
}

sub AllowAddBoard {
    my $self = shift;
    if (@_) { $self->{AllowAddBoard} = shift }
    return $self->{AllowAddBoard};
}

sub AllowUserList {
    my $self = shift;
    if (@_) { $self->{AllowUserList} = shift }
    return $self->{AllowUserList};
}

sub AllowRecomUserList {
    my $self = shift;
    if (@_) { $self->{AllowRecomUserList} = shift }
    return $self->{AllowRecomUserList};
}

sub AllowRecomComment {
    my $self = shift;
    if (@_) { $self->{AllowRecomComment} = shift }
    return $self->{AllowRecomComment};
}

sub AllowAccessControl {
    my $self = shift;
    if (@_) { $self->{AllowAccessControl} = shift }
    return $self->{AllowAccessControl};
}

sub AllowAnonAccess {
    my $self = shift;
    if (@_) { $self->{AllowAnonAccess} = shift }
    return $self->{AllowAnonAccess};
}

sub AllowAnonBoard {
    my $self = shift;
    if (@_) { $self->{AllowAnonBoard} = shift }
    return $self->{AllowAnonBoard};
}

sub AllowAttach {
    my $self = shift;
    if (@_) { $self->{AllowAttach} = shift }
    return $self->{AllowAttach};
}

sub HTMLTitle {
    my $self = shift;
    if (@_) { $self->{HTMLTitle} = shift }
    return $self->{HTMLTitle};
}

sub BackgroundImageURL{
    my $self = shift;
    if (@_) { $self->{BackgroundImageURL} = shift }
    return $self->{BackgroundImageURL};
}

sub NoteCheckURL {
    my $self = shift;
    if (@_) { $self->{NoteCheckURL} = shift }
    return $self->{NoteCheckURL};
}

sub MenuURL {
    my $self = shift;
    if (@_) { $self->{MenuURL} = shift }
    return $self->{MenuURL};
}

sub NoteURL {
    my $self = shift;
    if (@_) { $self->{NoteURL} = shift }
    return $self->{NoteURL};
}

sub NewsURL {
    my $self = shift;
    if (@_) { $self->{NewsURL} = shift }
    return $self->{NewsURL};
}

sub BoardURL {
    my $self = shift;
    if (@_) { $self->{BoardURL} = shift }
    return $self->{BoardURL};
}

sub UserURL {
    my $self = shift;
    if (@_) { $self->{UserURL} = shift }
    return $self->{UserURL};
}

sub GoogleAnalytics {
    my $self = shift;
    if (@_) { $self->{GoogleAnalytics} = shift }
    return $self->{GoogleAnalytics};
}

sub x {
    my $self = shift;
    if (@_) { $self->{x} = shift }
    return $self->{x};
}

1;
