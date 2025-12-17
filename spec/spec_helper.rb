# frozen_string_literal: true

require 'bundler/setup'
require 'webmock/rspec'
require 'sendly'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Disable external HTTP requests
  config.before(:each) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  # Reset Sendly configuration
  config.before(:each) do
    Sendly.api_key = nil
    Sendly.base_url = 'https://sendly.live/api/v1'
  end
end

# Helper methods for testing
module SpecHelpers
  def valid_api_key
    'sk_test_v1_abc123xyz'
  end

  def base_url
    'https://sendly.live/api/v1'
  end

  def stub_request_with_auth(method, path, status: 200, response_body: {}, headers: {})
    stub_request(method, "#{base_url}#{path}")
      .with(
        headers: {
          'Authorization' => "Bearer #{valid_api_key}",
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      )
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }.merge(headers)
      )
  end

  def message_response(overrides = {})
    {
      'id' => 'msg_abc123',
      'to' => '+15551234567',
      'from' => '',
      'text' => 'Hello, world!',
      'status' => 'sent',
      'segments' => 1,
      'creditsUsed' => 1,
      'isSandbox' => false,
      'createdAt' => '2025-01-15T10:00:00Z'
    }.merge(overrides)
  end

  def message_list_response(messages = [], total: nil)
    {
      'data' => messages,
      'count' => total || messages.length,
      'limit' => 20,
      'offset' => 0
    }
  end

  def scheduled_message_response(overrides = {})
    {
      'id' => 'sched_abc123',
      'to' => '+15551234567',
      'text' => 'Reminder!',
      'scheduledAt' => '2025-01-20T10:00:00Z',
      'status' => 'scheduled',
      'creditsReserved' => 1
    }.merge(overrides)
  end

  def batch_response(overrides = {})
    {
      'batchId' => 'batch_abc123',
      'total' => 2,
      'queued' => 2,
      'sent' => 0,
      'failed' => 0,
      'status' => 'processing',
      'createdAt' => '2025-01-15T10:00:00Z'
    }.merge(overrides)
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
end
