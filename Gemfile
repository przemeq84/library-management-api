source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4", ">= 8.1.4.1"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapter for Active Job
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Soft deletes [https://github.com/jhawthorn/discard]
gem "discard"

# JSON serialization [https://github.com/procore-oss/blueprinter]
gem "blueprinter"

# Pagination [https://github.com/mislav/will_paginate]
gem "will_paginate"

# Store sent emails and browse them at /letter_opener instead of sending them, in every environment but test
# [https://github.com/fgrehm/letter_opener_web]
gem "letter_opener_web", "~> 3.0"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec-specific RuboCop cops [https://github.com/rubocop/rubocop-rspec]
  gem "rubocop-rspec", require: false

  # Markdown lint, used only for the 120-character line length [https://github.com/markdownlint/markdownlint]
  gem "mdl", require: false

  # Load environment variables from .env [https://github.com/bkeepers/dotenv]
  gem "dotenv-rails"

  # Testing [https://github.com/rspec/rspec-rails]
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :test do
  # Code coverage [https://github.com/simplecov-ruby/simplecov]
  gem "simplecov", require: false
end
