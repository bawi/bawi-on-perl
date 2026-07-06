# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is **Bawi** - a Korean community bulletin board system (BBS) written in Perl using mod_perl and Apache. It's a mature, production-ready web application designed for Korean community websites.

## Technology Stack

- **Language**: Perl (CGI scripts and modules)
- **Web Server**: Apache with mod_perl
- **Database**: MariaDB 10.6 (MySQL wire-compatible; use the `mariadb` client)
- **Template System**: Custom `.tmpl` files
- **Character Encoding**: UTF-8
- **Session Management**: Cookie-based authentication

## Project Structure

- `/admin/` - Administrative tools and user management
- `/board/` - Main bulletin board functionality (posting, reading, commenting)
- `/main/` - Main site entry points and general pages
- `/user/` - User profile and account management
- `/reg/` - User registration system
- `/lib/Bawi/` - Core Perl modules implementing business logic
- `/conf/` - Configuration files (main.conf, board.conf, user.conf)
- `/db/` - Database schema and migration scripts
- `/apache2/` - Apache and mod_perl configuration
- `/postman/` - Email inquiry system (`postman.pl`)
- `/search/` - Legacy; `search/search.cgi` is a `Closed.` placeholder

## Common Development Tasks

### Running the Application
This is a mod_perl application that runs directly through Apache. Key environment variables are set in `apache2/startup.pl`:
- `BAWI_PERL_HOME`: /home/bawi/bawi-spring/
- `BAWI_DATA_HOME`: /home/bawi/bawi-data/

### Database Migrations
The live database is named **`bawi`** (the `bawi_on_perl` value in `conf/*.conf.sample` is a
generic placeholder — the real name is in the gitignored `conf/*.conf` on the host). Apply
every migration in `db/` in filename (chronological) order — don't hardcode a list here, it
goes stale as new migrations land:
```bash
for f in db/2*.sql; do echo "applying $f"; mariadb bawi < "$f"; done
# as of this writing, in order:
#   20161225_add_career_enum.sql
#   20201030_add_expiration_days.sql
#   20201031_create_commentref.sql
#   20220903_add_retraction.sql
#   20221221_retroactive_change_delete_comment.sql
```

### System Monitoring
- `/admin/load.pl` - Records system load (runs via cron every minute)

### User Management
- `/admin/reg.sql` - Process recommended users from staging to production
- `/postman/postman.pl` - Email inquiry system

### Testing
- `/board/test.cgi` - Test script for board functionality

## Configuration

Main configuration files are in `/conf/`:
- Copy `.conf.sample` files to `.conf` for initial setup
- Key settings include database credentials, cookie configuration, and paths

## Required Perl Modules

- CGI
- DBI
- Image::Magick
- Locale::Maketext
- Apache::DBI
- ModPerl::Registry

## Architecture Notes

The application follows a traditional CGI architecture with:
- CGI scripts serving as entry points for different features
- Perl modules in `/lib/Bawi/` containing business logic
- Template files (`.tmpl`) for HTML generation
- Direct database queries using DBI

Each major section (board, user, admin) has its own set of CGI scripts and corresponding template files in `skin/default/` subdirectories.

## Git Branch Information

The canonical branch is **`main`** (promoted from the former `resp2` line, which was the
deployed branch). As captured from the production host on 2026-07-06, the deploy tree at
`/home/bawi/bawi-spring` was checked out on `resp2`; the maintenance cutover repoints it at
`main`. Always confirm with `git -C /home/bawi/bawi-spring branch --show-current` rather than
trusting this note.

**Git identity on the host**: user "bawi service account", email `bawi@orange.bawi.org`.

## Working-Tree Drift

Production has historically carried uncommitted changes edited in place. Do **not** trust a
static list here — it goes stale the moment the box changes. Check live state directly:
```bash
git -C /home/bawi/bawi-spring status
```
The 2026-07 snapshot of that drift was preserved on branch `resp2-live-snapshot`. Credential
files (`conf/*.tmp`) are gitignored and stay on the host only — never commit them.

## Code Management Guidelines

- **Critical Production Guideline**: 
  - Do not change the code without explicit approval from the user as this is a production server and it is currently running.
  - If new features are made, make minimal modifications to existing code (functions, scripts) to avoid unintended modifications of running code
