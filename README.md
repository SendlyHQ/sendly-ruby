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
message = client.messages.send(
  to: "+15551234567",
  text: "Hello from Sendly!"
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
| +15550001234 | Success |
| +15550001001 | Invalid number |
| +15550001002 | Carrier rejected |
| +15550001003 | No credits |
| +15550001004 | Rate limited |

## Requirements

- Ruby 3.0+
- Faraday 2.0+

## License

MIT
