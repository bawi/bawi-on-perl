#!/usr/bin/perl -w
use strict;
use lib '../lib';

use JSON::PP qw(encode_json);
use Bawi::Auth;
use Bawi::User;
use Bawi::User::UI;

my $ui = new Bawi::User::UI();
my $auth = new Bawi::Auth(-cfg=>$ui->cfg, -dbh=>$ui->dbh);

unless ($auth->auth) {
    print $ui->cgi->header(-type=>'application/json', -charset=>'utf-8');
    print '[]';
    exit(1);
}

my $user = new Bawi::User(-ui=>$ui);
my $q = $ui->cparam('q') || '';
my $org = $q =~ /\S/ ? $user->org_suggest($q) : [];

print $ui->cgi->header(-type=>'application/json', -charset=>'utf-8');
# DBD::mysql returns UTF-8 *bytes* (no mysql_enable_utf8 on the handle, per house
# style). encode_json re-encodes its input as UTF-8, so byte strings double-encode
# into mojibake. Decode each name to Perl chars first → encode_json emits clean UTF-8.
print encode_json([ map { my $n = $_->{name}; utf8::decode($n); +{id=>$_->{org_id}, name=>$n} } @$org ]);

1;
