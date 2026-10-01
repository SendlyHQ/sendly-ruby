#!/usr/bin/env ruby
# frozen_string_literal: true

require "sendly"

# Configure with your API key
client = Sendly::Client.new(ENV["SENDLY_API_KEY"] || "sk_test_v1_example")

# Send an SMS
begin
  message = client.messages.send(
    to: "+15125550123",
    text: "Hello from Sendly Ruby SDK!"
  )

  puts "Message sent successfully!"
  puts "  ID: #{message.id}"
  puts "  To: #{message.to}"
  puts "  Status: #{message.status}"
  puts "  Credits used: #{message.credits_used}"
rescue Sendly::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue Sendly::InsufficientCreditsError => e
  puts "Insufficient credits: #{e.message}"
rescue Sendly::ValidationError => e
  puts "Validation error: #{e.message}"
rescue Sendly::RateLimitError => e
  if e.response_body&.dig("error") == "too_many_failed_key_attempts"
    puts "Locked out after repeated wrong API keys. Fix the key, then wait #{e.retry_after} seconds"
  else
    puts "Rate limited. Retry after: #{e.retry_after} seconds"
  end
rescue Sendly::Error => e
  puts "Error: #{e.message}"
end
