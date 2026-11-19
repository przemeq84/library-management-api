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

## API

JSON over HTTP; send request bodies with `Content-Type: application/json`. There is no authentication.

### Pagination

List endpoints return a plain JSON array. Use `page` (positive integer, default `1`) and `per_page` (integer from `1`
to `100`, default `25`). Invalid values, including empty ones, are rejected with 400 rather than adjusted.

### Errors

Errors share one shape. The HTTP status code is in the response status; `error.status` repeats it as Rails' status
name. `details` holds per-field validation messages for 422 and is `null` otherwise:

```json
{ "error": { "status": "unprocessable_content", "message": "Email has already been taken", "details": { "email": ["has already been taken"] } } }
```

## Running tests

```bash
bundle exec rspec      # coverage report in coverage/index.html
```

With `CI` set (GitHub Actions, `bin/ci`), the run fails below 90% line or 80% branch coverage.

Lint and security checks:

```bash
bin/rubocop
bin/mdl
bin/brakeman --no-pager
bin/bundler-audit
```

All of the above (plus `bin/setup`) run in one go with:

```bash
bin/ci
```

## Continuous integration

GitHub Actions (`.github/workflows/ci.yml`) runs `bin/ci` on every pull request and on pushes to `main`.
The checks are defined once in `config/ci.rb`, so CI runs exactly what `bin/ci` runs locally.
The SimpleCov report is uploaded as the `coverage` artifact.
