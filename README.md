<p align="center">
  <img src="https://raw.githubusercontent.com/SendlyHQ/sendly-ruby/main/.github/header.svg" alt="Sendly Ruby SDK" />
</p>

<p align="center">
  <a href="https://rubygems.org/gems/sendly"><img src="https://img.shields.io/gem/v/sendly.svg?style=flat-square" alt="RubyGems" /></a>
  <a href="https://github.com/SendlyHQ/sendly-ruby/blob/main/LICENSE"><img src="https://img.shields.io/github/license/SendlyHQ/sendly-ruby?style=flat-square" alt="license" /></a>
</p>

# Sendly Ruby SDK

Official Ruby SDK for the Sendly SMS API.

## Installation

```bash
# gem
gem install sendly

# Bundler (add to Gemfile)
gem 'sendly'

# then run
bundle install
```

## Quick Start

```ruby
require 'sendly'

# Create a client
client = Sendly::Client.new("sk_live_v1_your_api_key")

# Send an SMS
message = client.messages.send(
  to: "+15551234567",
  text: "Hello from Sendly!"
)

puts message.id     # => "msg_abc123"
puts message.status # => "queued"
```

## Prerequisites for Live Messaging

Before sending live SMS messages, you need:

1. **Business Verification** - Complete verification in the [Sendly dashboard](https://sendly.live/dashboard)
   - **International**: Instant approval (just provide Sender ID)
   - **US/Canada**: Requires carrier approval (3-7 business days)

2. **Credits** - Add credits to your account
   - Test keys (`sk_test_*`) work without credits (sandbox mode)
   - Live keys (`sk_live_*`) require credits for each message

3. **Live API Key** - Generate after verification + credits
   - Dashboard → API Keys → Create Live Key

### Test vs Live Keys

| Key Type | Prefix | Credits Required | Verification Required | Use Case |
|----------|--------|------------------|----------------------|----------|
| Test | `sk_test_v1_*` | No | No | Development, testing |
| Live | `sk_live_v1_*` | Yes | Yes | Production messaging |

> **Note**: You can start development immediately with a test key. Messages to sandbox test numbers are free and don't require verification.

## Configuration

### Global Configuration

```ruby
Sendly.configure do |config|
  config.api_key = "sk_live_v1_xxx"
end

# Use the default client
Sendly.send_message(to: "+15551234567", text: "Hello!")
```

### Client Options

```ruby
client = Sendly::Client.new(
  "sk_live_v1_xxx",
  base_url: "https://sendly.live/api/v1",
  timeout: 60,
  max_retries: 5
)
```

## Messages

### Send an SMS

```ruby
# Marketing message (default)
message = client.messages.send(
  to: "+15551234567",
  text: "Check out our new features!"
)

# Transactional message (bypasses quiet hours)
message = client.messages.send(
  to: "+15551234567",
  text: "Your verification code is: 123456",
  message_type: "transactional"
)

puts message.id
puts message.status
puts message.credits_used
```

### List Messages

```ruby
# Basic listing
messages = client.messages.list(limit: 50)
messages.each { |m| puts m.to }

# With filters
messages = client.messages.list(
  status: "delivered",
  to: "+15551234567",
  limit: 20,
  offset: 0
)

# Pagination info
puts messages.total
puts messages.has_more
```

### Get a Message

```ruby
message = client.messages.get("msg_abc123")

puts message.to
puts message.text
puts message.status
puts message.delivered_at
```

### Scheduling Messages

```ruby
# Schedule a message for future delivery
scheduled = client.messages.schedule(
  to: "+15551234567",
  text: "Your appointment is tomorrow!",
  scheduled_at: "2025-01-15T10:00:00Z"
)

puts scheduled.id
puts scheduled.scheduled_at

# List scheduled messages
result = client.messages.list_scheduled
result.data.each { |msg| puts "#{msg.id}: #{msg.scheduled_at}" }

# Get a specific scheduled message
msg = client.messages.get_scheduled("sched_xxx")

# Cancel a scheduled message (refunds credits)
result = client.messages.cancel_scheduled("sched_xxx")
puts "Refunded: #{result.credits_refunded} credits"
```

### Batch Messages

```ruby
# Send multiple messages in one API call (up to 1000)
batch = client.messages.send_batch(
  messages: [
    { to: "+15551234567", text: "Hello User 1!" },
    { to: "+15559876543", text: "Hello User 2!" },
    { to: "+15551112222", text: "Hello User 3!" }
  ]
)

puts batch.batch_id
puts "Queued: #{batch.queued}"
puts "Failed: #{batch.failed}"
puts "Credits used: #{batch.credits_used}"

# Get batch status
status = client.messages.get_batch("batch_xxx")

# List all batches
batches = client.messages.list_batches

# Preview batch (dry run) - validates without sending
preview = client.messages.preview_batch(
  messages: [
    { to: '+15551234567', text: 'Hello User 1!' },
    { to: '+447700900123', text: 'Hello UK!' }
  ]
)
puts "Total credits needed: #{preview.total_credits}"
puts "Valid: #{preview.valid}, Invalid: #{preview.invalid}"
```

### Iterate All Messages

```ruby
# Auto-pagination
client.messages.each do |message|
  puts "#{message.id}: #{message.to}"
end

# With filters
client.messages.each(status: "delivered") do |message|
  puts "Delivered: #{message.id}"
end
```

## Webhooks

```ruby
# Create a webhook endpoint
webhook = client.webhooks.create(
  url: "https://example.com/webhooks/sendly",
  events: ["message.delivered", "message.failed"]
)

puts webhook.id
puts webhook.secret  # Store securely!

# List all webhooks
webhooks = client.webhooks.list

# Get a specific webhook
wh = client.webhooks.get("whk_xxx")

# Update a webhook
client.webhooks.update("whk_xxx",
  url: "https://new-endpoint.example.com/webhook",
  events: ["message.delivered", "message.failed", "message.sent"]
)

# Test a webhook
result = client.webhooks.test("whk_xxx")

# Rotate webhook secret
rotation = client.webhooks.rotate_secret("whk_xxx")

# Delete a webhook
client.webhooks.delete("whk_xxx")
```

## Account & Credits

```ruby
# Get account information
account = client.account.get
puts account.email

# Check credit balance
credits = client.account.get_credits
puts "Available: #{credits.available_balance} credits"
puts "Reserved: #{credits.reserved_balance} credits"
puts "Total: #{credits.balance} credits"

# View credit transaction history
result = client.account.get_credit_transactions
result.data.each do |tx|
  puts "#{tx.type}: #{tx.amount} credits - #{tx.description}"
end

# List API keys
result = client.account.list_api_keys
result.data.each do |key|
  puts "#{key.name}: #{key.prefix}*** (#{key.type})"
end

# Create a new API key
new_key = client.account.create_api_key(
  name: 'Production Key',
  type: 'live',
  scopes: ['sms:send', 'sms:read']
)
puts "New key: #{new_key.key}"  # Only shown once!

# Revoke an API key
client.account.revoke_api_key('key_xxx')
```

## Error Handling

```ruby
begin
  message = client.messages.send(
    to: "+15551234567",
    text: "Hello!"
  )
rescue Sendly::AuthenticationError => e
  puts "Invalid API key"
rescue Sendly::RateLimitError => e
  puts "Rate limited, retry after #{e.retry_after} seconds"
rescue Sendly::InsufficientCreditsError => e
  puts "Add more credits to your account"
rescue Sendly::ValidationError => e
  puts "Invalid request: #{e.message}"
rescue Sendly::NotFoundError => e
  puts "Resource not found"
rescue Sendly::NetworkError => e
  puts "Network error: #{e.message}"
rescue Sendly::Error => e
  puts "Error: #{e.message} (#{e.code})"
end
```

## Message Object

```ruby
message.id           # Unique identifier
message.to           # Recipient phone number
message.text         # Message content
message.status       # queued, sending, sent, delivered, failed
message.credits_used # Credits consumed
message.created_at   # Creation time
message.updated_at   # Last update time
message.delivered_at # Delivery time (if delivered)
message.error_code   # Error code (if failed)
message.error_message # Error message (if failed)

# Helper methods
message.delivered?   # => true/false
message.failed?      # => true/false
message.pending?     # => true/false
```

## Message Status

| Status | Description |
|--------|-------------|
| `queued` | Message is queued for delivery |
| `sending` | Message is being sent |
| `sent` | Message was sent to carrier |
| `delivered` | Message was delivered |
| `failed` | Message delivery failed |

## Pricing Tiers

| Tier | Countries | Credits per SMS |
|------|-----------|-----------------|
| Domestic | US, CA | 1 |
| Tier 1 | GB, PL, IN, etc. | 8 |
| Tier 2 | FR, JP, AU, etc. | 12 |
| Tier 3 | DE, IT, MX, etc. | 16 |

## Sandbox Testing

Use test API keys (`sk_test_v1_xxx`) with these test numbers:

| Number | Behavior |
|--------|----------|
| +15005550000 | Success (instant) |
| +15005550001 | Fails: invalid_number |
| +15005550002 | Fails: unroutable_destination |
| +15005550003 | Fails: queue_full |
| +15005550004 | Fails: rate_limit_exceeded |
| +15005550006 | Fails: carrier_violation |

## Requirements

- Ruby 3.0+
- Faraday 2.0+

## License

MIT
