# Library Management API

A JSON API for library staff to manage books, readers and borrowings.

Built with Ruby on Rails (API-only), PostgreSQL and Solid Queue.

Key design decisions are recorded in [DecisionLog.md](DecisionLog.md).

## Quick start (Docker)

```bash
docker compose up --build
```

The API is then available on <http://localhost> (port 80), already filled with the [demo data](#demo-data), for example
`curl localhost/books`. The containers run in development mode, so `docker compose logs -f` shows debug logs (including
SQL) and mailer previews are at <http://localhost/rails/mailers>. The image is built from the Dockerfile, so code
changes need `docker compose up --build`.

Emails aren't sent; they appear in the worker's debug log (`docker compose logs -f jobs`). To send the pending reminders
without waiting for 8am:

```bash
docker compose exec jobs bin/rails runner 'SendDueDateRemindersJob.perform_now("due_soon")'
docker compose exec jobs bin/rails runner 'SendDueDateRemindersJob.perform_now("due_today")'
```

`.env` file is optional. Settings from [Configuration](#configuration) can be put in `.env`. `docker compose down -v`
removes the containers and the database.

## Requirements

- Ruby 4.0.10 (see `.ruby-version`)
- PostgreSQL 14+

## Local setup (without Docker)

Any PostgreSQL works; the compose database can be used on its own with `docker compose up -d db` and
`DB_HOST=localhost`, `DB_USER=postgres`, `DB_PASSWORD=postgres` in `.env`.

```bash
bundle install
cp .env.example .env   # optional, adjust as needed
bin/rails db:prepare   # creates the primary and queue databases
bin/rails server       # API on http://localhost:3000
bin/jobs               # Solid Queue worker + recurring tasks (separate terminal)
```

### Demo data

`bin/rails db:prepare` loads `db/seeds.rb` when it creates the database; run `bin/rails db:seed` to load it again (it
is idempotent).

## Configuration

Every variable is optional. Locally they can be put in `.env`, which is loaded by `dotenv-rails`.

| Variable          | Default                  | Purpose                                                  |
| ----------------- | ------------------------ | -------------------------------------------------------- |
| `TZ`              | `UTC`                    | App time zone (IANA name), also used as the OS time zone |
| `DB_HOST`         | local socket             | PostgreSQL host                                          |
| `DB_PORT`         | `5432`                   | PostgreSQL port                                          |
| `DB_USER`         | OS user                  | PostgreSQL role                                          |
| `DB_PASSWORD`     | none                     | PostgreSQL password                                      |
| `DB_GSSENCMODE`   | `disable`                | libpq GSSAPI encryption; `disable` avoids a macOS crash  |
| `SECRET_KEY_BASE` | none (production only)   | Generate with `bin/rails secret`                         |
| `RAILS_LOG_LEVEL` | `info` (production only) | Log verbosity                                            |
| `MAILER_FROM`     | `library@example.com`    | Sender address of reminder emails                        |

## API

JSON over HTTP; send request bodies with `Content-Type: application/json`. There is no authentication.

### Endpoints

| Endpoint                 | Body                                 | Errors        | Notes                                     |
| ------------------------ | ------------------------------------ | ------------- | ----------------------------------------- |
| `GET /readers`           |                                      | 400           | Ordered by card number, paginated         |
| `POST /readers`          | `reader: card_number, name, email`   | 400, 422      | `email` is optional                       |
| `DELETE /readers/:id`    |                                      | 404, 409      | Soft delete; 409 while a book is borrowed |
| `GET /books`             |                                      | 400           | Ordered by serial number, paginated       |
| `GET /books/:id`         |                                      | 404           | History newest first                      |
| `POST /books`            | `book: serial_number, title, author` | 400, 422      |                                           |
| `DELETE /books/:id`      |                                      | 404, 409      | Soft delete; 409 while borrowed           |
| `POST /books/:id/borrow` | `reader_card_number`                 | 400, 404, 409 | Due in 30 days                            |
| `POST /books/:id/return` | `reader_card_number`                 | 400, 404, 409 | 409 unless this reader has it             |

Request bodies are JSON objects, e.g. `{ "reader": { "card_number": "100007", "name": "Ada" } }` or
`{ "reader_card_number": "100001" }`.

### Pagination

List endpoints return a plain JSON array. Use `page` (positive integer, default `1`) and `per_page` (integer from `1`
to `100`, default `25`). Invalid values, including empty ones, are rejected with 400 rather than adjusted.

### Errors

Errors share one shape. The HTTP status code is in the response status; `error.status` repeats it as Rails' status
name. `details` holds per-field validation messages for 422 and is `null` otherwise:

```json
{ "error": { "status": "unprocessable_content", "message": "Email has already been taken", "details": { "email": ["has already been taken"] } } }
```

## Emails

No real emails are sent.

Locally that is `log/development.log`, including emails delivered by `bin/jobs`. Tests use the standard `:test`
delivery method.

### Due-date reminders

Books are due 30 days after borrowing. `SendDueDateRemindersJob` runs from Solid Queue's recurring schedule
(`config/recurring.yml`) every day at 8am in the app time zone (`TZ`), once per reminder:

- `due_soon`: books due within the next 3 days
- `due_today`: books due today, or overdue by up to 7 days if a run was missed (then the email says "was due on …")

For each borrowing that needs a reminder it enqueues a `SendReminderJob`, which atomically records the reminder as sent
(`*_reminder_sent_at`) and then sends it. A reminder is therefore sent at most once, even if the scheduler runs twice; a
delivery error releases it for a retry. A missed day is caught up on the next run, and returned books and readers
without an email are skipped. Run it by hand with:

```bash
bin/rails runner 'SendDueDateRemindersJob.perform_now("due_soon")'
```

In development, preview both emails at <http://localhost:3000/rails/mailers/reminder_mailer>.

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
