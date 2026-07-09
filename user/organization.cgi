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
# Names are stored HTML-escaped (house style). unescapeHTML reverses that so the
# JS type-ahead shows clean text AND a picked name round-trips: on save career.cgi
# re-escapes it to the stored form and resolve_or_create_org matches the existing
# org (no double-escaped duplicate). Then decode UTF-8 bytes -> Perl chars so
# encode_json emits clean UTF-8 (DBD::mysql returns bytes; encode_json re-encodes,
# which would otherwise double-encode into mojibake).
print encode_json([ map { my $n = $ui->cgi->unescapeHTML($_->{name}); utf8::decode($n); +{id=>$_->{org_id}, name=>$n} } @$org ]);

1;
