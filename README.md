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
gem 'sendly', '~> 4.2'

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
  to: "+15125550123",
  text: "Hello from Sendly!"
)

puts message.id     # => "msg_abc123"
puts message.status # => "queued"
```

## Prerequisites for Live Messaging

Before sending live SMS messages, you need:

1. **Business Verification** - Complete verification in the [Sendly dashboard](https://sendly.live/dashboard)
   - **International**: Instant approval (just provide Sender ID)
   - **US/Canada**: Requires carrier approval

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
Sendly.send_message(to: "+15125550123", text: "Hello!")
```

### Client Options

```ruby
client = Sendly::Client.new(
  "sk_live_v1_xxx",
  base_url: "https://sendly.live/api/v1",
  timeout: 60,
  max_retries: 5,
  organization_id: "org_abc"   # sent as X-Organization-Id; defaults to ENV["SENDLY_ORG_ID"]
)

# The API key is also accepted as a keyword, for callers on the older signature.
client = Sendly::Client.new(api_key: "sk_live_v1_xxx")
```

The key is validated in the constructor: anything that is not
`sk_test_v1_…` or `sk_live_v1_…` raises `Sendly::AuthenticationError`
before a request is made. `organization_id` is also writable after
construction (`client.organization_id = "org_abc"`).

## Messages

### Send an SMS

```ruby
# Marketing message (default)
message = client.messages.send(
  to: "+15125550123",
  text: "Check out our new features!"
)

# Transactional message (bypasses quiet hours)
message = client.messages.send(
  to: "+15125550123",
  text: "Your verification code is: 123456",
  message_type: "transactional"
)

# With custom metadata (max 4KB)
message = client.messages.send(
  to: "+15125550123",
  text: "Your order #12345 has shipped!",
  metadata: { order_id: "12345", customer_id: "cust_abc" }
)

# Send from one of your owned numbers (or an alphanumeric sender ID).
# Omit `from` to use your default sender.
message = client.messages.send(
  to: "+15125550123",
  text: "Hello from our team!",
  from: "+447700900123"
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
  to: "+15125550123",
  limit: 20,
  offset: 0
)

# Pagination info: total counts every matching message, not just this page
puts messages.total
puts messages.has_more
```

A page holds at most 100 messages; a larger `limit:` is capped at 100.

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
  to: "+15125550123",
  text: "Your appointment is tomorrow!",
  scheduled_at: (Time.now.utc + 3600).iso8601  # 5 minutes to 5 days ahead
)

# schedule returns the raw Hash the API sent, not a Message object
puts scheduled["id"]
puts scheduled["scheduledAt"]

# List scheduled messages (returns a Hash with "data" array)
result = client.messages.list_scheduled
result["data"].each { |msg| puts "#{msg['id']}: #{msg['scheduledAt']}" }

# Get a specific scheduled message
msg = client.messages.get_scheduled("schd_xxx")

# Cancel a scheduled message (refunds credits)
result = client.messages.cancel_scheduled("schd_xxx")
puts "Refunded: #{result['creditsRefunded']} credits"
```

### Batch Messages

```ruby
# Send multiple messages in one API call (up to 10,000)
batch = client.messages.send_batch(
  messages: [
    { to: "+15125550123", text: "Hello User 1!" },
    { to: "+15125550124", text: "Hello User 2!" },
    { to: "+15125550125", text: "Hello User 3!" }
  ]
)

puts batch["batchId"]
puts "Status: #{batch['status']}"        # "processing" until the batch finishes
puts "Sent: #{batch['sent']}"
puts "Failed: #{batch['failed']}"
puts "Credits used: #{batch['creditsUsed']}"

# Get batch status. The stored batch — unlike the send response — also
# carries queued/delivered counts.
status = client.messages.get_batch("batch_xxx")
puts "#{status['queued']} queued, #{status['delivered']} delivered"

# List all batches
batches = client.messages.list_batches

# Preview batch (dry run) - validates without sending
preview = client.messages.preview_batch(
  messages: [
    { to: '+15125550123', text: 'Hello User 1!' },
    { to: '+447700900123', text: 'Hello UK!' }
  ]
)
puts "Credits needed: #{preview['creditsNeeded']} (balance #{preview['creditBalance']})"
puts "Sendable: #{preview['sendable']} of #{preview['total']}, blocked: #{preview['blocked']}"
puts "Enough credits? #{preview['hasSufficientCredits']}"
```

### Iterate All Messages

`each` requests page after page until it has yielded every matching message,
so on a large account it makes many requests; `break` out of the block to stop
early. Without a block it returns an `Enumerator`.

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

### Group MMS

Send one MMS to 2-8 US/Canada recipients who all share a single thread —
replies fan out to every participant. Group messaging is an A2P 10DLC
capability, so the sending number must be an MMS-enabled, 10DLC-registered
number you own. Omit `from` to use your workspace's default sender. Requires
the `group_mms` feature (and `enable_mms` when sending media).

```ruby
group = client.messages.send_group(
  to: ["+14155550123", "+14155550124"],
  text: "Hey team - quick sync at noon?"
)

puts group.id                # => "msg_abc123"
puts group.group_message_id  # => "grp_..." (present on live sends)
puts group.status            # => "sent" (or "delivered" when simulated)
puts group.simulated?        # => true on test keys / before verification

# Recipients: on a live send each entry is a Hash with the per-recipient
# status ({ "phoneNumber" => "+14155550123", "status" => "queued" });
# on a simulated send each entry is the phone number String.
group.to.each { |r| puts r.is_a?(Hash) ? "#{r['phoneNumber']} #{r['status']}" : r }

# With media instead of (or in addition to) text
client.messages.send_group(
  to: ["+14155550123", "+14155550124"],
  media_urls: ["https://cdn.acme.example/flyer.jpg"],
  message_type: "marketing"
)
```

Billed per recipient. US/Canada destinations only. Without the `group_mms`
feature the API answers 403 `feature_disabled` (`Sendly::APIError`). A group
message the carrier refuses raises `Sendly::ValidationError` (422
`send_failed`), and its credits are refunded.

### AI Message Enhancement

Rewrite a draft into a single, polished SMS segment (≤160 chars) and get a
short explanation of what changed. Pass `message_type` to steer the tone; with
no `text` the model generates a suitable message for that type. At least one of
`text` or `message_type` is required. Requires the `ai_classification` feature —
when AI is unavailable, the original text is returned with an empty explanation.

```ruby
result = client.messages.enhance(
  text: "hey come check out our sale this weekend",
  message_type: "marketing"
)

puts result.enhanced     # polished, ≤160-char rewrite
puts result.explanation  # what changed and why
puts result.model        # model used (when available)
```

## Idempotency

Every POST carries an automatically generated `Idempotency-Key` header. The
client keeps that key for every retry it makes on its own (a 5xx, or a 429 it
waits out; see [Retries and rate limits](#retries-and-rate-limits)), so a retry
of a request that already reached the API returns the original result instead
of sending and charging again. Pass your own key (1-255 printable ASCII
characters) when the guarantee needs to outlive the process, such as a job
queue that re-runs after a crash or your own retry loop; `idempotency_key:` is
accepted on `messages.send`, `send_group`, `schedule`, and `send_batch`.

```ruby
message = client.messages.send(
  to: "+15125550123",
  text: "Your order has shipped!",
  idempotency_key: "order-4821-shipped"
)
```

The API records the answer under the key for a 2xx and for every 4xx except
429, and repeating the request with the same key within 24 hours returns that
recorded answer. A 5xx or a 429 is never recorded, so a retry under the same
key runs the request again. Reusing one of your own keys with a different body
is refused with 422 `idempotency_key_mismatch` (`Sendly::ValidationError`).

`send_batch` sends no automatic key, because the API already deduplicates
identical batches by their contents. This client raises `Sendly::TimeoutError`
and `Sendly::NetworkError` instead of retrying them, so those are exactly when
to retry with your own key.

Full details: https://sendly.live/docs/idempotency

## Rate Limits

Requests are counted per API key in a fixed 60-second window that opens with
the key's first request:

| Key | Requests per minute |
|-----|---------------------|
| Test (`sk_test_v1_*`) | 60 |
| Live (`sk_live_v1_*`) | 600 |
| Enterprise master key | 3000 |

Going over the limit returns a 429 `rate_limit_exceeded` with `retryAfter` in
the body. The client sleeps that long and retries, up to `max_retries` times
(default 3), then raises `Sendly::RateLimitError`, which carries `retry_after`
in seconds. Other 429s, and any wait over 60 seconds, are raised at once; see
[Retries and rate limits](#retries-and-rate-limits) for which ones.

## Webhooks

### Managing endpoints

```ruby
# Create a webhook endpoint
webhook = client.webhooks.create(
  url: "https://acme.example/webhooks/sendly",
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
  url: "https://new-endpoint.acme.example/webhook",
  events: ["message.delivered", "message.failed", "message.sent"]
)

# Test a webhook. A delivered test returns a Sendly::WebhookTestResult; a
# test your endpoint fails raises Sendly::ValidationError with the API's
# message ("Test webhook failed: ...").
result = client.webhooks.test("whk_xxx")
puts "#{result.status_code} in #{result.response_time_ms}ms (#{result.delivery_id})"

# Rotate webhook secret. Deliveries are signed with the new secret from
# the moment it is issued and the old secret is not kept, so switch your
# endpoint over straight away. new_secret is shown only once.
rotation = client.webhooks.rotate_secret("whk_xxx")
puts rotation.new_secret
puts rotation.new_secret_version

# Delete a webhook
client.webhooks.delete("whk_xxx")

# Delivery history, newest first (limit defaults to 50, max 100), and a
# manual retry of one delivery
client.webhooks.deliveries("whk_xxx", status: "failed", limit: 20).each do |d|
  puts "#{d.event_type} #{d.status} (attempt #{d.attempt_number}/#{d.max_attempts})"
end
client.webhooks.retry_delivery("whk_xxx", "del_xxx")

