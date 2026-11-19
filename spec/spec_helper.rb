# Coverage must start before any application code is loaded. Report: coverage/index.html
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  # Enforced only for full CI runs (GitHub Actions and bin/ci set CI), so running a
  # single spec file locally doesn't fail on coverage.
  minimum_coverage line: 90, branch: 80 if ENV["CI"]
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "tmp/rspec_examples.txt"
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end
