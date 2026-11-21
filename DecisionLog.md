# Decision Log

- [Application setup and deployment](#application-setup-and-deployment)
- [Development tooling and code quality](#development-tooling-and-code-quality)
- [Domain and data model](#domain-and-data-model)
- [HTTP API](#http-api)
- [Background jobs and reminders](#background-jobs-and-reminders)

## Application setup and deployment

### Time zone from the TZ environment variable

*Chosen*: `config.time_zone = ENV.fetch("TZ", "UTC")`. The same `TZ` variable is passed to the containers.

*Alternatives considered*: a custom `APP_TIME_ZONE` variable; a hard-coded zone in `application.rb`.

Due dates and reminders are day-based, so "today" has to mean the library's local day. `TZ` also sets the OS zone, which
Solid Queue's recurring schedules use, so a single variable keeps "every day at 8am" and `Time.zone.today`
consistent. This assumes the library has a single location; supporting several locations across time zones would
require a per-location time zone setting.

### Production mode in Docker Compose

*Chosen*: `docker compose up` builds the generated Dockerfile and runs it with `RAILS_ENV=production`.

*Alternatives considered*: `RAILS_ENV=development` (debug logs, mailer previews, no secrets, but development gems
missing from the image)

The Dockerfile builds a production image without development gems, so running it in production mode keeps the
containers consistent with how they were built. Sent emails are visible through
[letter_opener_web](#sent-emails-in-letter_opener_web), so debug logs are not needed to read them. This also reduce
noise in logs. The app uses no cookies, sessions, signed values or credentials, so a placeholder secret keeps
`docker compose up` free of setup steps in a private container.

### Separate jobs container

*Chosen*: a `jobs` service runs `bin/jobs` from the same image, next to the `web` service.

*Alternatives considered*: running Solid Queue inside Puma (`SOLID_QUEUE_IN_PUMA`).

Web requests and background work scale and restart independently, and job logs are separated from request logs.
Running inside Puma would save one container, which matters more on a small single-server deployment than here. It
also means the sent emails have to be shared between the containers through a volume.

## Development tooling and code quality

### RSpec with FactoryBot

*Chosen*: `rspec-rails` with `factory_bot_rails`, and SimpleCov for coverage.

*Alternatives considered*: Minitest with fixtures (the Rails default).

This was the developer's personal preference.

### Markdown style checked by mdl

*Chosen*: the `mdl` gem (markdownlint for Ruby) with all default rules, and MD013 set to 120 characters (ignoring code
blocks and tables), run through `bin/mdl` locally and in CI.

*Alternatives considered*: RuboCop (it lints Ruby only; `rubocop-md` checks just the Ruby code blocks inside Markdown).

Markdown files follow markdownlint's default rules with 120-character lines, enforced in CI so all Markdown files stay
consistent. Individual rules can be relaxed in `.mdl_style.rb` if they get in the way.

## Domain and data model

### Borrowings as their own table

*Chosen*: a separate `borrowings` table.

*Alternatives considered*: `borrowed_at` / `reader_id` columns on `books` with a separate history table.

One table gives both the current state and the full history the book view needs. It also allows a row lock to
serialize concurrent requests and avoid race conditions.

### Borrowing.borrow! and Borrowing.return! instead of a service class

*Chosen*: borrow and return are class methods on `Borrowing`.

*Alternatives considered*: service objects (`BorrowBook`, `ReturnBook`); instance methods on `Book`.

Both operations act only on `Borrowing` records, so they naturally belong there.
Each operation is a few lines touching one aggregate, so a service layer would add indirection without hiding
complexity. They can easily be extracted into a service if needed in the future.

### Soft delete with the discard gem, without a default scope

*Chosen*: books and readers include `Discard::Model`, without a default scope.

*Alternatives considered*: hard deletes, `paranoia` / `acts_as_paranoid`, `discard` with a `default_scope`.

Borrowing history must keep pointing at books and readers after they are removed from circulation. Explicit `.kept`
makes it obvious where deleted records are excluded.

### Six-digit numbers stored as strings

*Chosen*: `books.serial_number` and `readers.card_number` are strings validated in the models with `/\A\d{6}\z/`.

*Alternatives considered*: integer columns with a 1..999999 range, formatted with leading zeros on output.

These are identifiers printed on labels and cards, not quantities, and they are never used in arithmetic.
The format needs no database-level check, as all writes go through the models.

### Optional reader email

*Chosen*: `readers.email` is nullable. Readers without an email receive no reminders.

*Alternatives considered*: a required email.

Not every patron of an offline library has, or wants to share, an email address.

## HTTP API

### Plain Rails controllers instead of Grape

*Chosen*: the API is built from plain `ActionController::API` controllers with Rails routing, strong parameters and
Blueprinter serializers.

*Alternatives considered*: Grape (optionally with grape-entity and grape-swagger).

This is a simple internal API used by library staff, so it doesn't need Grape's versioning, parameter DSL or generated
documentation, and plain controllers keep the stack conventional for any Rails developer. If API usage evolves (public
clients, several versions), the endpoints can be migrated to Grape or a versioned namespace later.

### Borrow and return as actions on books

*Chosen*: `POST /books/:id/borrow` and `POST /books/:id/return` member routes on `BooksController`.

*Alternatives considered*: a `borrowings` resource (`POST /borrowings`, `PATCH /borrowings/:id`); a nested singular
`/books/:id/borrowing` resource with `create`/`destroy`.

Staff think in terms of "borrow this book" and "return this book", and both operations start from the book in hand.
API clients don't need to know the borrowing ID to return a book. Both return 200: they are action verbs on an
existing book rather than REST creation of a new resource, so 201 doesn't apply.

### Plain arrays for paginated lists

*Chosen*: list endpoints return a bare JSON array, no envelope and no total count.

*Alternatives considered*: a `{ data, meta }` envelope with `total_count` / `total_pages`; pagination headers (`Link`,
`X-Total-Count`).

This is an internal API for library staff, and no client needs totals yet; skipping them also avoids a `COUNT(*)` per
request. Adding an envelope or headers later is a small, coordinated change with the known clients.

### Unknown request attributes are ignored

*Chosen*: strong parameters (`params.expect`) permit a fixed attribute list per resource; any other attribute in the
body is dropped without an error. Missing or wrongly shaped resource keys still get a 400.

*Alternatives considered*: `action_on_unpermitted_parameters = :raise`, answering 400 that names the unknown attribute.

Ignoring extra attributes lets clients and server evolve independently: a client can start sending a field before the
server knows it, and a removed field doesn't break older clients. Only permitted attributes are assigned, so clients
still can't set fields like `discarded_at`.

### strict_loading on serialized queries

*Chosen*: the queries whose records are serialized with associations (`BooksController#index` and `#show`) use
`.strict_loading` alongside `includes`.

*Alternatives considered*: a test-only query counter; the `bullet` gem; `strict_loading_by_default` for every model.

The guard lives next to the `includes` it protects, so any association the serializer touches without preloading fails
the existing request specs. Model code that lazily loads associations on single records (e.g., `Borrowing.borrow!`) is
not an N+1 and stays unaffected. A lazy association load raises in development and test, and is only logged in
production (`action_on_strict_loading_violation = :log`).

## Background jobs and reminders

### Separate queue database

*Chosen*: `primary` and `queue` databases in development and production (the Rails 8 default layout minus `cache` and
`cable`). Tests use only `primary`, with the `:test` Active Job adapter.

*Alternatives considered*: Solid Queue tables in the primary database; the `async` adapter in development.

Keeping the queue separate follows the Rails default and keeps polling traffic away from application tables. The
cost is that a job can't be enqueued in the same transaction as a domain write; if that is ever needed, the queue can
move into the primary database.

### Reminders from one recurring job

*Chosen*: `SendDueDateRemindersJob` takes a reminder name (`due_soon` or `due_today`, see
[Reminder kinds](#reminder-kinds-as-a-value-object-registry)) and is scheduled twice in `config/recurring.yml`, every
day at 8am. It only finds borrowings that still need the reminder and enqueues one `SendReminderJob` per borrowing.

*Alternatives considered*: enqueueing two delayed jobs (`set(wait_until:)`) when a book is borrowed; one job sending
both reminders, sending all emails directly from the scheduling job.

Delayed per-borrowing jobs have to be cancelled or re-checked on return, and lost jobs are hard to notice, while a daily
query over `borrowings` always reflects the current data. Passing the scope keeps a single job with two independent
schedules, so each reminder kind can be run, retried or rescheduled on its own. Sending each email from its own job (one
per borrowing) isolates failures, so only the failed email is retried.

### At-most-once reminders with an atomic sent_at claim

*Chosen*: `SendReminderJob` claims `due_soon_reminder_sent_at` / `due_today_reminder_sent_at` with one conditional
`UPDATE` (`<column> IS NULL`, book not returned, reader has an email), and sends the email with `deliver_now` only if
the claim succeeded. A delivery error releases the claim and the job retries (`retry_on`).

*Alternatives considered*: marking and sending in separate jobs; matching an exact day (`due_on == today + 3`).

The claim and the send happen in one job, so a duplicate enqueue or a Solid Queue re-run after a crash finds the claim
taken and sends nothing. Only a crash between claiming and sending can lose a reminder, which is an acceptable
trade-off for notifications. The scheduler selects by date window, so a run missed because of downtime is caught up.

### Sent emails in letter_opener_web

*Chosen*: the `letter_opener_web` delivery method, with the UI mounted at `/letter_opener` without authentication.

*Alternatives considered*: only logging emails (`perform_deliveries = false`); MailCatcher or Mailpit as an extra
SMTP container.

Reminders are sent by background jobs, so it should be easy to check what a reader actually received, which mailer
previews (built from fake records) don't show. letter_opener_web needs no extra service and works in API-only apps.
Files are enough for a development inbox. The app only runs in a private Docker container, so production uses the same
inbox and needs no SMTP server or login; exposing it publicly would require real delivery or protecting
`/letter_opener`.



## New ones

* Book and Reader uses codes as ID. I's unique, always present and should not be reused and user knows it better than internal id.
* Codes cannot be reused - we use them as ID, so we cannot use them for new book or reader. That's OK as archived books, users should not release their code in real life

* Add envelope, so paging is easier (we can display paging in client and know if we need to page)

* Limit number of borrowings included in the book api to 3 newest (we don't have paging on sub collection). All borrowings can be seen in borrowings resource.

* Keep status in DB. It make it faster to have it stored (we read more often than update), it's easier to filter by status if needed.

* Reader check in return is not needed. It creates additional friction (e.g., book found on the shelf and we don't know who returned it) and does not really guard against any problem.
