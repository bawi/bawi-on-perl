# Bawi on Perl

Codebase of [bawi.org](https://bawi.org) — a Korean-community bulletin-board
system in Perl 5, running on Apache2 + mod_perl (ModPerl::Registry) with
MariaDB. No web framework, no build step: plain CGI scripts and server-side
HTML templates.

## Philosophy

Fast and lightweight. Prefer plain Perl, server-rendered templates, and a
minimal dependency set over frameworks and heavy libraries (the complete
dependency list fits in `docker/web/Dockerfile`).

## Layout

* `lib/Bawi/` — core modules (Auth, Board, User, DBI wrapper)
* `main/ board/ user/ reg/ admin/ search/ postman/` — CGI endpoints with
  their `tmpl/` templates, URL-mapped 1:1 in the Apache vhost
* `apache2/` — vhost configs and mod_perl `startup.pl`
* `conf/` — `*.conf.sample` templates (real configs live untracked on prod)
* `db/` — MariaDB schema dump and dated migration scripts
* `bin/`, `t/` — CLI utilities and smoke tests
* `docker/`, `seed/` — local test environment (see below)

## Local development

A reproducible Docker test environment (same stack as prod, synthetic data)
ships with the repo — see [INSTALLATION.md](INSTALLATION.md):

```sh
docker compose up -d --build
./seed/reseed.sh
# http://localhost:8080/  (login: root / test1234)
```

## Deployment

Production runs the `main` branch; a deploy is a `git pull` on the server.
