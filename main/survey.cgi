#!/usr/bin/perl -w
use strict;
use lib '../lib';

use CGI;
use Bawi::Auth;
use Bawi::User;
use Bawi::Main::UI;

my $ui = new Bawi::Main::UI();
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgiurl);
    exit (1);
}
my $whoami = $user->get_user($auth->uid());
my $name = $auth->name();
my $ki = $whoami->{'ki'};
my $grad_year = 1989+2+$ki;
my $email = $whoami->{'email'};

my $mesg = "
한국교육개발원 영재교육센터에서 ‘청장년시기(15세-45세) 과학기술인재 발달 및 육성 종합 전략 연구(2009년-2011년)’ 연구의 일환으로 전국의 과학고등학교와 과학영재학교의 졸업생들의 현재의 거취를 조사하고 있습니다. 설문 조사에 응하신 분들에게는 약 20분 정도 소요되는 추가 설문 조사가 아루어질 예정입니다. 자세한 내용은 <a href='http://www.bawi.org/board/read.cgi?bid=987&aid=1352643' target='_blank'>링크</a>를 참고해 주세요. -- 바위지기";

my $q = new CGI;
print $q->header(-charset=>'utf-8');
print "<html>\n";
print "<header><title>영재교육센터 설문참여 조사</title></header>\n";
print "<body>\n";
print $mesg,"<br>\n";

print $q->start_form(-method=>"POST"),"\n";
print "설문참여 여부",$q->radio_group(-name=>'choice',-values=>['가능','불가능','재학생'],-default=>'가능'),"<br>\n";
print "이름 ",$q->textfield(-name=>'name',-value=>$name,-maxlength=>'20'),"<br>\n";
print "Email ",$q->textfield(-name=>'email',-value=>$email),"<br>\n";
print "졸업 학교",$q->textfield(-name=>'school',-value=>"서울과학고등학교"),
  "졸업년도",$q->textfield(-name=>'grad_year',-value=>$grad_year),
  "수료여부",$q->radio_group(-name=>'is_graduate',-values=>['졸업','수료','기타']),"<br>\n";
print "학생이면 아래 항목을 기입해 주세요<br>\n";
print "학교이름:",$q->textfield(-name=>'school'), 
    "전공:",$q->textfield(-name=>'major'),
    "학위과정:",$q->radio_group(-name=>'degree',-values=>['학부','석사','박사','석박사 통합'],-default=>'학부'),"<br>\n";
print "직장인이면 아래 항목을 기입해 주세요</br>\n";
print "직장이름:",$q->textfield(-name=>'employer'),"직위:",$q->textfield(-name=>'job_title'),"</br>\n";
print $q->submit(-name=>"submit", -value=>'입력 완료'),$q->reset(),"\n";
print $q->end_form(),"\n";
print "</body></html>\n";