# Event types the API describes (a subset: subscribe accepts every
# Sendly::Webhooks::EVENT_* constant except EVENT_MESSAGE_QUEUED)
client.webhooks.event_types.each { |t| puts t }
```

Webhook ids begin `whk_` and delivery ids `del_`; both are checked in the
client, so a malformed id raises `ArgumentError` before a request goes out.
`create` likewise rejects a non-HTTPS URL and an empty event list. Signing
secrets begin `whsec_`.

After an outage the endpoint can be caught up, and a tripped circuit
breaker reset. Both recovery calls are rejected with HTTP 409 while the
circuit is still open, so reset first:

```ruby
client.webhooks.reset_circuit("whk_xxx")

# Re-fire deliveries we recorded but could not deliver
client.webhooks.redeliver("whk_xxx",
  since: (Time.now.utc - 86_400).iso8601,
  event_types: ["message.delivered"],
  statuses: ["failed", "cancelled"],   # default
  limit: 1000)                         # default 1000, max 10000

# Synthesize events that never got an audit row at all (what redeliver
# cannot recover). A synthesized event reuses the id the original dispatch
# used, so dedupe on event.id. Not on event.data.object.id: a message's
# sent and delivered events share it.
client.webhooks.backfill("whk_xxx", since: (Time.now.utc - 86_400).iso8601)
```

Subscribe with the `Sendly::Webhooks::EVENT_*` constants rather than string
literals — a typo then fails at load time instead of in a 400. Every constant
but one names an event the API accepts on subscribe. The exception is
`EVENT_MESSAGE_QUEUED`: `message.queued` has never been emitted and is
rejected on subscribe with a 400 (`Sendly::ValidationError`). It is
deprecated, kept only so existing code still loads, and will be removed in the
next major. `message.undelivered` is rejected in the same way and has never had
a constant here. Subscribe to `message.sent`, `message.failed` and
`message.bounced` instead.

### Receiving events

`Sendly::Webhooks.parse_event` verifies the signature and returns a
`Sendly::WebhookEvent`. Pass the raw request body — not a re-serialized hash,
which would no longer match the signature.

```ruby
event = Sendly::Webhooks.parse_event(
  request.raw_post,
  request.headers["X-Sendly-Signature"],
  ENV.fetch("SENDLY_WEBHOOK_SECRET"),
  timestamp: request.headers["X-Sendly-Timestamp"]
)
```

Both are module functions on `Sendly::Webhooks`, not methods on
`client.webhooks`, and the argument order is payload, signature, secret,
with the timestamp as a keyword. `Sendly::Webhooks.verify_signature` is the
same check on its own, returning `true`/`false` instead of raising, for when
you want to verify without parsing. Passing the timestamp is recommended:
it is what binds the signature to a time, and a payload older than
`Sendly::Webhooks::SIGNATURE_TOLERANCE_SECONDS` (300) is then rejected.

`event.raw_object` is `data.object` exactly as it arrived, for every event
type. `event.data` is a hash-like view of the same object: read a key with
`[]` (String or Symbol), a reader method of the same name, or `to_h`.

```ruby
case event.type
when Sendly::Webhooks::EVENT_MESSAGE_DELIVERED
  # message.* events also get a typed message view
  puts "#{event.message.id} -> #{event.message.to}"
when Sendly::Webhooks::EVENT_RCS_AGENT_LIVE
  puts event.data[:agent_id]
  puts event.data.stage
when Sendly::Webhooks::EVENT_CALL_COMPLETED
  puts event.data[:duration_secs]
end

# Or read data.object as a type of your own. A Struct or Data class is filled
# from the members it declares and ignores the rest of the payload, so a field
# added to the event later cannot break the call.
AgentLive = Struct.new(:agent_id, :name, :stage)
agent = event.object_as(AgentLive)
```

Two things the SDK will not do, because both make a handler act on data that
was never sent:

- **Nothing is invented.** A field the payload did not carry is `nil`, and
  `event.data.key?(:segments)` is `false`. `segments`, `credits_used`,
  `direction`, `to` and `from` are no longer defaulted to `1`, `0`,
  `"outbound"` and `""`.
- **`nil` stays `nil`.** An in-app `call.*` event carries `from` and `to` as
  JSON `null`; they come back as `nil`, not `""`.

`event.message` is the message view and is `nil` for every event that is not a
message — `rcs_*`, `whatsapp_*`, `call.*`, `short_code.*`, `brand.*`,
`campaign.*`, `assignment.*`, `number.*`, `port*`, `contact*`,
`conversation.*` and `draft.*`, whose payloads are not message-shaped. `verification.*` events get
`event.verification`, a `Sendly::WebhookVerificationData`. `event.data` is the
typed view where one exists and a plain `Sendly::WebhookObject` otherwise, so
reading `data.object` works the same way for all of them, including an event
type this SDK predates.

Note that `contact.auto_flagged` carries the contact under `id` and the message
that failed under `message_id`; read the message with
`event.data[:message_id]`.

### Handling a lifecycle event

Only `message.*` events carry a message, and not `message.opt_in` or
`message.opt_out`: those carry an opt-out record (`phone_number`, `keyword`,
`from_number`), so their `event.message` is `nil` too. A lifecycle event — `rcs_*`,
`whatsapp_*`, `call.*`, `short_code.*`, `brand.*`, `campaign.*`,
`assignment.*`, `number.*`, `port*`, `contact*`, `conversation.*`,
`draft.*` — carries a different object,
so `event.message` is `nil` and you read `data.object` off `event.data` or
`event.raw_object`.

```ruby
require "sendly"

# Framework-neutral: hand it the raw request body and a headers Hash.
def handle_sendly_webhook(raw_body, headers)
  event = Sendly::Webhooks.parse_event(
    raw_body,
    headers["X-Sendly-Signature"],
    ENV.fetch("SENDLY_WEBHOOK_SECRET"),
    timestamp: headers["X-Sendly-Timestamp"]
  )

  case event.type
  when Sendly::Webhooks::EVENT_RCS_AGENT_LIVE
    # data.object is the agent: agent_id, name, stage
    puts "RCS agent #{event.data[:name]} is #{event.data.stage}"
    puts event.data[:agent_id]
  when Sendly::Webhooks::EVENT_NUMBER_ACTIVATED
    # data.object is the number: id, phone, status, country_code, source
    puts "#{event.data[:phone]} active in #{event.data[:country_code]}"
  when Sendly::Webhooks::EVENT_CONTACT_AUTO_FLAGGED
    # the contact is `id`; the message that failed is `message_id`
    puts "flagged #{event.data[:id]} (#{event.data[:invalid_reason]})"
    puts "from message #{event.data[:message_id]}"
  when Sendly::Webhooks::EVENT_MESSAGE_DELIVERED
    # message.* events, and only these, also get the typed message view
    puts "#{event.message.id} delivered to #{event.message.to}"
  else
    # An event type this SDK predates still parses; raw_object holds all of it.
    puts "unhandled #{event.type}: #{event.raw_object.inspect}"
  end

  :ok
rescue Sendly::WebhookSignatureError
  :unauthorized
end
```

Reading a message field off a lifecycle event fails loudly rather than
answering with a value the event never carried:

```ruby
event.data.from
# => NoMethodError: undefined method 'from' for Sendly::WebhookObject:
#    this event's data.object carries agent_id, name, stage, organization_id
event.message      # => nil
event.message.id   # => NoMethodError — nil has no #id
```

Branch on `event.type`, or on `event.message?` / `event.verification?`, before
reaching for a typed view.

## Account & Credits

```ruby
# Get account information. name is the workspace's name; organization,
# credits, verification, api_key and limits are the API's Hashes as sent.
account = client.account.get
puts account.email
puts "#{account.name} (#{account.organization_id})"
puts account.verification&.dig("status")

# Check credit balance (a Sendly::Credits object, not a Hash)
credits = client.account.credits
puts "Available: #{credits.available_balance} credits"
puts "Reserved: #{credits.reserved_balance} credits"
puts "Total: #{credits.balance} credits"

# View credit transaction history
transactions = client.account.transactions
transactions.each do |tx|
  puts "#{tx.type}: #{tx.amount} credits - #{tx.description}"
end

# List API keys
keys = client.account.api_keys
keys.each do |key|
  puts "#{key.name}: #{key.prefix} (#{key.type})"
end

# Create a new API key. type: is "test" (the default) or "live"; scopes:
# defaults to every scope the calling key has and cannot go beyond them.
# A live key needs a verified business and credits: the API answers 403
# verification_required or 402 credits_required otherwise.
result = client.account.create_api_key('Production Key', type: 'live', scopes: ['sms:send', 'sms:read'])
puts "New key: #{result['key']}"  # Only shown once!

# Rotate an API key. Issues a new key and keeps the old one valid for a grace
# period (default 24h; 24-168 allowed) so you can deploy before the old expires.
rotation = client.account.rotate_api_key('key_xxx', grace_period_hours: 72)
puts "New key: #{rotation['newKey']['key']}"  # Only shown once!
puts rotation['message']                      # "Old key will expire in 72 hours"

# Revoke an API key (an optional reason is recorded on the key's audit trail)
client.account.revoke_api_key('key_xxx', reason: 'rotated out of CI')

# Fetch one key, and its usage statistics
key = client.account.api_key('key_xxx')
puts "#{key.name}: #{key.scopes.join(', ')}#{key.revoked? ? ' (revoked)' : ''}"
usage = client.account.api_key_usage('key_xxx')

# Move credits to another workspace you own
client.account.transfer_credits(target_organization_id: 'org_xyz', amount: 500)
```

## Contacts

Manage your contact directory. `list` returns a Hash with a `:contacts` array
of `Contact` objects plus pagination fields.

```ruby
# Create a contact
contact = client.contacts.create(
  phone_number: "+15125550123",
  name: "Alice Example",
  email: "alice@acme.example",
  metadata: { plan: "pro" }
)

# List / search (scope to a list with list_id:)
result = client.contacts.list(limit: 50, search: "alice")
result[:contacts].each { |c| puts "#{c.name}: #{c.phone_number}" }
puts result[:total]

# Get, update, delete
c = client.contacts.get(contact.id)
client.contacts.update(contact.id, name: "Alice E.")  # see the note below
client.contacts.delete(contact.id)

