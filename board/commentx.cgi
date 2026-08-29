#!/usr/bin/perl -w
# Retired 2026-08-28 (PR #35): an abandoned AJAX comment endpoint from the
# original svn import (the "x" was text/xml output). Its add/delete
# actions called check_param, which only comment.cgi defines, so every
# mutation 500ed since introduction -- and nothing (template, JS, or CGI)
# has ever linked here, on main or on the production snapshot.
# comment.cgi is the comment endpoint. Kept as a placeholder because the
# URL is web-mapped (cf. the non-mapped search/search.cgi precedent).
use strict;
use CGI ();
# CGI.pm routes the header through the mod_perl request record; a raw
# printed header is NOT parsed here (no PerlOptions +ParseHeaders on the
# board/ vhost) and would arrive as body text.
print CGI->new->header(-type => 'text/plain', -charset => 'utf-8'), "Closed.\n";
1;
