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

# With custom metadata (max 4KB)
message = client.messages.send(
  to: "+15551234567",
  text: "Your order #12345 has shipped!",
  metadata: { order_id: "12345", customer_id: "cust_abc" }
)

# Send from one of your owned numbers (or an alphanumeric sender ID).
# Omit `from` to use your default sender.
message = client.messages.send(
  to: "+15551234567",
  text: "Hello from our team!",
  from: "+447111111111"
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

# List scheduled messages (returns a Hash with "data" array)
result = client.messages.list_scheduled
result["data"].each { |msg| puts "#{msg['id']}: #{msg['scheduledAt']}" }

# Get a specific scheduled message
msg = client.messages.get_scheduled("sched_xxx")

# Cancel a scheduled message (refunds credits)
result = client.messages.cancel_scheduled("sched_xxx")
puts "Refunded: #{result['creditsRefunded']} credits"
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

puts batch["batchId"]
puts "Queued: #{batch['queued']}"
puts "Failed: #{batch['failed']}"
puts "Credits used: #{batch['creditsUsed']}"

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
puts "Credits needed: #{preview['creditsNeeded']}"
puts "Will send: #{preview['willSend']}, Blocked: #{preview['blocked']}"
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

### Group MMS

Send one MMS to 2-8 US/Canada recipients who all share a single thread —
replies fan out to every participant. Group messaging is an A2P 10DLC
capability, so the sending number must be an MMS-enabled, 10DLC-registered
number you own. Omit `from` to use your workspace's default sender. Requires
the `group_mms` feature (and `enable_mms` when sending media).

```ruby
group = client.messages.send_group(
  to: ["+14155551234", "+14155555678"],
  text: "Hey team - quick sync at noon?"
)

puts group.id                # => "msg_abc123"
puts group.group_message_id  # => "grp_..." (present on live sends)
puts group.status            # => "sent" (or "delivered" when simulated)
puts group.simulated?        # => true on test keys / before verification

# With media instead of (or in addition to) text
client.messages.send_group(
  to: ["+14155551234", "+14155555678"],
  media_urls: ["https://cdn.example.com/flyer.jpg"],
  message_type: "marketing"
)
```

Billed per recipient. US/Canada destinations only.

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

Every POST carries an automatically generated `Idempotency-Key` header, held
across the client's own rate-limit retries, so a retry of a request that
already reached the API returns the original result instead of sending and
charging again. Pass your own key (1-255 printable ASCII characters) when the
guarantee needs to outlive the process, such as a job queue that re-runs after
a crash or your own retry loop; `idempotency_key:` is accepted on
`messages.send`, `send_group`, `schedule`, and `send_batch`.

```ruby
message = client.messages.send(
  to: "+15551234567",
  text: "Your order has shipped!",
  idempotency_key: "order-4821-shipped"
)
```

Repeating a request with the same key within 24 hours returns the original
response; `send_batch` sends no automatic key, because the API already
deduplicates identical batches by their contents. Note this client raises
`Sendly::TimeoutError` instead of retrying a timeout, so a timeout is exactly
when to retry with your own key.

Full details: https://sendly.live/docs/idempotency

## Webhooks

### Managing endpoints

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
message — `rcs_*`, `whatsapp_*`, `call.*`, `brand.*`, `campaign.*`,
`assignment.*`, `number.*`, `port*`, `contact*`, `conversation.*` and
`draft.*`, whose payloads are not message-shaped. `verification.*` events get
`event.verification`, a `Sendly::WebhookVerificationData`. `event.data` is the
typed view where one exists and a plain `Sendly::WebhookObject` otherwise, so
reading `data.object` works the same way for all of them, including an event
type this SDK predates.

Note that `contact.auto_flagged` carries the contact under `id` and the message
that failed under `message_id`; read the message with
`event.data[:message_id]`.

### Handling a lifecycle event

Only `message.*` events carry a message. A lifecycle event — `rcs_*`,
`whatsapp_*`, `call.*`, `brand.*`, `campaign.*`, `assignment.*`, `number.*`,
`port*`, `contact*`, `conversation.*`, `draft.*` — carries a different object,
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
# Get account information
account = client.account.get
puts account.email

# Check credit balance
credits = client.account.credits
puts "Available: #{credits['availableBalance']} credits"
puts "Reserved: #{credits['reservedBalance']} credits"
puts "Total: #{credits['balance']} credits"

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

# Create a new API key
result = client.account.create_api_key('Production Key')
puts "New key: #{result['key']}"  # Only shown once!

# Rotate an API key. Issues a new key and keeps the old one valid for a grace
# period (default 24h; 24-168 allowed) so you can deploy before the old expires.
rotation = client.account.rotate_api_key('key_xxx', grace_period_hours: 72)
puts "New key: #{rotation['newKey']['key']}"  # Only shown once!
puts rotation['message']                      # "Old key will expire in 72 hours"

# Revoke an API key
client.account.revoke_api_key('key_xxx')
```

## Contacts

Manage your contact directory. `list` returns a Hash with a `:contacts` array
of `Contact` objects plus pagination fields.

```ruby
# Create a contact
contact = client.contacts.create(
  phone_number: "+15551234567",
  name: "Alice Example",
  email: "alice@example.com",
  metadata: { plan: "pro" }
)

# List / search (scope to a list with list_id:)
result = client.contacts.list(limit: 50, search: "alice")
result[:contacts].each { |c| puts "#{c.name}: #{c.phone_number}" }
puts result[:total]

# Get, update, delete
c = client.contacts.get(contact.id)
client.contacts.update(contact.id, name: "Alice E.")
client.contacts.delete(contact.id)

# A contact's helper flags
puts c.opted_out?  # excluded from marketing sends
puts c.invalid?    # auto-flagged as unreachable (landline / bad number)

# Bulk import (dedupes by phone; each entry is a Hash)
report = client.contacts.import_contacts(
  [
    { phone: "+15551234567", name: "Alice" },
    { phone: "+15559876543", name: "Bob", email: "bob@example.com" }
  ],
  list_id: "list_abc"
)
puts "Imported #{report[:imported]}, skipped #{report[:skipped_duplicates]}"

# Clear the auto-invalid flag (single or bulk)
client.contacts.mark_valid(contact.id)
client.contacts.bulk_mark_valid(list_id: "list_abc")

# Trigger a carrier line-type lookup (async; landlines get excluded)
client.contacts.check_numbers(list_id: "list_abc", force: false)
```

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

Send a message to one or more contact lists as a single campaign.

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

# Send now, or schedule for later
client.campaigns.send_campaign(campaign.id)
client.campaigns.schedule(campaign.id, scheduled_at: "2025-06-01T15:00:00Z", timezone: "America/New_York")

# List, update, cancel, clone, delete
client.campaigns.list(status: "sent")[:campaigns].each { |c| puts "#{c.name}: #{c.status}" }
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

# Update (drafts only), publish, delete
client.templates.update(template.id, text: "Hi {{name}}, your order is on the way!")
client.templates.publish(template.id)
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

# Reply in a thread
client.conversations.reply("conv_abc", text: "Thanks for reaching out!")

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
  conditions: { keyword: "STOP" },
  actions: { add_label: "opted-out" },
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
verification = client.verify.send(to: "+15551234567", app_name: "Acme")
puts verification.id

# Check the code the user entered
result = client.verify.check(verification.id, code: "123456")
puts result.verified?

# Resend, fetch, and list
client.verify.resend(verification.id)
client.verify.get(verification.id)
client.verify.list(status: "verified")[:verifications].each { |v| puts v.phone }

# Hosted verification session (returns a URL to send the user to)
session = client.verify.sessions.create(
  success_url: "https://example.com/verified",
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
client.messages.send(to: "+15551234567", text: "Check this out!", media_urls: [media.url])
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
  # Hand the user the hosted page + code, wait for them to finish, then
  # re-call buy with the SAME arguments plus the completed action's code.
  puts "Visit #{purchase.action_url} and enter code #{purchase.action_code}"
  # ...after the action completes:
  # client.numbers.buy(..., action_code: purchase.action_code)
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
  puts approved.status            # "pending" -> "active"
  puts approved.throughput&.tier  # e.g. "Standard"

  # 3. Assign a number you own — it can send once the assignment is Active
  assignment = client.ten_dlc.assign_number(campaign.id, phone_number: '+15551234567')
  puts assignment.status  # "Under review" -> "Active"
end

# List everything
client.ten_dlc.list_brands[:brands].each { |b| puts "#{b.legal_name} — #{b.status}" }
client.ten_dlc.list_campaigns[:campaigns].each { |c| puts "#{c.use_case} — #{c.status}" }
client.ten_dlc.list_assignments[:assignments].each { |a| puts "#{a.phone_number} — #{a.status}" }
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
link = client.links.create(url: "https://example.com/spring-sale?utm_source=sms")
puts link.short_url        # => "https://sendly.live/l/Ab3xY7"
puts link.code             # => "Ab3xY7"
puts link.destination_url  # => "https://example.com/spring-sale?utm_source=sms"

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
Connecting is a one-time $19 setup (no monthly fee) and always ends with a
human step: the signup returns a connect URL a person must open in a
browser and log in with Facebook to link their WhatsApp Business Account.

Free-form text and media only deliver inside a 24-hour customer-service
window (opened by the recipient messaging you); an approved template works
anytime. Templates are reviewed by Meta (typically 24-48h) and categorized
as authentication, utility, or marketing — pricing follows the category and
destination country. Note: Meta has paused marketing template delivery to
US (+1) numbers.

```ruby
# 1. Connect a number ($19 one-time; a human must open the connect URL)
signup = client.whatsapp.signup.create(phone_number: "+15559876543")
puts "Have your user open: #{signup.connect_url}"

# 2. Poll until active
status = client.whatsapp.signup.get(signup.id)
puts status.failure_reasons if status.failed?

# List your connected senders
client.whatsapp.senders.list[:senders].each do |s|
  puts "#{s.phone_number} (#{s.display_name || 'no name yet'}) — #{s.status}"
end

# Read and update a sender's business profile (what recipients see when
# they open your details in WhatsApp)
profile = client.whatsapp.senders.get_profile("+15559876543")
puts profile.display_name
puts profile.about

client.whatsapp.senders.update_profile(
  "+15559876543",
  about: "Fresh roasted coffee, delivered.",               # max 139 chars
  description: "Small-batch roaster shipping nationwide.", # max 512 chars
  website: "https://acme.example"
)

# 3. Create a template (Meta reviews it, usually 24-48h)
template = client.whatsapp.templates.create(
  sender: "+15559876543",
  name: "order_shipped",
  language: "en_US",
  category: "UTILITY",
  body: "Hi {{1}}, your order {{2}} has shipped!",
  examples: { "1" => "Sam", "2" => "#4821" }
)
puts template.status  # "PENDING"

# List, edit-and-resubmit (the recovery path for rejections), or delete
client.whatsapp.templates.list[:templates].each { |t| puts "#{t.name} — #{t.status}" }
client.whatsapp.templates.update(template.id, body: "Hi {{1}}, order {{2}} is on its way!",
                                              examples: { "1" => "Sam", "2" => "#4821" })
client.whatsapp.templates.delete(template.id)

# 4. Send — free-form inside an open 24h window, template anytime
window = client.whatsapp.window(from: "+15559876543", to: "+15551234567")
if window.open?
  client.messages.send(
    channel: "whatsapp",
    to: "+15551234567",
    from: "+15559876543",
    text: "Your table is ready!"
  )
else
  message = client.messages.send(
    channel: "whatsapp",
    to: "+15551234567",
    from: "+15559876543",
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
  to: "+15551234567",
  from: "+15559876543",
  text: "Here is your receipt",
  media_urls: ["https://example.com/receipt.pdf"]
)
```

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
             phone_number: "+15551234567" }
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
    phone_number: { number: "+15551234567", label: "Support" }
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
  { phone_number: "+15557654321", label: "Sam's Pixel" }
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
capability = client.rcs.capability(to: "+15551234567")
puts capability.capable? ? "RCS" : "would fall back to SMS"

# Text with suggested replies and actions. Nested suggestion and card
# hashes are passed through verbatim, so they use the camelCase keys the
# API expects.
message = client.messages.send(
  channel: "rcs",
  to: "+15551234567",
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
  to: "+15551234567",
  card: {
    title: "Spring collection",
    description: "New arrivals are in - take a look.",
    mediaUrl: "https://example.com/spring.jpg", # public JPEG, PNG, or GIF
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
  to: "+15551234567",
  text: "RCS or nothing",
  fallback_to_sms: false
)
```

## Voice Calls

Place phone calls that one of your AI agents handles, list and inspect
calls, end a call early, and download recordings. Agents are configured in
the dashboard under Calls, then Agents; the number you call from must have
voice switched on there (Calls, then Settings) and an emergency address
registered before it can place outbound calls. Each `Sendly::PhoneNumber`
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
> for yours, every call method raises `Sendly::NotFoundError`
> (`voice_not_enabled`).

```ruby
# Place a call. Returns at once with the call ringing; the agent greets the
# callee when they answer and uses `context` for this call only.
call = client.calls.create(
  to: "+15555550123",
  agent_id: "3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b",
  from: "+15555550188",                # optional when you have one voice number
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
# the recording is ready. Ogg/Opus, dual channel on agent calls.
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
`agent_required`, `invalid_metadata` and `from_number_required`;
`Sendly::RateLimitError` for `daily_call_limit`; `Sendly::APIError` with
`status_code` 428 for `e911_required` (register an emergency address for the
number), 409 for `agent_disabled`, `no_voice_number` and `lines_busy` (retry
shortly), or 403 for `live_key_required` and a key missing the scope; and
`Sendly::ServerError` (a sibling of `APIError`, not a subclass) for 503
`voice_unavailable` / `agents_unavailable` and 500 `voice_internal_error`.
The full list is `Sendly::Call::ERROR_CODES`; the hangup vocabulary is
`Sendly::Call::HANGUP_CLASSES`.

`call.started`, `call.completed` and `call.recording.ready` webhooks carry
the same object in snake_case (`handled_by`, `hangup_class`, `billing`,
`metadata`, ...); `Sendly::Call.new(event.raw_object)` reads it.

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
| Domestic | US, CA | 2 |
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

## Enterprise

The Enterprise API lets you programmatically manage workspaces, verification, credits, and API keys for multi-tenant platforms. Requires an enterprise master key (`sk_live_v1_master_*`).

### Quick Provision

Create a fully configured workspace in a single call:

```ruby
client = Sendly::Client.new(api_key: "sk_live_v1_master_YOUR_KEY")

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

key = client.enterprise.workspaces.create_key("ws_xxx",
  name: "Production", type: "live")
puts key["key"]

client.enterprise.workspaces.revoke_key("ws_xxx", "key_abc")
```

### Webhooks & Analytics

```ruby
client.enterprise.webhooks.set(url: "https://yourapp.com/webhooks")
overview = client.enterprise.analytics.overview
messages = client.enterprise.analytics.messages(period: "30d")
delivery = client.enterprise.analytics.delivery
```

Full enterprise docs: [sendly.live/docs/enterprise](https://sendly.live/docs/enterprise)

---

## Requirements

- Ruby 3.0+

The client is built on Ruby's standard-library `net/http` and does not use Faraday at runtime. The gemspec still declares `faraday` and `faraday-retry` so this release does not drop a runtime dependency that callers may be resolving transitively. Both are unused and are slated for removal in the next major version.

## License

MIT
