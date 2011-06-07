#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Main::UI;
use Bawi::Auth;
use Bawi::Main::Note;
use Image::Magick;


my $ui = new Bawi::Main::UI( -template=>'photo.tmpl', -main_dir=>'admin' );
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth_admin) {
    print $auth->access_denied($ui->cgiurl);
    exit (1);
}
my $t = $ui->template;
my $dbh = $ui->dbh; 

my $upload = '/home/bawi/photo_attach/';
my $updated = '/home/bawi/photo_attach/updated';


my @msg = (
	{ 
		title => "사진이 등록되었습니다.",
		body  => "보내주신 사진을 DB에 등록했습니다." 
	}, 
	{ 
		title => "얼굴을 알아볼 수 없습니다.",
		body  => "얼굴을 알아볼 수 없는 사진은 DB에 등록할 수 없습니다.\n사진을 다시 보내주세요."
	}, 
	{ 
		title => "사진의 크기가 작습니다.",
		body  => "보내주신 사진의 크기가 너무 작습니다.\n얼굴 부분이 더 크게 나온 사진을 다시 보내주세요." 
	}, 
	{
		title => "그림은 등록할 수 없습니다.",
		body  => "DB에는 사진만 등록할 수 있습니다."
	},
	{
		title => "천연색 사진만 등록할 수 있습니다.",
		body  => "DB에는 천연색 사진만 등록할 수 있습니다.\n천연색 사진을 다시 보내주세요."
	},
	{ 
		title => "편집된 사진은 등록할 수 없습니다.",
		body  => "DB에는 증명 사진과 같이 편집되지 않은 사진만 등록하고 있습니다. \n편집되지 않은 사진을 다시 보내주세요."
	}, 
	{ 
		title => "가로 세로 비율이 맞지 않습니다.",
		body  => "보내주신 사진의 가로 세로 비율이 맞지 않아 DB에 등록하기가 곤란합니다.\n다른 사진을 보내주시기 바랍니다."
	}, 
	{ 
		title => "옆 얼굴 사진은 등록할 수 없습니다.",
		body  => "옆 얼굴만 나온 사진은 등록하기 곤란합니다.\n다른 사진을 보내주시기 바랍니다."
	}, 
	{ 
		title => "사진이 손상되었습니다.",
		body  => "보내주신 사진 파일이 손상되었습니다.\n사진을 다시 보내주세요."
	}, 
);

my @title = map { { title=>$$_{title}} } @msg;

my @uid;
opendir(DIR, $upload) or $ui->msg(qq(Can't opendir $upload: $!));
while (my $file = readdir(DIR)) {
    if ($file =~ /(\d+)\.jpg/) {
        push @uid, $1;
    }
}
closedir(DIR);
my $uids = join(", ", @uid);


if ($ui->cparam('photo')) {
    local *local_fh; my $fh = *local_fh; undef *local_fh;
    $fh = $ui->cgi->upload('photo');
    my $file = $ui->cparam('photo');
    my $out = "$upload/$file";
    my($bytesread, $buffer);
    open(OUT,"> $out") or die("Can't open file $out: $!\n");
    while($bytesread = read($fh,$buffer,1024)) {
        print OUT $buffer;
    }
    close OUT;
}

my $update = $ui->cparam('update') || '';
my $uid = $ui->cparam('uid') || '';
my $msg_id = $ui->cparam('msg') || '';

if ($update && $update eq '1' && $uid) {
    my ($photo, $buffer);
    open(FH, "< $upload/$uid.jpg") or $ui->msg("Can't open $uid.jpg: $!");
    while (my $len = read(FH, $buffer, 1024)) { 
        $photo .= $buffer;
    }
    close FH;
    &update($uid, $photo);
}

my $sql = qq(select c.ki, a.uid, d.name, d.id, datediff(now(), b.updated_at) as days from bw_user_basic as a left join bw_user_ki as c using (uid) left join bw_xauth_passwd as d using (uid) left outer join bw_user_photo as b using (uid) where a.uid in ($uids));
my $rv = $dbh->selectall_hashref($sql, 'uid')
    if $uids;

if ($msg_id && $msg_id =~ /^[1-8]$/ && $uid) {
    my $id = $$rv{$uid}->{id};
    my $name = $$rv{$uid}->{name};
    my $body = ${$msg[$msg_id - 1]}{body};
    delete $$rv{$uid};
    rename "$upload/$uid.jpg", "$updated/$uid.jpg";
    &note($id, $name, $body, $dbh);
}

my @rv = map { $$rv{$_}->{msg} = \@title; $$rv{$_} } 
             sort { $$rv{$a}->{ki} <=> $$rv{$b}->{ki} || 
                    $$rv{$a}->{name} cmp $$rv{$b}->{name} } 
                 keys %$rv;
if ($#rv >= 0) {
    $ui->tparam(list=>\@rv);
} else {
    $ui->msg("모두 처리되었습니다.");
}

print $ui->output;

sub update {
    my ($uid, $photo) = @_;
    my $im = Image::Magick->new(magick=>'jpeg');
    $im->BlobToImage($photo);
    $im->Thumbnail(width=>'60', height=>'80');
    #$im->UnsharpMask(threshold=>0, radius=>0.2, amount=>300);
    my $thumb = $im->ImageToBlob(quality=>80);
    my $sql = qq(replace into bw_user_photo (uid, photo, thumb) values (?, ?, ?));
    my $rv = $dbh->do($sql, undef, $uid, $photo, $thumb);
    if ($rv) {
        my $rv2 = $dbh->do(qq(update bw_user_basic set modified=now() where uid=?), undef, $uid);
    }
    return $rv;
}

sub note {
    my ($id, $name, $body, $dbh) = @_;
    my $admin_id = $auth->id;
    my $admin_name = $auth->name;
    my $msg = <<END;
안녕하세요, 바위지기 $admin_name입니다.

$body

즐거운 바위생활 되시길...:)
END
    
    ### using note interface
    my $n = new Bawi::Main::Note( -dbh => $dbh );

    my $u = $n->get_user_info_by_id($id);
    my $to_uid = $u->{uid};
    my $to_name = $u->{name};

    my $rv = $n->send_msg($id, $to_name, $admin_id, $admin_name, $msg);


#    $sql = qq(insert into bw_note (from_id, from_name, sent_time, read_time, to_id, to_name, msg) values (?, ?, now(), now(), ?, ?, ?));
#    my $rv = $dbh->do($sql, undef, $admin_id, $admin_name, $id, $name, $msg);
    return $rv;
}

1;
