#!/usr/bin/perl -w
##############################################
# POSTMAN by indepth 2005. 04. 02. (4th rev)
##############################################
# TODO : DBI error message web으로 출력하도록 하기.


# NOMENCLATURE
# -------------------
# sender   : 이메일 주소를 문의하는 사람을 가리킨다.
# bawier   : 문의의 대상이 되는 사람을 가리킨다.
# 

use strict;
use CGI;
use DBI;
use MIME::Base64;
use HTML::Template;

###############################
# GLOBAL VARIABLES 
###############################
my $form_action = "index.pl"; # form_action은 자기자신이다.
my $reply_email = "postman\@bawi.org"; # 보낸 e-mail 주소이다. (발송금지)
my $email_validation = "^[A-z0-9_\\-\.]+[\@][A-z0-9_\\-]+([.][A-z0-9_\\-]+)+[A-z]\$";


###############################
# DB ROUTINES
###############################
sub db_connect {
    return DBI->connect() or 
        die("Couldn't connect");
}

sub search_bawier {
    # "이름"을 받으면, bawi DB에서 이름과 소속, 기수 정보를 받아와서 i
    # request template의 RECIPIENT_LOOP type에 맞도록 return한다.

    # INPUT argument
    my ($bawier_name) = @_;

    # OUTPUT return variable
    my @loop_data = ();

    # QUERY strings : 0=uid, 1=name, 2=email, 3=job, 4=ki
    my $query_search_bawier = "select x.uid,x.name,x.email,y.affiliation,z.ki from bw_xauth_passwd as x, bw_user_basic as y, bw_user_ki as z WHERE x.uid = y.uid AND x.uid = z.uid AND x.name like ?;";

    # Temporary Local variables
    my $dbh;                        # for DBI connection
    my $sth;                        # for Query string preparation
    my @resptr;                     # for fetching.

    # sub-routine code

    $dbh = &db_connect();
    $sth = $dbh->prepare($query_search_bawier);
    $sth->execute($bawier_name);


    if ($sth->rows > 0) {

        while ( @resptr = $sth->fetchrow_array() ) {
            my %row_data;           # RECIPIENT_LOOP에 알맞는 hash한 줄.

            $row_data{ bawier_uid }  = $resptr[0];
            $row_data{ bawier_name } = $resptr[1];
            $row_data{ bawier_ki }   = $resptr[4];
            $row_data{ bawier_org }  = $resptr[3];

            $row_data{ bawier_notes } = ($resptr[2]) ? 1 : 0;

            push @loop_data, \%row_data;
        }
    }

    $dbh->disconnect;
   
    return @loop_data;
}

sub get_bawier_email {
    # uid를 받으면, bawi DB에서 이름, 소속, e-mail을 return한다.

    # INPUT argument
    my ($bawier_uid) = @_;

    # OUTPUT return variable
    my %return_data;

    # QUERY strings : 0=name, 1=email, 2=job
    my $query_get_bawier_email = "select x.name, x.email, y.affiliation from bw_xauth_passwd as x, bw_user_basic as y WHERE x.uid = y.uid AND x.uid = ?;";

    # Temporary Local variables
    my $dbh;                        # for DBI connection
    my $sth;                        # for Query string preparation
    my @resptr;                     # for fetching.
   
    # sub-routine code

    $dbh = &db_connect();
    $sth = $dbh->prepare($query_get_bawier_email);
    $sth->execute($bawier_uid);

    @resptr = $sth->fetchrow_array();

    $return_data{ bawier_name } = $resptr[0];
    $return_data{ bawier_email } = $resptr[1];
    $return_data{ bawier_org } = $resptr[2];

    return %return_data;
}

sub check_bawier_uid_name {
    # uid와 이름이 들어왔을 때, 이들이 match하는지 확인하는 것이다.
    # 만약, 존재한다면, 제대로 된 접근이므로, 1을, 아니면 0을 return.

    # INPUT argument
    my ($bawier_uid, $bawier_name) = @_;

    # QUERY strings
    my $query_bawier_uid_name = 
        "SELECT uid from bw_xauth_passwd WHERE uid = ? AND name = ?;";

    # OUTPUT return variable
    my $bawier_exist = 0;
    
    # Temporary Local variables
    my $dbh;                        # for DBI connection
    my $sth;                        # for Query string preparation
    my @resptr;                     # for fetching.

    # sub-routine code

    $dbh = &db_connect();
    $sth = $dbh->prepare( $query_bawier_uid_name );
    $sth->execute( $bawier_uid, $bawier_name );

    if ($sth->rows > 0) {
        $bawier_exist = 1;
    }

    $dbh->disconnect;

    return $bawier_exist;
}

