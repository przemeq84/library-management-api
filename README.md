# Library Management API

A JSON API for library staff to manage books, readers and borrowings. 

Built with Ruby on Rails (API-only), PostgreSQL and Solid Queue.

Key design decisions are recorded in [DecisionLog.md](DecisionLog.md).

## Requirements

- Ruby 4.0.10 (see `.ruby-version`)
- PostgreSQL 14+

## Local setup

```bash
bundle install
cp .env.example .env   # optional, adjust as needed
bin/rails db:prepare   # creates the primary and queue databases
bin/rails server       # API on http://localhost:3000
bin/jobs               # Solid Queue worker + recurring tasks (separate terminal)
```

## Configuration

Every variable is optional. Locally they can be put in `.env`, which is loaded by `dotenv-rails`.

| Variable          | Default                  | Purpose                                                  |
| ----------------- | ------------------------ | -------------------------------------------------------- |
| `TZ`              | `UTC`                    | App time zone (IANA name), also used as the OS time zone |
| `DB_HOST`         | local socket             | PostgreSQL host                                          |
| `DB_PORT`         | `5432`                   | PostgreSQL port                                          |
| `DB_USER`         | OS user                  | PostgreSQL role                                          |
| `DB_PASSWORD`     | none                     | PostgreSQL password                                      |
| `SECRET_KEY_BASE` | none (production only)   | Generate with `bin/rails secret`                         |
| `RAILS_LOG_LEVEL` | `info` (production only) | Log verbosity                                            |

## Running tests

```bash
bundle exec rspec
```

Lint and security checks:

```bash
bin/rubocop
bin/mdl
bin/brakeman --no-pager
bin/bundler-audit
```