# A contact's helper flags
puts c.opted_out?  # excluded from marketing sends
puts c.invalid?    # auto-flagged as unreachable (landline / bad number)

# Bulk import (dedupes by phone; each entry is a Hash)
report = client.contacts.import_contacts(
  [
    { phone: "+15125550123", name: "Alice" },
    { phone: "+15125550124", name: "Bob", email: "bob@acme.example" }
  ],
  list_id: "list_abc"
)
puts "Imported #{report[:imported]}, skipped #{report[:skipped_duplicates]}, errors #{report[:total_errors]}"

# Clear the auto-invalid flag (single or bulk). bulk_mark_valid takes
# either ids: (up to 10,000) or list_id: — not both.
client.contacts.mark_valid("contact_1")
client.contacts.bulk_mark_valid(list_id: "list_abc")
report = client.contacts.bulk_mark_valid(ids: ["contact_1", "contact_2"])
puts "Cleared #{report[:cleared]}"

# Trigger a carrier line-type lookup (async; landlines get excluded)
client.contacts.check_numbers(list_id: "list_abc", force: false)
```

`update` returns a `Contact` built from the API's update response, which
leaves out `opted_out` and `created_at`: on that object `opted_out?` is
`false` and `created_at` is `nil` whatever the contact holds. Read those with
`contacts.get`.

## Contact Lists

Group contacts into lists for campaigns. Access via `client.contacts.lists`.

```ruby
# Create and manage lists
list = client.contacts.lists.create(name: "VIP Customers", description: "Top spenders")
all = client.contacts.lists.list
all[:lists].each { |l| puts "#{l.name} (#{l.contact_count})" }

# Get a list (paginate its members)
detail = client.contacts.lists.get(list.id, limit: 100, offset: 0)

client.contacts.lists.update(list.id, name: "VIPs")

# Add / remove members
result = client.contacts.lists.add_contacts(list.id, ["contact_1", "contact_2"])
puts "Added #{result[:added_count]}"
client.contacts.lists.remove_contact(list.id, "contact_1")

client.contacts.lists.delete(list.id)
```

## Campaigns

Send one message to every contact on a contact list. A campaign targets a
single list: `contact_list_ids:` takes an Array, but the API refuses more than
one ID with a 400.

```ruby
# Create a campaign
campaign = client.campaigns.create(
  name: "Spring Sale",
  text: "Our spring sale is live! 20% off everything.",
  contact_list_ids: ["list_abc"]
)

# Preview cost + reachability before sending
preview = client.campaigns.preview(campaign.id)
puts "Recipients: #{preview.recipient_count}"
puts "Credits needed: #{preview.estimated_credits}"
puts "Enough credits? #{preview.enough_credits?}"

# Send now. The result is a Sendly::CampaignSendResult (a Sendly::Campaign)
# describing the batch the messages went out in: status is the batch's
# ("processing", "completed", "partial_failure" or "failed").
result = client.campaigns.send_campaign(campaign.id)
puts "Batch #{result.batch_id}: #{result.sent_count}/#{result.recipient_count} sent, " \
     "#{result.failed_count} failed, #{result.credits_used} credits"

# The campaign itself is "completed" once sent
puts client.campaigns.get(campaign.id).completed?

# Or, instead of sending now, schedule a draft for later
client.campaigns.schedule(campaign.id, scheduled_at: (Time.now.utc + 86_400).iso8601, timezone: "America/New_York")

# List, update, cancel, clone, delete
client.campaigns.list(status: "completed")[:campaigns].each { |c| puts "#{c.name}: #{c.status}" }
client.campaigns.update(campaign.id, name: "Spring Sale (v2)")
client.campaigns.cancel(campaign.id)
client.campaigns.clone(campaign.id)
client.campaigns.delete(campaign.id)
```

## Templates

Reusable message templates with variables. AI can also draft one for you.

```ruby
# Create / list / get. New templates start as drafts; publish to lock one for use.
template = client.templates.create(
  name: "Order shipped",
  text: "Hi {{name}}, order {{order_id}} has shipped!"
)
client.templates.list[:templates].each { |t| puts "#{t.name} — #{t.status}" }
t = client.templates.get(template.id)

# Update (drafts only) and publish
client.templates.update(template.id, text: "Hi {{name}}, your order is on the way!")
client.templates.publish(template.id)

# Copy a template into a new draft, then delete the original
copy = client.templates.clone(template.id, name: "Order shipped (v2)")
client.templates.delete(template.id)

# Generate a template with AI
generated = client.templates.generate(description: "A friendly appointment reminder")
puts generated.text
puts generated.variables.inspect
```

## Conversations

Two-way messaging threads with your contacts.

```ruby
# List conversations (Enumerable)
conversations = client.conversations.list(status: "active")
conversations.each { |c| puts "#{c.phone_number}: #{c.last_message_text}" }

# Get one, optionally with its messages
convo = client.conversations.get("conv_abc", include_messages: true)

# Reply in a thread with text, media, or both (a reply with neither raises
# Sendly::ValidationError before anything is sent). Returns a Sendly::Message.
client.conversations.reply("conv_abc", text: "Thanks for reaching out!")
client.conversations.reply("conv_abc", media_urls: ["https://cdn.acme.example/menu.jpg"])

# Lifecycle + metadata
client.conversations.mark_read("conv_abc")
client.conversations.close("conv_abc")
client.conversations.reopen("conv_abc")
client.conversations.update("conv_abc", tags: ["priority"], metadata: { csat: 5 })

# Apply / remove labels
client.conversations.add_labels("conv_abc", label_ids: ["label_1"])
client.conversations.remove_label("conv_abc", label_id: "label_1")

# AI: conversation context + suggested replies
context = client.conversations.get_context("conv_abc", max_messages: 20)
puts context.token_estimate

replies = client.conversations.suggest_replies("conv_abc")
replies.each { |r| puts "[#{r.tone}] #{r.text}" }

# Auto-paginate every conversation
client.conversations.each(status: "active") { |c| puts c.id }
```

## Drafts

Stage replies for review before they're sent (approve → sends via the API).

```ruby
draft = client.drafts.create(
  conversation_id: "conv_abc",
  text: "Here's the info you asked for.",
  source: "agent"
)

client.drafts.list(conversation_id: "conv_abc", status: "pending").each { |d| puts d.text }
client.drafts.update(draft.id, text: "Here is the info you asked for.")

# Approve (sends the message) or reject with a reason
client.drafts.approve(draft.id)
client.drafts.reject(draft.id, reason: "Needs the discount code")
```

## Labels

Organize conversations with labels.

```ruby
label = client.labels.create(name: "Urgent", color: "#ff0000", description: "Needs a fast reply")
client.labels.list.each { |l| puts l.name }
client.labels.delete(label.id)
```

## Rules

Automations that act on inbound messages based on conditions.

```ruby
rule = client.rules.create(
  name: "Auto-label opt-outs",
  conditions: { intent: "opt_out" },
  actions: { addLabels: ["label_1"] },
  priority: 1
)

client.rules.list.each { |r| puts "#{r.name} (priority #{r.priority})" }
client.rules.update(rule.id, priority: 2)
client.rules.delete(rule.id)
```

## Verify

Phone verification (OTP) — send a code, then check it. Hosted verification
sessions are available under `client.verify.sessions`.

```ruby
# Send a verification code
verification = client.verify.send(to: "+15125550123", app_name: "Acme")
puts verification.id

# Check the code the user entered
result = client.verify.check(verification.id, code: "123456")
puts result.verified?

# Resend, fetch, and list
client.verify.resend(verification.id)
client.verify.get(verification.id)
client.verify.list[:verifications].select { |v| v.status == "verified" }.each { |v| puts v.phone }

# Hosted verification session (returns a URL to send the user to)
session = client.verify.sessions.create(
  success_url: "https://acme.example/verified",
  brand_name: "Acme"
)
puts session.url
check = client.verify.sessions.validate(token: "session_token")
puts check.valid?
```

## Media

Upload an image to attach to an MMS (returns a hosted media URL).

```ruby
# From a file path
media = client.media.upload("flyer.jpg", content_type: "image/jpeg")
puts media.url

# ...then attach it to a send
client.messages.send(to: "+15125550123", text: "Check this out!", media_urls: [media.url])
```

## Numbers

Search for, list, and purchase phone numbers. Requires an API key with the
`numbers:read` / `numbers:write` scopes.

```ruby
# List supported countries and the number types available in each
client.numbers.list_countries[:countries].each do |country|
  puts "#{country.code} #{country.name}: #{country.number_types.join(', ')}"
end

# Find available numbers (monthly_cost is already customer-priced)
result = client.numbers.list_available(country: 'GB', type: 'mobile', contains: '777')
number = result[:numbers].first
puts "#{number.phone_number} — #{number.monthly_cost} #{number.currency}/mo"

# List numbers you already own
client.numbers.list[:numbers].each do |n|
  puts "#{n.phone_number} (#{n.status})"
end

# Buy a number
purchase = client.numbers.buy(
  phone_number: number.phone_number,
  country_code: number.country,
  phone_number_type: number.number_type,
  monthly_cost: number.monthly_cost
)

case purchase.status
when 'provisioning'
  puts "Provisioning #{purchase.number.phone_number}"
when 'documents_required', 'payment_required'
  # The action carries TWO different identifiers, and they are not
  # interchangeable:
  #   action_code       - the short code you SHOW the user to type on the
  #                       hosted page. Display only.
  #   action_identifier - the 32-hex identifier you PASS BACK to buy.
  puts "Visit #{purchase.action_url} and enter code #{purchase.action_code}"
  # ...after the action completes, re-call buy with the same arguments plus:
  # client.numbers.buy(..., action_code: purchase.action_identifier)
end

# Get one number you own (includes is_default, which the list omits)
number = client.numbers.get('num_abc123')
puts "#{number.phone_number} — default sender: #{number.is_default}"
puts "voice: #{number.voice_enabled?} (#{number.voice_mode})"