sub put_postman_log {
    # 모든 메일 발송이 끝난 직후에, log를 남긴다.
    # log관련 table정의는 http://wiki.dev.bawi.org/wiki/BawiPostman 참고.

    # INPUT argument
    my (%log_item) = @_;

    # QUERY strings
    my $query_put_postman_log =
        "INSERT INTO bw_postman_log( postman_id, sender_name, sender_email, sender_ip, sender_org, bawi_uid, submit_time ) VALUES (NULL,?,?,?,?,?,?);";

    # Temporary Local variables
    my $dbh;                        # for DBI connection
    my $sth;                        # for Query string preparation
    my @resptr;                     # for fetching.

    # sub-routine code

    $dbh = &db_connect();
    $sth = $dbh->prepare( $query_put_postman_log );
    $sth->execute(  $log_item{ sender_name },
                    $log_item{ sender_email },
                    $log_item{ sender_ip },
                    $log_item{ sender_org },
                    $log_item{ bawi_uid },
                    $log_item{ submit_time } );
    $dbh->disconnect;
}


###############################
# MAIL ROUTINE
###############################
sub send_mail {
    # 특정한 string을 갖고 와서 mailing을 수행한다.

    # INPUT argument
    my ($mail_content) = @_;
    
    open (MAIL, "| /usr/sbin/exim4 -t");
    print MAIL "Content-type: text/plain; charset=\"utf-8\"\n"; 
    print MAIL $mail_content; 
    close MAIL;
}

sub send_mail_to_sender {
    # 의뢰자에게 전달되는 mail이다. template에 들어갈 내용은 tmpl dir참고.
    # mailing은 여기서 직접 send_mail sub-routine을 호출한다.
    # required argument keys : 
    #   sender_email, bawier_name, bawier_org, sender_name, sender_org,
    #   sender_message

    # INPUT argument
    my (%arg) = @_;
   
    # Temporary Local variables
    my $mail_response = HTML::Template->new(filename => 'tmpl/mail_response');

    $mail_response->param( sender_email => $arg{ sender_email } );
    $mail_response->param( reply_email  => $reply_email );
    $mail_response->param( bawier_name  => $arg{ bawier_name } );
    $mail_response->param( bawier_org   => $arg{ bawier_org } );
    $mail_response->param( sender_name  => $arg{ sender_name } );
    $mail_response->param( sender_org   => $arg{ sender_org } );
    $mail_response->param( sender_message => $arg{ sender_message } );

    my @subject_words = (
        "[천년바위postman] ", 
        $arg{ bawier_name }."님께 연락 요청 ",
        "메일을 발송하였습니다." 
    );
    my $subject_header = join("\n\t",
        map { "=?UTF-8?B?" . encode_base64($_, "") . "?=" } @subject_words
    );

    $mail_response->param( response_subject => $subject_header );

    &send_mail( $mail_response->output() ); # Template의 출력물을 그대로 MAIL.
}

sub send_mail_to_bawier {
    # 서울과학고등학교 동창에게 전달되는 mail이다. template내용은 tmpl dir참고.
    # mailing은 여기서 직접 send_mail sub-routine을 호출한다.
    # required argument keys :
    #   bawier_email, sender_name, sender_org, sender_email, sender_message

    # INPUT argument
    my (%arg) = @_;

    # Temporary Local variables
    my $mail_contact = HTML::Template->new(filename => 'tmpl/mail_contact');

    $mail_contact->param( bawier_email => $arg{ bawier_email } );
    $mail_contact->param( reply_email  => $reply_email );
    $mail_contact->param( sender_name  => $arg{ sender_name } );
    $mail_contact->param( sender_email => $arg{ sender_email } );
    $mail_contact->param( sender_org   => $arg{ sender_org } );
    $mail_contact->param( sender_email => $arg{ sender_email } );
    $mail_contact->param( sender_message => $arg{ sender_message } );

    my @subject_words = (
        "[천년바위postman] ",
        $arg{ sender_name }."님으로부터 ",
        "연락 요청이 왔습니다."
    );
    my $subject_header = join("\n\t",
        map { "=?UTF-8?B?" . encode_base64($_, "") . "?=" } @subject_words
    );

    $mail_contact->param( contact_subject => $subject_header );

    &send_mail( $mail_contact->output() ); # Template의 출력물을 그대로 MAIL.
}

