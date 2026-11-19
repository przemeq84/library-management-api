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
