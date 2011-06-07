#!/usr/bin/perl -w
use strict;
use lib '../lib';
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI(-template=>'search.tmpl');
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);
my $user = new Bawi::User(-ui=>$ui);

unless ($auth->auth) {
    print $auth->login_page($ui->cgi->url(-query=>1));
    exit(1);
}
my $keyword = $ui->cparam('keyword') || '';

$ui->tparam(menu_search=>1);
$ui->tparam(user_url=>$ui->cfg->UserURL);
$ui->tparam(note_url=>$ui->cfg->NoteURL);

if ($keyword) {
    $ui->tparam(keyword=>$ui->cgi->escapeHTML($keyword));
    my $rv = $user->search_affiliation($keyword);
    $keyword =~ s/(\[|\*|\(|\)|\{|\}|\\|\+|\?|\||\.|\&)/\\$1/g;
    my @rv = map { $$_{affiliation} =~ s/($keyword)/<span class="search">$1<\/span>/gi; $_ } @$rv;
    $ui->tparam(user=>\@rv);
    $ui->tparam(total=>scalar(@rv));
}

print $ui->output;

1;
