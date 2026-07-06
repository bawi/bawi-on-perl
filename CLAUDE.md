# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is **Bawi** - a Korean community bulletin board system (BBS) written in Perl using mod_perl and Apache. It's a mature, production-ready web application designed for Korean community websites.

## Technology Stack

- **Language**: Perl (CGI scripts and modules)
- **Web Server**: Apache with mod_perl
- **Database**: MySQL
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

## Common Development Tasks

### Running the Application
This is a mod_perl application that runs directly through Apache. Key environment variables are set in `apache2/startup.pl`:
- `BAWI_PERL_HOME`: /home/bawi/bawi-spring/
- `BAWI_DATA_HOME`: /home/bawi/bawi-data/

### Database Migrations
SQL migration files are located in `/db/`. Run them in chronological order:
```bash
mysql bawi_on_perl < db/20161225_add_career_enum.sql
mysql bawi_on_perl < db/20201030_add_expiration_days.sql
mysql bawi_on_perl < db/20201031_create_commentref.sql
mysql bawi_on_perl < db/20220903_add_retraction.sql
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

**Current Branch**: `resp2` - This is an extended branch that accommodates production server requirements and builds upon the original codebase.

**Git Configuration**:
- User: bawi service account
- Email: bawi@orange.bawi.org

**Branch History**:
- The `resp2` branch diverged from the main development to handle production-specific needs

## Uncommitted Changes

There are currently uncommitted changes that need review before committing:

**Modified Files** (need scrutiny):
- `board/test.cgi` - Test script changes

**Untracked Files** (new additions):
- Beta/experimental features in `/board/` (read_beta.cgi, dark theme CSS, etc.)
- Session management tools (mysessions.cgi, remove_session.cgi)
- Temporary configuration files (*.tmp in /conf/)
- SEO verification files (Google, Bing auth files)
- Database helper scripts (reg2.sql, regtemp.sql)

When reviewing uncommitted changes, pay special attention to:
1. Security implications in Auth.pm and login-related files
2. Analytics template changes for privacy compliance
3. Beta features that may not be production-ready

## Code Management Guidelines

- **Critical Production Guideline**: 
  - Do not change the code without explicit approval from the user as this is a production server and it is currently running.
  - If new features are made, make minimal modifications to existing code (functions, scripts) to avoid unintended modifications of running code