###############################
# MAIN ROUTINE
###############################

my $q = new CGI;
my $header   = HTML::Template->new(filename => 'tmpl/header');
my $request  = HTML::Template->new(filename => 'tmpl/request');
my $search   = HTML::Template->new(filename => 'tmpl/search');
my $invalid  = HTML::Template->new(filename => 'tmpl/invalidaccess');
my $complete = HTML::Template->new(filename => 'tmpl/complete');
my $footer   = HTML::Template->new(filename => 'tmpl/footer');

# PAGE 초기화.
$search->param( form_action => $form_action );
$request->param( form_action => $form_action );

print $q->header(-charset => 'utf-8');
print $header->output();

if ( $ENV{'REQUEST_METHOD'} && $ENV{'REQUEST_METHOD'} eq "POST" ) {
    if (    $q->param('action') eq "request" and 
            $q->param('bawier_name') and
            $q->param('uid_select')  and 
            $q->param('sender_name') and
            $q->param('sender_email') and
            ($q->param('sender_email') =~ /$email_validation/g) and
            $q->param('sender_message') ) {
        # 동창 인명을 찾아서 요청한 사항들을 모두 완수하여 request하는 것이다.
        # 따라서 이제 mailing을 하면 된다. 물론, 제대로 된 request인지, id와
        # 이름을 matching하는 작업을 먼저 해야한다.
       
        # 일단 uid와 이름을 동시에 찾아서 잘못된 접근인지 아닌지 확인한다.
        if (&check_bawier_uid_name( $q->param('uid_select'), 
                                     $q->param('bawier_name') )) {

            # email, name, org 정보를 받아온다.
            my %bawier_info = &get_bawier_email( $q->param('uid_select') );

            # bawier에게 메일을 보낸다.
            &send_mail_to_bawier(
                bawier_email => $bawier_info{bawier_email},
                bawier_name  => $bawier_info{bawier_name},
                bawier_org   => $bawier_info{bawier_org},
                sender_email => $q->param( 'sender_email' ),
                sender_name  => $q->param( 'sender_name' ),
                sender_org   => $q->param( 'sender_org' ),
                sender_message => $q->param( 'sender_message' )
            );

            # sender에게 메일을 보낸다.
            &send_mail_to_sender(   
                sender_email => $q->param( 'sender_email' ),
                bawier_name  => $bawier_info{bawier_name},
                bawier_org   => $bawier_info{bawier_org},
                sender_name  => $q->param( 'sender_name' ),
                sender_org   => $q->param( 'sender_org' ),
                sender_message => $q->param( 'sender_message' ) 
            );
            
            # log를 기록한다.
            my %log_item;
            %log_item = (   sender_name  => $q->param( 'sender_name' ),
                            sender_email => $q->param( 'sender_email' ),
                            sender_ip    => $ENV{'REMOTE_ADDR'},
                            sender_org   => $q->param( 'sender_org' ),
                            bawi_uid     => $q->param( 'uid_select' ) );

            my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
            $log_item{ submit_time } = 
                sprintf("%04d-%02d-%02d %02d:%02d:%02d", 
                            $year+1900, $mon+1, $mday, $hour, $min, $sec);
            
            &put_postman_log(%log_item);
                            
            # 완료 메세지를 찍고, search page를 재출력한다.
            $complete->param( sender_email => $q->param( 'sender_email' ));

            print $complete->output();
            print $search->output();
        } else {
            print $invalid->output();
            print $search->ouput();
        }
    } else {
        # 잘못된 접근이다.
        print $invalid->output();
        print $search->output();
    }
} else { 
    # GET METHOD로 접근했거나 아니면 REQUEST_METHOD가 빠진 거다.
    if ( $q->param('action') eq "search" ) {
        # 동창이름을 입력했다. 이제 DB에서 그 이름을 찾아서 출력해준다.

        my @recipient_loop = &search_bawier( $q->param("bawier_name") );

        if (scalar @recipient_loop == 0) {
            $request->param( NO_MATCH => 1 );
            print $request->output();
            print $search->output();
        } else {
            $request->param( NO_MATCH => 0 );
            $request->param( bawier_name => $q->param("bawier_name") );
            $request->param( RECIPIENT_LOOP => \@recipient_loop );
            print $request->output();
        }
    } else {
        # 처음이다.
        print $search->output();
    }
}

print $footer->output();
# End of postman bawi.