# Update a number — make it the default sender (must be active),
# and/or cancel a scheduled release ("keep this number")
client.numbers.update('num_abc123', is_default: true)
client.numbers.update('num_abc123', pending_cancellation: false)

# Release a number. A live paid purchase is cancelled at the end of the paid
# period (scheduled?), everything else is released immediately.
result = client.numbers.release('num_abc123')
if result.scheduled?
  puts "Releases at #{result.scheduled_release_at}"
else
  puts "Released"
end
```

## 10DLC (Local Number Texting)

Register your business for carrier review so you can text from local
(10-digit) US numbers. Requires an API key with the `tendlc:read` /
`tendlc:write` scopes; writes need a live key.

```ruby
# 1. Register a brand for carrier review
brand = client.ten_dlc.create_brand(
  legal_name: 'Acme Holdings LLC',
  ein: '12-3456789',
  website: 'https://acme.example',
  email: 'ops@acme.example'
)

# Poll until the brand is verified (or failed, with failure_reasons)
refreshed = client.ten_dlc.get_brand(brand.id)
puts refreshed.status  # "pending" -> "verified"

# 2. Pre-check your use case, then create a campaign
check = client.ten_dlc.qualify(brand.id, 'MIXED')
if check.qualified?
  campaign = client.ten_dlc.create_campaign(
    brand_id: brand.id,
    use_case: 'MIXED',
    description: 'Order updates and support replies for Acme customers',
    message_flow: 'Customers opt in at checkout on acme.example',
    sample_messages: ['Your order #123 has shipped!'],
    opt_out_keywords: 'STOP'
  )

  # Poll until carriers approve
  approved = client.ten_dlc.get_campaign(campaign.id)
  puts approved.status            # "awaiting_review" -> "pending" -> "active"
  puts approved.throughput&.tier  # e.g. "Standard"

  # 3. Assign a number you own — it can send once the assignment is Active
  assignment = client.ten_dlc.assign_number(campaign.id, phone_number: '+15125550123')
  puts assignment.status  # "Under review" -> "Active"
end

# List everything
client.ten_dlc.list_brands[:brands].each { |b| puts "#{b.legal_name} — #{b.status}" }
client.ten_dlc.list_campaigns[:campaigns].each { |c| puts "#{c.use_case} — #{c.status}" }
client.ten_dlc.list_assignments[:assignments].each { |a| puts "#{a.phone_number} — #{a.status}" }
```

## Short Codes

**This SDK has no short-code resource.** There is no `client.short_codes`;
short-code applications are handled in the dashboard, or over REST. What
the SDK does carry is the four lifecycle events, as constants you can
subscribe to and branch on:

```ruby
client.webhooks.create(
  url: "https://acme.example/webhooks/sendly",
  events: [
    Sendly::Webhooks::EVENT_SHORT_CODE_ACTION_REQUIRED, # something needs you
    Sendly::Webhooks::EVENT_SHORT_CODE_REJECTED,        # data.object[:reason]
    Sendly::Webhooks::EVENT_SHORT_CODE_FILED,           # filed with the carriers
    Sendly::Webhooks::EVENT_SHORT_CODE_LIVE             # data.object[:short_code]
  ]
)

case event.type
when Sendly::Webhooks::EVENT_SHORT_CODE_LIVE
  # data.object carries short_code_id, short_code and organization_id
  puts "#{event.data[:short_code]} is live"
when Sendly::Webhooks::EVENT_SHORT_CODE_ACTION_REQUIRED
  puts "waiting on you at stage #{event.data[:stage]}"
end
```

These are lifecycle events, so `event.message` is `nil` and you read
`data.object` through `event.data` or `event.raw_object`, as with every
other non-message event.

To drive an application from code meanwhile, call the REST endpoints
directly with an API key holding the `short_codes:read` /
`short_codes:write` scopes:

| Method | Path | Scope |
|--------|------|-------|
| `GET` | `/api/v1/short_codes` | `short_codes:read` |
| `POST` | `/api/v1/short_codes/requests` | `short_codes:write` |
| `GET` | `/api/v1/short_codes/application` | `short_codes:read` |
| `PUT` | `/api/v1/short_codes/application` | `short_codes:write` |
| `POST` | `/api/v1/short_codes/application/preflight` | `short_codes:read` |
| `POST` | `/api/v1/short_codes/application/submit` | `short_codes:write` |

The client's own HTTP
methods reach them without a dedicated resource — paths are relative to the
`/api/v1` base:

```ruby
application = client.get("/short_codes/application")
```

The write endpoints take the application form's fields as their body. This
SDK does not model them, so check the API reference for the shape rather
than guessing: `client.put` and `client.post` pass a Hash through as JSON
unchanged (`client.delete` takes no body), and every `client.post` carries an
`Idempotency-Key` as usual.

## Business Entity Upgrade

`client.business_upgrade` runs the toll-free entity upgrade: when you form
a new legal entity, reserve a new toll-free number under it, submit it for
carrier review, and swap over on approval. The current number keeps sending
throughout the 1-2 week review.

```ruby
# Validate before submitting — advisory only, nothing is written.
# verdict is "ready", "warnings" or "blocked".
preview = client.business_upgrade.preflight(
  business_name: "Acme Holdings LLC",
  brn: "12-3456789",
  brn_type: "EIN",                    # Sendly::BusinessUpgradeResource::BRN_TYPES
  brn_country: "US",
  entity_type: "PRIVATE_PROFIT"       # Sendly::BusinessUpgradeResource::ENTITY_TYPES
)
puts preview["verdict"]
preview["issues"].each { |i| puts "#{i['severity']} #{i['field']}: #{i['code']}" }

# Prefill from the caller's other verified workspaces
best = client.business_upgrade.best_prefill

# Submit, with the IRS letter attached (ein_doc_path OR ein_doc, not both)
client.business_upgrade.start("ws_abc",
  business_name: "Acme Holdings LLC",
  brn: "12-3456789",
  brn_type: "EIN",
  brn_country: "US",
  entity_type: "PRIVATE_PROFIT",
  ein_doc_path: "./CP-575.pdf")

client.business_upgrade.status("ws_abc")     # { "pending" => nil } when none
client.business_upgrade.resubmit("ws_abc", contact_email: "ops@acme.example")
client.business_upgrade.cancel("ws_abc")

# After approval, decide what happens to the old toll-free number
client.business_upgrade.set_disposition("ws_abc",
  disposition: "moved",                      # or "released"
  target_workspace_id: "ws_other")
```

## URL Shortening (Branded Links)

Mint branded short links for a destination URL, list them with click
analytics, and disable an individual link (a per-link kill switch). Branded,
owned-domain short links improve deliverability — carriers filter public
shorteners — and give you click data.

> **Not yet GA.** URL shortening is gated behind the `url_shortener` rollout
> flag (currently founder-only). Until the flag is on for your account, calls
> return a 404 (`Sendly::NotFoundError`) — the feature reads as absent.

```ruby
# Shorten a URL (must be http/https)
link = client.links.create(url: "https://acme.example/spring-sale?utm_source=sms")
puts link.short_url        # => "https://sendly.live/l/Ab3xY7"
puts link.code             # => "Ab3xY7"
puts link.destination_url  # => "https://acme.example/spring-sale?utm_source=sms"

# List your links with click counts (limit 1-200, default 50)
listing = client.links.list(limit: 20)
puts listing.total
listing.each do |l|
  puts "#{l.short_url} -> #{l.destination_url} (#{l.click_count} clicks)"
  puts "  last click: #{l.last_country} #{l.last_clicked_at}"
  puts "  14-day spark: #{l.spark.inspect}"
end

# Disable (redirect returns 404) or re-enable a link
client.links.disable(link.code)
client.links.enable(link.code)

