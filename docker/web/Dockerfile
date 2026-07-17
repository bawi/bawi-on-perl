# Web container for the bawi-on-perl LOCAL test environment.
# Mirrors production: Ubuntu 22.04, Apache 2.4 + mod_perl2 (ModPerl::Registry),
# Perl 5.34, MariaDB client libs. The application code is NOT baked into the
# image — the repo working tree is bind-mounted at /home/bawi/bawi-spring.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Core stack + every EXTERNAL Perl module the app needs:
#   libapache2-mod-perl2      -> mod_perl2 / ModPerl::Registry
#   libapache-dbi-perl        -> Apache::DBI (persistent DB handles)
#   libdbd-mysql-perl         -> DBD::mysql (DSNs are "dbi:mysql:...")
#   libcgi-pm-perl            -> CGI, CGI::Cookie
#   libhtml-template-perl     -> HTML::Template
#   libimage-magick-perl      -> Image::Magick (PerlMagick)
#   libtext-iconv-perl        -> Text::Iconv
#   liburi-perl               -> URI::Escape
#   libjson-perl              -> JSON (board/comment.cgi Twitter embed)
#   libgd-perl                -> GD (main/process/graph.cgi)
#   Locale::Maketext, Digest::MD5, HTTP::Tiny, Encode, Benchmark -> perl core
# Text::Markdown needs no package: it is vendored at lib/Text/Markdown.pm and
# resolved via startup.pl's `use lib`. GeoIP2::WebService::Client is
# intentionally NOT installed: nothing in this repo imports it (verified by
# grep); it belongs to a skipped optional feature.
RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 \
        libapache2-mod-perl2 \
        libapache-dbi-perl \
        libdbi-perl \
        libdbd-mysql-perl \
        libcgi-pm-perl \
        libhtml-template-perl \
        libimage-magick-perl \
        libtext-iconv-perl \
        liburi-perl \
        libjson-perl \
        libgd-perl \
        mariadb-client \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# HTML::ParseBrowser is a HARD dependency of Bawi::Auth (use'd at
# lib/Bawi/Auth.pm:10, hit on every login) but is NOT packaged in Ubuntu
# 22.04 ("Unable to locate package libhtml-parsebrowser-perl") — install it
# from CPAN. The perl -M gate below fails the build if this ever breaks.
RUN apt-get update \
    && apt-get install -y --no-install-recommends cpanminus make \
    && cpanm --notest HTML::ParseBrowser \
    && rm -rf /var/lib/apt/lists/*

# Fail the build early if any compile-time dependency is missing.
RUN perl -MApache::DBI -MDBI -MDBD::mysql -MCGI -MCGI::Cookie \
         -MHTML::Template -MImage::Magick -MText::Iconv -MHTML::ParseBrowser \
         -MURI::Escape -MLocale::Maketext -MJSON -MGD -MDigest::MD5 \
         -e 'print "perl deps OK\n"'

# Apache: prefork MPM (legacy CGI-style app, matches prod), mod_perl,
# plain mod_cgi for the couple of AddHandler'd .pl scripts.
RUN a2dismod -q mpm_event \
    && a2enmod -q mpm_prefork perl cgi include rewrite \
    && a2dissite -q 000-default

COPY bawi-test.conf /etc/apache2/sites-available/bawi-test.conf
RUN a2ensite -q bawi-test

# Route Apache's GLOBAL logs to the container's stdout/stderr so Perl
# warn()/die() output (which lands in the global error log, not the vhost
# log) shows up in `docker compose logs web`.
RUN ln -sfT /dev/stderr /var/log/apache2/error.log \
    && ln -sfT /dev/stdout /var/log/apache2/access.log \
    && ln -sfT /dev/stdout /var/log/apache2/other_vhosts_access.log

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
