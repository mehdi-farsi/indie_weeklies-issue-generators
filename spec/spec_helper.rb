# frozen_string_literal: true

require "bundler/setup"
require "dotenv/load"
require "zeitwerk"
require "vcr"

# Set up autoloading
loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path("../lib", __dir__))
loader.setup

# Configure VCR for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  
  # Don't record sensitive information
  config.filter_sensitive_data("<TWITTER_BEARER_TOKEN>") { ENV["TWITTER_BEARER_TOKEN"] }
  config.filter_sensitive_data("<OPENAI_API_KEY>") { ENV["OPENAI_API_KEY"] }
  config.filter_sensitive_data("<BEEHIIV_API_KEY>") { ENV["BEEHIIV_API_KEY"] }
  config.filter_sensitive_data("<BEEHIIV_PUBLICATION_ID>") { ENV["BEEHIIV_PUBLICATION_ID"] }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end