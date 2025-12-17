#!/usr/bin/env ruby
# frozen_string_literal: true

require "sendly"

client = Sendly::Client.new(ENV["SENDLY_API_KEY"] || "sk_test_v1_example")

# List recent messages
puts "=== Recent Messages ==="
messages = client.messages.list(limit: 10)
puts "Total: #{messages.total}"
puts "Has more: #{messages.has_more}"
puts

messages.each do |msg|
  puts "#{msg.id}: #{msg.to} - #{msg.status}"
end

# List with filters
puts "\n=== Delivered Messages ==="
delivered = client.messages.list(status: "delivered", limit: 5)
delivered.each do |msg|
  puts "#{msg.id}: Delivered at #{msg.delivered_at}"
end

# Iterate all with auto-pagination
puts "\n=== All Messages (paginated) ==="
count = 0
client.messages.each(batch_size: 50) do |msg|
  puts "#{msg.id}: #{msg.to}"
  count += 1
  break if count >= 20 # Limit for demo
end