# Or set the state explicitly
status = client.links.update(link.code, disabled: true)
puts status.disabled?
```

## WhatsApp

Connect a number you own to WhatsApp, create Meta-reviewed message
templates, and send via `client.messages.send(channel: "whatsapp", ...)`.
Connecting is a one-time $19 setup (no monthly fee). The first number always
ends with a human step: the signup returns a connect URL a person must open in
a browser and log in with Facebook to link their WhatsApp Business Account.
More numbers can then be added to that account with a 6-digit code Meta sends
to the number, with no Facebook step (same $19 fee, refunded if it fails).

Sends go through `messages.send(channel: "whatsapp")` and need `sms:send`,
not `whatsapp:write`. Reads (`signup.get`, templates, the window, senders and
sender profiles) need `whatsapp:read` and accept test keys. Signup, template
create/edit/delete and profile edits need `whatsapp:write` and a live key
(otherwise 403 `whatsapp_requires_live_key`). Sends need a live key too. In a
team workspace, connecting and profile edits need an owner or admin
(`settings:write`), and template writes need an owner, admin or member
(`templates:write`). A missing role returns 403 `insufficient_permissions`.
Reading conversational components needs `whatsapp:read` too and accepts test
keys. The profile photo, conversational component and calling changes, and
submitting or resending a verification code, need the same as a profile edit.

WhatsApp is enabled per person: the user who owns the API key, not the
workspace. While it is off, sends return 403 `whatsapp_not_enabled` and the
`/api/v1/whatsapp/*` management routes return 404 `not_found`.

Free-form text and media only deliver inside a 24-hour customer-service
window (opened by the recipient messaging you); an approved template works
anytime. Templates are reviewed by Meta (typically 24-48h) and categorized
as authentication, utility, or marketing; `category` is required on create,
with no default, and an update can't change it.

Pricing: free-form text or media inside the 24-hour window costs 1 credit
each for the first 1,000 per sending number per calendar month (UTC), then
the destination's utility template price; countries without a listed price
use the default utility price of 12 credits. Templates are priced by category
and destination country; countries without a listed price use 33
(marketing), 12 (utility) and 12 (authentication) credits. A failed send
gives its slot back. Note: Meta
has paused marketing template delivery to US (+1) numbers.

```ruby
# 1. Connect a number ($19 one-time; a human must open the connect URL)
signup = client.whatsapp.signup.create(phone_number: "+15125550123")
puts "Have your user open: #{signup.connect_url}"

# 2. Poll until active. After the Facebook step the signup is "registering"
# while WhatsApp activates the number. Activation usually takes a few minutes
# but can take hours. If it hasn't finished about 6 hours after the session
# began, the session fails with registration_timeout and the fee is refunded.
# If the connection fails, the $19 fee is refunded automatically; once a
# number has connected, a later disconnect gets nothing back.
status = client.whatsapp.signup.get(signup.id)
puts status.failure_reasons if status.failed?  # e.g. ["waba_mismatch"]

# List your connected senders
client.whatsapp.senders.list[:senders].each do |s|
  puts "#{s.phone_number} (#{s.display_name || 'no name yet'}) — #{s.status}"
end

# Read and update a sender's business profile (what recipients see when
# they open your details in WhatsApp)
profile = client.whatsapp.senders.get_profile("+15125550123")
puts profile.display_name
puts profile.about

client.whatsapp.senders.update_profile(
  "+15125550123",
  about: "Fresh roasted coffee, delivered.",               # max 139 chars
  description: "Small-batch roaster shipping nationwide.", # max 512 chars
  website: "https://acme.example"
)

# Profile photo: a JPEG or PNG of at most 5 MB, square, at least 192 px wide
client.whatsapp.senders.upload_profile_photo("+15125550123", "logo.png",
                                             content_type: "image/png", filename: "logo.png")
client.whatsapp.senders.delete_profile_photo("+15125550123")

# Ice breakers (tappable suggestions on a first chat) and "/" commands. Each
# list you pass replaces the stored one; [] clears it.
client.whatsapp.senders.update_conversational_components(
  "+15125550123",
  ice_breakers: ["Track my order", "Opening hours"],     # at most 4
  commands: [{ command: "menu", description: "See today's menu" }]  # at most 30
)
components = client.whatsapp.senders.get_conversational_components("+15125550123")
components.commands.each { |c| puts "/#{c.command}: #{c.description}" }

# WhatsApp calling: WhatsApp users calling the number ring like a phone call.
# Switch voice on for the number first. There is no API for placing WhatsApp
# calls.
settings = client.whatsapp.senders.set_calling("+15125550123", enabled: true)
puts settings.calling_enabled?

# Add another number to the account you already connected: no Facebook step.
# Meta sends the number a 6-digit code by text ("sms", the default) or call.
sender = client.whatsapp.senders.list[:senders].find(&:active?)
added = client.whatsapp.signup.create(
  phone_number: "+15125550124",
  business_account_id: sender.business_account_id,
  verification_method: "sms"
)
puts added.status  # "verifying"

# The code can be read back once Meta's text arrives on the number. Until a
# code has been submitted it is the newest code since the signup started, so
# after a resend it still shows the earlier code until the new one arrives.
# Once WhatsApp has checked a code, only a code that arrived after the last
# submission or resend is returned. A 502 whatsapp_verification_unavailable
# isn't counted, so the same unchecked code can come back, and submitting it
# again is safe.
code = client.whatsapp.signup.get(added.id).verification_code
client.whatsapp.signup.verify(added.id, code: code) if code
# Or ask for a new one (at most every 30 seconds)
client.whatsapp.signup.resend(added.id, verification_method: "voice")

# 3. Create a template (Meta reviews it, usually 24-48h)
template = client.whatsapp.templates.create(
  sender: "+15125550123",
  name: "order_shipped",
  language: "en_US",
  category: "UTILITY",
  header: "Order update",  # fixed text only: a header with {{n}} is refused
  body: "Hi {{1}}, your order {{2}} has shipped!",
  examples: { "1" => "Sam", "2" => "#4821" }
)
puts template.status  # "PENDING"

# List, edit-and-resubmit (the recovery path for rejections), or delete
client.whatsapp.templates.list[:templates].each { |t| puts "#{t.name} — #{t.status}" }
client.whatsapp.templates.update(template.id, body: "Hi {{1}}, order {{2}} is on its way!",
                                              examples: { "1" => "Sam", "2" => "#4821" })
client.whatsapp.templates.delete(template.id)

# 4. Send — free-form inside an open 24h window, template anytime. The window
# is exactly { open, expiresAt }: no window on record reads open false with
# expires_at nil; an expired one reads open false with its past expires_at.
window = client.whatsapp.window(from: "+15125550123", to: "+15555550100")
if window.open?
  client.messages.send(
    channel: "whatsapp",
    to: "+15555550100",
    from: "+15125550123",
    text: "Your table is ready!"
  )
else
  message = client.messages.send(
    channel: "whatsapp",
    to: "+15555550100",
    from: "+15125550123",
    template: {
      name: "order_shipped",
      language: "en_US",
      variables: { "1" => "Acme Inc", "2" => "#4821" }
    }
  )
  puts message.whatsapp.kind  # "template"
end

# Media with a caption (also window-bound; one attachment per message)
client.messages.send(
  channel: "whatsapp",
  to: "+15555550100",
  from: "+15125550123",
  text: "Here is your receipt",
  media_urls: ["https://acme.example/receipt.pdf"]
)
```

WhatsApp errors map onto the usual classes:

- `signup.create` raises `Sendly::ServerError` for 503 `whatsapp_unavailable`
  while WhatsApp connections are unavailable. Only signup returns it; no send
  does. Nothing is charged, the response carries a `Retry-After: 3600` header,
  and `e.response_body["retryAfter"]` (3600) says how many seconds to wait; the client
  retries it like any 5xx before raising. After 5 failed, charged signups in
  24 hours it raises `Sendly::RateLimitError` for 429
  `whatsapp_signup_limit_reached`, which is not retried: try again the next
  day.
- A send outside an open window raises `Sendly::ValidationError` (422
  `whatsapp_window_closed`); send a template instead.
- `whatsapp_send_failed` is a `Sendly::ValidationError` (422) when WhatsApp
  refused the message, which is final (cached under the idempotency key and
  replayed for 24 hours), and a `Sendly::ServerError` (502) when the message
  provably never reached the carrier, so it was not sent and is safe to send
  again; the 502 is never cached and the client retries it first under the
  same idempotency key. Neither is charged.
- `whatsapp_send_unconfirmed` is a `Sendly::APIError` with `status_code` 409:
  the outcome is unknown. The message was marked failed and refunded but may
  still be delivered, so check before sending it again (it could arrive
  twice). It is not retried automatically, and it is cached under the
  idempotency key.
- A send while WhatsApp is off for the key's owner gets 403
  `whatsapp_not_enabled`; a test key on a send or a write gets 403
  `whatsapp_requires_live_key`.
- `templates.create` for a sender that isn't connected raises
  `Sendly::NotFoundError` (404 `whatsapp_sender_not_connected`), checked
  before anything else.
- A template the API refuses for its content raises `Sendly::ValidationError`
  (400) with a `template_*` code in `e.response_body["error"]`:
  `template_category_invalid` (category missing or not one of the three),
  `template_authentication_otp_button_required`,
  `template_authentication_no_links` (a link in the body or a URL button on an
  authentication template) or `template_header_variable_unsupported`. A
  marketing template without an opt-out button only gets a warning. `template_already_exists`,
  `template_name_locked` and `template_not_editable` are a `Sendly::APIError`
  with `status_code` 409, and `template_not_found` is a
  `Sendly::NotFoundError`.
- Adding a number by code: `signup.create` with `business_account_id:` raises
  `Sendly::NotFoundError` for 404 `whatsapp_business_account_not_found` (the
  account isn't connected in this workspace), `Sendly::ValidationError` for
  400 `display_name_required` and for 422 `whatsapp_verification_start_failed`
  (WhatsApp refused to verify the number; final), `Sendly::APIError` (409) for
  `whatsapp_signup_in_progress` and `whatsapp_already_enabled`, and
  `Sendly::ServerError` for 502 `whatsapp_verification_start_failed` (WhatsApp
  couldn't start verifying the number; start again). Either failure fails the
  session and refunds its fee. With `business_account_id:` the client never
  retries a 5xx, a timeout or a dropped connection, because each retry would
  start a new charged session. A
  Facebook signup for a number
  that is being added by code gets 409 `whatsapp_verification_in_progress`,
  with that session's id in `e.response_body["id"]`.
- `signup.verify` raises `Sendly::ValidationError` for 400
  `invalid_verification_code` (not 6 digits) and 422
  `whatsapp_verification_code_invalid` (a wrong code, with
  `e.response_body["attemptsRemaining"]`); `Sendly::APIError` (409) for
  `whatsapp_verification_failed` (after 5 wrong codes the session fails and
  the fee is refunded), `whatsapp_verification_busy` (try again) and
  `signup_not_active`; and `Sendly::ServerError` for 502
  `whatsapp_verification_unavailable` (the attempt isn't counted) and
  `whatsapp_activation_pending` (the code was accepted but connecting didn't
  finish; check back shortly with `signup.get`). The client never retries a
  5xx, a timeout or a dropped connection from `signup.verify`: each
  submission uses one of the 5 attempts.
  `signup.resend` is retried like any other call.
- `signup.resend` raises `Sendly::RateLimitError` for 429
  `whatsapp_verification_resend_too_soon` at once, with the seconds to wait in
  `e.retry_after`, and `whatsapp_verification_resend_failed` as a
  `Sendly::ValidationError` (422) or a `Sendly::ServerError` (502).
- `senders.upload_profile_photo` raises `Sendly::ValidationError` for 400
  `whatsapp_profile_photo_invalid` (not a JPEG or PNG) and `file_required`,
  and `Sendly::APIError` with `status_code` 413 for
  `whatsapp_profile_photo_too_large`. The photo methods raise
  `Sendly::ServerError` for 502 `whatsapp_profile_update_failed`, and the
  conversational component methods for 502
  `whatsapp_conversational_components_fetch_failed` and
  `whatsapp_conversational_components_update_failed`; an invalid list is a
  `Sendly::ValidationError` (400 `invalid_request`) with a message naming the
  problem. The client never retries a 5xx, a timeout or a dropped connection
  from `senders.upload_profile_photo`.
- `senders.set_calling` raises `Sendly::APIError` (409) for `voice_not_enabled`
  (switch voice on for the number first), `Sendly::ValidationError` for 422
  `whatsapp_calling_unavailable` (Meta only allows calling once the account may
  message at least 2,000 people a day and the display name is approved), and
  `Sendly::ServerError` for 502 `whatsapp_calling_update_failed`.
- A sender method for a number that isn't connected raises
  `Sendly::NotFoundError` (404 `whatsapp_sender_not_connected`).

## RCS

Send branded rich messages — text with suggested replies and actions, or
rich cards with an image and buttons — through your workspace's RCS agent
by passing `channel: "rcs"` to `client.messages.send`. Delivery is
per-recipient: not every device or network supports RCS. Text sends fall
back to plain SMS automatically (billed as SMS) unless you disable the
fallback; rich cards have no SMS form and only deliver to RCS-capable
recipients.

The RCS channel is being rolled out gradually and is not yet generally
available; until it is enabled for your account the endpoints read as
absent and calls raise `Sendly::NotFoundError` (HTTP 404: `not_found` on
sends and listing, `rcs_not_enabled` on registration). RCS sends and
capability checks require a live API key.

### Registering an agent

Registration is self-serve, from the dashboard or the API. Draft the
brand (the business) and the agent (what recipients see), submit them for
Sendly's review, and once approved they go on to the carrier network for
brand verification and agent review. The agent then reaches invited test
devices only; when you have tested it, request launch and Sendly reviews
the campaign before sending the launch on to the carrier network. Watch
`customer_stage` (one of `Sendly::RcsRegistration::CUSTOMER_STAGES`) to
see where a registration is.

Registration reads need the `rcs:read` scope and writes `rcs:write`; test
and live keys both work, since drafting is not carrier-backed. Logo, hero
and call-to-action media must be public `https://` URLs: assets cannot be
uploaded over the API, only from the dashboard. Nested hashes (address,
contact, basics, campaign, testing) accept snake_case or camelCase keys.
Every write accepts `idempotency_key:`; `POST`s get an auto-generated key
as usual, while `PATCH` and `PUT` send one only when you pass it.

```ruby
# Where is the registration at?
reg = client.rcs.registration.get
puts reg.stage  # "draft" until something is submitted

# Seed the brand from details Sendly already holds (your 10DLC brand or
# toll-free verification), then fill in the rest
dossier = client.rcs.dossier.get
brand = client.rcs.brands.create(**dossier.brand)  # dossier.source: "tendlc", "verification" or "none"
client.rcs.brands.update(brand.id,
  display_name: "Acme Coffee",
  legal_entity_type: "LIMITED_LIABILITY_COMPANY",
  contact: { first_name: "Sam", last_name: "Lee", email: "sam@acme.example",
             phone_number: "+15125550123" }
)

# Draft the agent. Media must be public https URLs.
agent = client.rcs.agents.create(
  brand_id: brand.id,
  display_name: "Acme Coffee",
  use_case: "MULTI_USE",
  basics: {
    description: "Order updates and offers from Acme Coffee",
    logo_url: "https://acme.example/rcs/logo.png",
    hero_url: "https://acme.example/rcs/hero.png",
    brand_color: "#5B3A29",
    privacy_policy_url: "https://acme.example/privacy",
    terms_and_conditions_url: "https://acme.example/terms",
    phone_number: { number: "+15125550123", label: "Support" }
  }
)

# Submit for Sendly's review. Pass your own key if you may retry: a replay
# returns the original response without submitting again.
agent = client.rcs.agents.submit(agent.id, idempotency_key: "rcs-submit-#{agent.id}")
puts agent.review_status  # "awaiting_review"

# Later: poll, and act on a review note
agent = client.rcs.agents.get(agent.id)
if agent.changes_requested?
  puts agent.review_note
  client.rcs.agents.update(agent.id, basics: { hero_url: "https://acme.example/rcs/hero-v2.png" })
end

# Once the agent is in testing, invite devices, describe the campaign,
# then request launch
client.rcs.agents.set_test_devices(agent.id, devices: [
  { phone_number: "+15125550123", label: "Sam's Pixel" }
])
client.rcs.agents.update(agent.id,
  campaign: {
    company_overview: "Specialty coffee roaster with three cafes in Austin",
    agent_overview: "Order updates, pickup alerts and support replies",
    interactions: [{ interaction_type: "TRANSACTIONAL_UPDATES",
                     description: "Order and pickup status" }],
    message_examples: ["Your order #4821 has shipped!",
                       "Your latte is ready for pickup at 5th St",
                       "Reply HELP for support or STOP to opt out"],
    consent_settings: {
      opt_in_methods: [{ method_type: "WEBSITE", description: "Checkbox at checkout" }],
      call_to_action: "Get order updates by RCS",
      call_to_action_url: "https://acme.example/updates",
      double_opt_in: false,
      help_response: "Acme Coffee: reply STOP to opt out, or email help@acme.example",
      opt_out_response: "You're opted out of Acme Coffee updates."
    }
  }
)
client.rcs.agents.request_launch(agent.id, test_url: "https://acme.example/rcs-test")
```

Registration errors map onto the usual classes: `Sendly::NotFoundError`
for `rcs_not_enabled` and `rcs_not_found`; `Sendly::ValidationError` for
`rcs_us_only` and `rcs_invalid_content`, whose `field_errors` is the API's
list of `{ "path", "message" }` hashes; and `Sendly::APIError` with
`status_code` 409 for `rcs_field_locked`, `rcs_brand_not_verified` and
`rcs_launch_not_ready`, or 403 for a key missing the scope.

### Sending

```ruby
# Discover your RCS agents ("testing" reaches invited test devices only;
# "approved" reaches everyone). Pass agent_id on sends and capability
# checks when your workspace has more than one agent.
client.rcs.agents.list[:agents].each do |a|
  puts "#{a.name} — #{a.status}#{a.sendable? ? ' (sendable)' : ''}"
end

# Pre-flight: can this recipient receive RCS?
capability = client.rcs.capability(to: "+15125550123")
puts capability.capable? ? "RCS" : "would fall back to SMS"

# Text with suggested replies and actions. Nested suggestion and card
# hashes are passed through verbatim, so they use the camelCase keys the
# API expects.
message = client.messages.send(
  channel: "rcs",
  to: "+15125550123",
  text: "Your order has shipped! Want live updates?",
  suggestions: [
    { reply: { text: "Yes, notify me", postbackData: "notify_yes" } },
    { action: { text: "Track order", postbackData: "track",
                url: "https://acme.example/orders/4821" } }
  ]
)

# The response discloses which channel delivered
puts message.channel # "rcs", or "sms" when it fell back
if message.fell_back?
  # Delivered as plain SMS (billed as SMS). Suggestions have no SMS form
  # and were dropped — message.rcs.suggestions_dropped is true.
else
  puts message.rcs.kind       # "text" or "card"
  puts message.rcs.agent_name # the brand name recipients see
end

# Rich card (RCS-capable recipients only — cards have no SMS form)
client.messages.send(
  channel: "rcs",
  to: "+15125550123",
  card: {
    title: "Spring collection",
    description: "New arrivals are in - take a look.",
    mediaUrl: "https://acme.example/spring.jpg", # public JPEG, PNG, or GIF
    orientation: "vertical",                    # or "horizontal"
    suggestions: [
      { action: { text: "Shop now", postbackData: "shop",
                  url: "https://acme.example/spring" } }
    ]
  }
)

# Opt out of the SMS fallback — the send raises Sendly::ValidationError
# (HTTP 422 rcs_not_supported_for_recipient) when the recipient can't
# receive RCS
client.messages.send(
  channel: "rcs",
  to: "+15125550123",
  text: "RCS or nothing",
  fallback_to_sms: false
)
```

## Voice Calls

Place phone calls that one of your AI agents handles, list and inspect
calls, end a call early, and download recordings. Agents are created with
`client.voice.agents` or in the dashboard under Calls, then Agents; the
number you call from must have voice switched on and an emergency address
registered before it can place outbound calls (see
[Configure voice](#configure-voice), or Calls, then Settings in the
dashboard). Each `Sendly::PhoneNumber`
from `client.numbers.list` carries `voice_enabled?` and `voice_mode`
(`"none"`, `"ring_dashboard"` or `"agent"`) so you can pick a `from`:

```ruby
from = client.numbers.list[:numbers].find(&:voice_enabled?)&.phone_number
```

Calls are prepaid from your credit balance per started minute: 2 credits a
minute outbound, plus 8 a minute while an AI agent is on the call (10 in
total for an API-placed call). Unanswered calls cost nothing. Destinations
are US and Canadian numbers. Reads need the `calls:read` scope; `create`
and `hangup` need `calls:write` and a live key.

> **Rolling out.** Voice is enabled workspace by workspace. Until it is on
> for yours, every `client.calls` and `client.voice` method raises
> `Sendly::NotFoundError` (`voice_not_enabled`).

```ruby
# Place a call. Returns at once with the call ringing; the agent greets the
# callee when they answer and uses `context` for this call only.
call = client.calls.create(
  to: "+15125550123",
  agent_id: "3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b",
  from: "+15555550100",                # optional when you have one voice number
  context: "Confirm the 3pm appointment on Tuesday.",
  metadata: { "crmId" => "lead_8812" } # up to 20 string pairs, echoed everywhere
)
puts call.id
puts call.status        # "ringing"
puts call.handled_by    # "agent"

# Follow it. Agent-handled calls include a transcript once fetched by id.
call = client.calls.get(call.id)
puts call.status        # "ringing" -> "active" -> "completed" (or no_answer, busy, ...)
puts call.hangup_class  # why it ended, e.g. "agent_agent_hangup"
puts call.credits_charged
call.transcript&.each { |line| puts "#{line.speaker}: #{line.text}" }

# List (newest first; limit 1-100, default 50)
page = client.calls.list(status: "completed", direction: "outbound", agent_id: call.agent_id, limit: 20)
page.each { |c| puts "#{c.to} #{c.duration_secs}s #{c.credits_charged} credits" }
puts page.total
puts page.has_more?

# End a call. Ringing -> "cancelled", active -> "completed"; a call that
# has already ended comes back unchanged.
client.calls.hangup(call.id)

# Recording. The URL is signed and valid for five minutes; it is nil until
# the recording is ready. Ogg/Opus; agent calls are dual channel, with the
# agent on the left channel and the other party on the right.
rec = client.calls.recording(call.id)
if rec.ready?
  File.binwrite("#{call.id}.ogg", Net::HTTP.get(URI(rec.url)))
end
```

Call errors map onto the usual classes: `Sendly::InsufficientCreditsError`
when the balance cannot cover one minute at the agent rate;
`Sendly::NotFoundError` for `voice_not_enabled`, `outbound_calls_not_enabled`,
`agent_not_found`, `number_not_found` and `call_not_found`;
`Sendly::ValidationError` for `invalid_number`, `destination_not_supported`,
`agent_required`, `invalid_metadata`, `from_number_required` and
`from_number_not_supported` (a `from` that is not a US or Canadian number);
`Sendly::RateLimitError` for `daily_call_limit`; `Sendly::APIError` with
`status_code` 428 for `e911_required` (register an emergency address for the
number), 409 for `agent_disabled`, `no_voice_number` and `lines_busy` (retry
shortly), or 403 for `live_key_required` and a key missing the scope; and
`Sendly::ServerError` (a sibling of `APIError`, not a subclass) for 503
`voice_unavailable` / `agents_unavailable` and 500 `voice_internal_error`.
The full list is `Sendly::Call::ERROR_CODES`; the hangup vocabulary is
`Sendly::Call::HANGUP_CLASSES`.

`call.channel` is where the call took place: `"phone"`, `"whatsapp"` (a
WhatsApp call, for example one placed from the dashboard) or `"browser"`
(`Sendly::Call::CHANNELS`); a value this SDK predates comes through unchanged.
An inbound WhatsApp call can read `"phone"` until the carrier labels it.

`call.started`, `call.completed` and `call.recording.ready` webhooks carry
the same object in snake_case (`channel`, `handled_by`, `hangup_class`,
`billing`, `metadata`, ...); read it from `event.data`, for example
`event.data[:channel]`.

### Configure voice

Everything a call depends on is configurable from code with `client.voice`:
switch voice on for a number and choose how it answers, register the
number's emergency address, and create the AI agents that talk. Reads need
the `calls:read` scope; writes need `calls:write` and a live key. In a team
workspace, changing a number or its emergency address also needs a role that
can change settings, and managing agents a role that can manage API keys
(each agent holds its own scoped sending key).

```ruby
# Numbers. Pass the number's id or its E.164 phone number.
client.voice.numbers.list.each do |n|
  puts "#{n.phone_number} #{n.voice_mode} #{n.emergency_address&.status || 'no emergency address'}"
end
number = client.voice.numbers.get("+15125550123")
puts number.rate_per_minute.agent   # credits a minute when an agent answers

# A US or Canadian number needs an emergency address before it can place
# calls. The first registration adds $1.50 a month to the number;
# registering again replaces the address without a second charge.
number = client.voice.numbers.register_emergency_address(
  "+15125550123",
  street: "500 Example Ave",
  unit: "Suite 2",
  city: "Austin",
  state: "TX",
  zip: "78701"                      # country: defaults to "US"
)
puts number.emergency_address.status

# Voices and agents. An agent answers real callers on any number pointed at it.
client.voice.voices.list.each { |v| puts "#{v.id}: #{v.label}" }

agent = client.voice.agents.create(
  name: "Front desk",
  voice: "ashley",
  greeting: "Thanks for calling Acme, how can I help?",
  instructions: "Answer questions about opening hours and take a message for anything else.",
  tools: { send_sms: true }         # snake_case or camelCase keys
)
puts agent.can_send_sms?            # true once it holds its scoped sending key
client.voice.agents.update(agent.id, greeting: "Thanks for calling Acme. How can I help today?")
client.voice.agents.list.each { |a| puts "#{a.name}: #{a.calls_handled} calls" }

# Switching voice on changes how real calls to the number are answered.
client.voice.numbers.update("+15125550123", voice_enabled: true, voice_mode: "agent", agent_id: agent.id)
client.voice.numbers.update("+15125550123", voice_mode: "ring_dashboard") # ring the team instead
client.voice.numbers.update("+15125550123", voice_enabled: false)         # switch voice off

# An agent that answers a number can't be deleted until the number is moved.
begin
  client.voice.agents.delete(agent.id)
rescue Sendly::APIError => e
  raise unless e.response_body&.dig("error") == "agent_in_use"

  puts "Still answers #{e.response_body['numbers'].join(', ')}"
end
```

A mode alone is enough: `voice_mode: "agent"` or `"ring_dashboard"` switches
voice on, so it can fail the way switching on does, and `voice_mode: "none"`
switches it off. `voice_enabled: false` wins over any mode, and
`voice_enabled: true` with `"none"` answers in `"ring_dashboard"` mode.

Configuration errors map the same way: `Sendly::NotFoundError` for
`number_not_found` and `agent_not_found`; `Sendly::ValidationError` for
`invalid_request` (for example an emergency address field that is not a
string), `invalid_voice_mode`, `agent_required`,
`e911_not_applicable` and `invalid_address` (a 422 `invalid_address` means
the address could not be validated, and `e.response_body["suggested"]` holds
a corrected address when one was found); `Sendly::APIError` with
`status_code` 409 for `agent_disabled`, `agent_limit` (20 agents per
workspace) and `agent_in_use`; and `Sendly::ServerError` for 502
`voice_attach_failed` and `carrier_refused` and 503 `voice_unavailable`,
raised after the client has already retried the 5xx on its own. Not every
`carrier_refused` is worth retrying: when the message says the number
couldn't be found for emergency registration, retrying won't help, so
contact support. When it says the address couldn't be registered or
emergency calling couldn't be switched on, try again later. Every API error
keeps the parsed body on `e.response_body`.

## Error Handling

```ruby
begin
  message = client.messages.send(
    to: "+15125550123",
    text: "Hello!"
  )
rescue Sendly::AuthenticationError => e
  puts "Invalid API key"
rescue Sendly::RateLimitError => e
  if e.response_body&.dig("error") == "too_many_failed_key_attempts"
    # Repeated wrong API keys from this address locked it out for up to
    # 5 minutes. Fix the key; do not retry until the lockout ends.
    puts "Locked out for #{e.retry_after}s: check the API key"
  else
    puts "Rate limited (#{e.response_body&.dig('error')}), retry after #{e.retry_after} seconds"
  end
rescue Sendly::InsufficientCreditsError => e
  puts "Add more credits to your account"
rescue Sendly::ValidationError => e
  puts "Invalid request: #{e.message}"
rescue Sendly::NotFoundError => e
  puts "Resource not found"
rescue Sendly::NetworkError => e
  puts "Network error: #{e.message}"
rescue Sendly::Error => e
  puts "Error: #{e.message} (#{e.response_body&.dig('error') || e.code})"
end
```

Every error is a `Sendly::Error`, which carries `message`, `code`,
`status_code`, `details` and `response_body` — the parsed JSON body of the
API's response, or `nil` for an error raised before the request went out.
The API's own error code is `e.response_body["error"]`; `code` is the SDK's
name for the class (`"VALIDATION_ERROR"`, `"RATE_LIMIT_EXCEEDED"` and so on),
except on `APIError`, where it is the body's `"code"` when there is one. Some
refusals put more in that body than a message: a 409 `agent_in_use` lists the
numbers under `"numbers"`, a 422 `invalid_address` carries a corrected
address under `"suggested"`.

Some requests are refused before they are sent, with `response_body` `nil`:
an argument the method checks itself raises `ArgumentError` or
`Sendly::ValidationError`, and any ID that is empty, `"."` or `".."` raises
`Sendly::ValidationError`, so an ID can never send a request to a different
endpoint.

| Class | Raised for |
|-------|-----------|
| `Sendly::AuthenticationError` | 401, and a missing or malformed API key at construction |
| `Sendly::ValidationError` | 400 and 422; `field_errors` holds the API's `errors` list. `status_code` reads 400 for both, so tell them apart by `response_body["error"]` |
| `Sendly::InsufficientCreditsError` | 402 |
| `Sendly::NotFoundError` | 404, including a feature that is not enabled for you |
| `Sendly::RateLimitError` | 429; `retry_after` in seconds when the API sent one |
| `Sendly::ServerError` | 5xx |
| `Sendly::APIError` | any other non-2xx status |
| `Sendly::NetworkError` | connection refused or reset, DNS failure |
| `Sendly::TimeoutError` | a timeout (subclass of `NetworkError`) |
| `Sendly::WebhookSignatureError` | a webhook signature that does not verify, or a malformed payload |

`ServerError` and `APIError` are siblings — both inherit `Sendly::Error`
directly — so rescuing `APIError` does **not** catch a 5xx.

### Retries and rate limits

The client retries two kinds of response by itself, up to `max_retries`
(default 3), and sends every retry with the same idempotency key, generated
or yours:

- any 5xx, with exponential backoff (2, 4, 8... seconds);
- a 429 that waiting can fix, when its wait is 60 seconds or less: an
  ordinary `rate_limit_exceeded`, the per-minute `provision_rate_limit` from
  enterprise workspace provisioning (120 provisioning requests a minute), a
  429 with no `error`
  code, or `too_many_concurrent_verifications` (too many first-time API key
  checks at once). The wait is read from the `Retry-After` header first, then
  from the body's `retryAfter`, so a 429 from a proxy that sends only the
  header is waited out too.

Every other 429 is raised at once as a `Sendly::RateLimitError`, with the
API's code in `e.response_body["error"]` and the wait in `e.retry_after`:

- `too_many_failed_key_attempts`: repeated wrong API keys from one address
  locked it out for up to 5 minutes. Fix the key, then wait, since until the
  lockout ends the right key can be refused too.
- `rate_limit_exceeded` from `verify.send` and `verify.resend` at the
  per-phone limit (5 codes per 10 minutes) or the daily limit (20 a day),
  while more than a minute of that window remains, so the call raises instead
  of blocking and then sending a code nobody is waiting for. In the window's
  last minute the wait is 60 seconds or less, and the client waits it out and
  sends the code like any other rate limit.
- the hourly `provision_rate_limit` (1,000 provisioning requests an hour; a
  `provision_bulk` call counts as one), so you can pace provisioning. It too
  is waited out once 60 seconds or less of the hour remain.
- `whatsapp_signup_limit_reached` and `daily_call_limit`.

A 429 with no wait at all is raised at once too. Timeouts and network errors
are never retried: retry those yourself, with your own idempotency key.
`enterprise.upload_verification_document`, `business_upgrade.start` and
`business_upgrade.resubmit` send their uploads once, so any 429 or 5xx there
is raised at once.

## Message Object

```ruby
message.id           # Unique identifier
message.to           # Recipient phone number
message.from         # Sender ID or number (the default sender when you omit from:; "SENDLY-TEST" when simulated)
message.text         # Message content
message.status       # see Message Status below
message.direction    # "outbound" or "inbound"
message.segments     # Number of SMS segments
message.credits_used # Credits consumed
message.is_sandbox   # true for a simulated message (read it via messages.get or list; a send response leaves it false)
message.sender_type  # "number_pool", "alphanumeric" or "explicit" (live sends only)
message.created_at   # Creation time (Time)
message.delivered_at # Delivery time (Time, if delivered)
message.error        # Error message (if failed)
message.error_code   # Error code (if failed)
message.retry_count  # Delivery retry attempts
message.metadata     # The metadata Hash you attached
message.media_urls   # Attachments of an MMS; [] when there are none
message.message_format # "sms", "mms", "rcs" or "whatsapp" ("sms" when the API does not say)
message.ai_metadata  # AI classification, on inbound messages
message.warning      # Warning about the send, when the API sent one
message.sender_note  # Note about sender behaviour, when the API sent one

# Helper methods
message.delivered?   # => true/false
message.failed?      # => true/false
message.pending?     # => true/false
message.to_h         # => Hash of the above
```

There is no `updated_at` and no `error_message`; the failure text is on
`error`. `Sendly::Message` is what `messages.send`, `messages.get` and
`messages.list` return for SMS — a WhatsApp send returns a
`Sendly::WhatsAppMessage`, an RCS send a `Sendly::RcsMessage`, and a group
send a `Sendly::GroupMessage`, each with its own channel fields.

## Message Status

`Sendly::Message::STATUSES` is the vocabulary:

| Status | Description |
|--------|-------------|
| `queued` | Message is queued for delivery |
| `sent` | Message was sent to carrier |
| `delivered` | Message was delivered |
| `failed` | Message delivery failed |
| `bounced` | Invalid recipient, or the carrier rejected it |
| `retrying` | A failed send is being retried |

There is no `sending` status. WhatsApp and RCS additionally report reads,
as the `message.read` webhook (`Sendly::Webhooks::EVENT_MESSAGE_READ`);
SMS has no read receipts.

## Pricing Tiers

Per segment, at 1 credit = $0.01.

| Tier | Countries | Credits per SMS |
|------|-----------|-----------------|
| Domestic | US, CA | 2 |
| Tier 1 | GB, AU, PL, PT, SE, DK, etc. | 8 |
| Tier 2 | FR, JP, IN, IT, etc. | 12 |
| Tier 3 | DE, MX, etc. | 16 |
| Tier 4 | GE, MU, ME, AD, etc. | 24 |
| Tier 5 | IL, SI, etc. | 48 |

A multi-segment message costs its tier's rate per segment. Enterprise
accounts can have per-country or per-tier rates overridden, in which case
the override applies instead.

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

## Enterprise

The Enterprise API lets you programmatically manage workspaces, verification, credits, and API keys for multi-tenant platforms. It requires an enterprise master key — an ordinary live key (`sk_live_v1_…`) that has been marked as your organization's master key in the dashboard; what distinguishes it is the flag on the key, not the prefix. A non-master key is refused with 403 `enterprise_required`, and a master key whose enterprise account is inactive with 403 `enterprise_inactive`. Master keys also get the higher rate limit of 3,000 requests a minute.

### Quick Provision

Create a fully configured workspace in a single call:

```ruby
client = Sendly::Client.new(api_key: "sk_live_v1_your_master_key")

result = client.enterprise.provision(
  name: "Acme Insurance - Austin",
  source_workspace_id: "ws_verified",
  credit_amount: 5000,
  credit_source_workspace_id: "SOURCE_WORKSPACE_ID",
  key_name: "Production",
  key_type: "live",
  generate_opt_in_page: true
)

puts result["workspace"]["id"]
puts result["key"]["key"]
```

Three provisioning modes:

| Mode | Params | Description |
|------|--------|-------------|
| **Inherit** | `source_workspace_id:` | Shares toll-free number from verified workspace |
| **Inherit + New Number** | `source_workspace_id:` + `inherit_with_new_number: true` | Copies business info, purchases new number |
| **Fresh** | `verification: { ... }` | Full business details, new number + carrier approval |

### Workspace Management

```ruby
ws = client.enterprise.workspaces.create(name: "Acme Insurance")
list = client.enterprise.workspaces.list
detail = client.enterprise.workspaces.get("ws_xxx")
client.enterprise.workspaces.delete("ws_xxx")
```

### Credits & API Keys

```ruby
client.enterprise.workspaces.transfer_credits("ws_dest",
  source_workspace_id: "ws_source", amount: 5000)

# type: is "test" (the default) or "live"; scopes: defaults to every scope.
# A name is required: a missing or empty one raises ArgumentError.
key = client.enterprise.workspaces.create_key("ws_xxx",
  name: "Production", type: "live", scopes: ["sms:send", "sms:read"])
puts key["key"]      # shown only once
puts key["scopes"].inspect

client.enterprise.workspaces.revoke_key("ws_xxx", "key_abc")
```

### Webhooks & Analytics

```ruby
client.enterprise.webhooks.set(url: "https://hooks.acme.example/enterprise")
client.enterprise.webhooks.test
client.enterprise.webhooks.rotate_secret

overview = client.enterprise.analytics.overview
messages = client.enterprise.analytics.messages(period: "30d")
delivery = client.enterprise.analytics.delivery
credits  = client.enterprise.analytics.credits(period: "30d")
```

### The rest of the enterprise surface

```ruby
# Verification, per workspace. A first submission needs business_name, website,
# address, contact, use_case, use_case_summary, sample_messages and
# opt_in_workflow. A resubmit after a rejection may send only the top-level
# fields that change, but an address or contact Hash replaces the stored one
# whole, so send every key of it.
client.enterprise.workspaces.submit_verification("ws_xxx", **verification_fields)
client.enterprise.workspaces.resubmit_verification("ws_xxx",
  contact: { firstName: "Sam", lastName: "Rivera", email: "new@acme.example", phone: "+15555550100" })
# Share the source workspace's verification and sending number (nothing is
# bought), or copy only its business details and buy the workspace its own
# toll-free number; the response then has "newNumber" => true.
client.enterprise.workspaces.inherit_verification("ws_xxx", source_workspace_id: "ws_verified")
client.enterprise.workspaces.inherit_verification("ws_other", source_workspace_id: "ws_verified",
                                                              purchase_new_number: true)
client.enterprise.workspaces.get_verification("ws_xxx")
client.enterprise.upload_verification_document("./CP-575.pdf", workspace_id: "ws_xxx")

# Hosted opt-in pages, and a generated business page
client.enterprise.workspaces.list_opt_in_pages("ws_xxx")
client.enterprise.workspaces.create_opt_in_page("ws_xxx", business_name: "Acme LLC")
client.enterprise.workspaces.update_opt_in_page("ws_xxx", "page_x", header_color: "#5B3A29")
client.enterprise.workspaces.delete_opt_in_page("ws_xxx", "page_x")
client.enterprise.workspaces.set_custom_domain("ws_xxx", "page_x", domain: "sms.acme.example")
client.enterprise.generate_business_page(business_name: "Acme LLC")

# Members: invite into a workspace, list and cancel invitations
client.enterprise.workspaces.send_invitation("ws_xxx", email: "sam@acme.example", role: "member")
client.enterprise.workspaces.list_invitations("ws_xxx")
client.enterprise.workspaces.cancel_invitation("ws_xxx", "inv_x")

# Suspend / resume, quotas, per-workspace webhooks, bulk provisioning
client.enterprise.workspaces.suspend("ws_xxx", reason: "non-payment")
client.enterprise.workspaces.resume("ws_xxx")
client.enterprise.workspaces.get_quota("ws_xxx")
client.enterprise.workspaces.set_quota("ws_xxx", monthly_message_quota: 50_000)
client.enterprise.workspaces.set_webhook("ws_xxx", url: "https://yourapp.example/hooks")
client.enterprise.workspaces.list_webhooks("ws_xxx")
client.enterprise.workspaces.test_webhook("ws_xxx")
client.enterprise.workspaces.delete_webhooks("ws_xxx", webhook_id: "whk_xxx")
client.enterprise.workspaces.provision_bulk([{ name: "Acme Austin" }])  # max 100
client.enterprise.workspaces.get_credits("ws_xxx")
client.enterprise.workspaces.list_keys("ws_xxx")

# Enterprise-level account, credits and billing
client.enterprise.get_account
client.enterprise.credits.get
client.enterprise.settings.get_auto_top_up
client.enterprise.settings.update_auto_top_up(enabled: true, threshold: 1000, amount: 10_000)
client.enterprise.billing.get_breakdown(period: "30d")
```

These return the API's parsed Hash rather than typed objects.

Full enterprise docs: [sendly.live/docs/enterprise](https://sendly.live/docs/enterprise)

---

## Requirements

- Ruby 3.0+

The client is built on Ruby's standard-library `net/http` and does not use Faraday at runtime. The gemspec still declares `faraday` and `faraday-retry` so this release does not drop a runtime dependency that callers may be resolving transitively. Both are unused and are slated for removal in the next major version.

## License

MIT
