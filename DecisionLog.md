# Decision Log

## Separate queue database

*Chosen*: `primary` and `queue` databases in development and production (the Rails 8 default layout minus `cache` and
`cable`). Tests use only `primary`, with the `:test` Active Job adapter.

*Alternatives considered*: Solid Queue tables in the primary database; the `async` adapter in development.

Keeping the queue separate follows the Rails default and keeps polling traffic away from application tables. Using Solid
Queue in development, rather than `async`, means recurring jobs can be run and observed locally with `bin/jobs`. The
cost is that a job can't be enqueued in the same transaction as a domain write; if that is ever needed, the queue can
move into the primary database.

## Dropping unused Rails frameworks

*Chosen*: only Active Record, Active Job, Action Controller, Action Mailer, Action View (needed by mailers) and the
test_unit railtie (needed by mailer previews) are loaded. `solid_cache`, `solid_cable` and `image_processing` are
removed, and production uses the in-process `:memory_store` cache.

*Alternatives considered*: keep the generator's `rails new` defaults (Active Storage, Action Mailbox, Action Text,
Action Cable, Solid Cache).

The API has no uploads, inbound email, rich text, websockets or `Rails.cache` usage, so those components would only add
boot time, attack surface, an extra database and system dependencies (libvips). `kamal` and `thruster` stay as
generated, because they are harmless in the production image. Any removed component can be brought back by re-adding its
gem or `require` line.

## RSpec with FactoryBot

*Chosen*: `rspec-rails` with `factory_bot_rails`, and SimpleCov for coverage.
*Alternatives considered*: Minitest with fixtures (the Rails default).
This was a developer personal preference.

## Time zone from the TZ environment variable

*Chosen*: `config.time_zone = ENV.fetch("TZ", "UTC")`. The same `TZ` variable is passed to the containers.
*Alternatives considered*: a custom `APP_TIME_ZONE` variable; a hard-coded zone in `application.rb`.
Due dates and reminders are day-based, so "today" has to mean the library's local day. `TZ` also sets the OS zone, which
Solid Queue's recurring schedules (Fugit) use, so a single variable keeps "every day at 8am" and `Time.zone.today`
consistent. This assumes library is one location. Handling multi-location across timezones would require per location TZ
setting.  

## Markdown style checked by mdl

*Chosen*: the `mdl` gem (markdownlint for Ruby) with all default rules, and MD013 set to 120 characters (ignoring code
blocks and tables), run through `bin/mdl` locally and in CI.

*Alternatives considered*: RuboCop (it lints Ruby only; `rubocop-md` checks just the Ruby code blocks inside Markdown).

Markdown files follow markdownlint's default rules with 120-character lines, enforced in CI so all md files are
consistent. Individual rules can be relaxed in `.mdl_style.rb` if they get in the way.

## Six-digit numbers stored as strings

*Chosen*: `books.serial_number` and `readers.card_number` are strings validated in the models with `/\A\d{6}\z/`.

*Alternatives considered*: integer columns with a 100000..999999 range formatted with leading zeros on output

These are identifiers printed on labels and cards, not quantities and is never used in arithmetic.
It needs no database-level guard as all writes go through the models.

## Soft delete with discard, without a default scope

*Chosen*: books and readers include `Discard::Model` no default scope

*Alternatives considered*: hard deletes, `paranoia` / `acts_as_paranoid`, `discard` with a `default_scope`

Borrowing history must keep pointing at books and readers after they are removed from circulation. Explicit `.kept`
makes it obvious where deleted records are excluded.

## Optional reader email

*Chosen*: `readers.email` is nullable. Readers without an email receive no reminders.

*Alternatives considered*: a required email.

Not every patron of an offline library has, or wants to share, an email address.

## Borrowings as their own table

*Chosen*: a separate `borrowings` table

*Alternatives considered*: `borrowed_at` / `reader_id` columns on `books` with a separate history table.

One table gives both the current state and the full history the book view needs. Allow to use the row lock for
serializing concurrent requests to avoid race conditions.

## Borrowing.borrow! and Borrowing.return! instead of a service class

*Chosen*: borrow and return are class methods on `Borrowing`

*Alternatives considered*: service objects (`BorrowBook`, `ReturnBook`); instance methods on `Book`.

This is operation that operates only on `Borrowing` object, so it naturally lands there.
Each operation is a few lines touching one aggregate, so a service layer would add indirection without hiding
complexity. It can be easily extracted to a service if needed in the future.

## Plain Rails controllers instead of Grape

*Chosen*: the API is built from plain `ActionController::API` controllers with Rails routing, strong parameters and
Blueprinter serializers.

*Alternatives considered*: Grape (optionally with grape-entity and grape-swagger).

This is a simple internal API used by library staff, so it doesn't need Grape's versioning, parameter DSL or generated
documentation, and plain controllers keep the stack conventional for any Rails developer. If API usage evolves (public
clients, several versions), the endpoints can be migrated to Grape or a versioned namespace later.

## Plain arrays for paginated lists

*Chosen*: list endpoints return a bare JSON array, no envelope and no total count.

*Alternatives considered*: a `{ data, meta }` envelope with `total_count` / `total_pages`; pagination headers (`Link`,
`X-Total-Count`).

This is an internal API for library staff, and no client needs totals yet; skipping them also avoids a `COUNT(*)` per
request. Adding an envelope or headers later is a small, coordinated change with the known clients.

## Unknown request attributes are ignored

*Chosen*: strong parameters (`params.expect`) permit a fixed attribute list per resource; any other attribute in the
body is dropped without an error. Missing or wrongly shaped resource keys still get a 400.

*Alternatives considered*: `action_on_unpermitted_parameters = :raise`, answering 400 that names the unknown attribute.

Ignoring extra attributes lets clients and server evolve independently: a client can start sending a field before the
server knows it, and a removed field doesn't break older clients. Only permitted attributes are assigned, so clients
still can't set fields like `discarded_at`.

## strict_loading on serialized queries

*Chosen*: the queries whose records are serialized with associations (`BooksController#index` and `#show`) use
`.strict_loading` alongside `includes`.

*Alternatives considered*: a test-only query counter; the `bullet` gem; `strict_loading_by_default` for every model.

The guard lives next to the `includes` it protects, so any association the serializer touches without preloading fails
the existing request specs. Model code that lazily loads associations on single records (e.g. `Borrowing.borrow!`) is
not an N+1 and stays unaffected. A lazy association load raises in development and test, and is only logged in
production (`action_on_strict_loading_violation = :log`).

## Borrow and return as actions on books

*Chosen*: `POST /books/:id/borrow` and `POST /books/:id/return` member routes on `BooksController`

*Alternatives considered*: a `borrowings` resource (`POST /borrowings`, `PATCH /borrowings/:id`); a nested singular
`/books/:id/borrowing` resource with `create`/`destroy`.

Staff think in terms of "borrow this book" and "return this book", and both operations start from the book in hand.
API user does not need to care about borrowing id to handle return. Both return 200: they are action verbs on an
existing book rather than REST creation of a new resource, so 201 doesn't apply.
