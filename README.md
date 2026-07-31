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
credits = client.account.credits
puts "Available: #{credits['availableBalance']} credits"
puts "Reserved: #{credits['reservedBalance']} credits"
puts "Total: #{credits['balance']} credits"

# View credit transaction history
transactions = client.account.transactions
transactions.each do |tx|
  puts "#{tx['type']}: #{tx['amount']} credits - #{tx['description']}"
end

# List API keys
keys = client.account.api_keys
keys.each do |key|
  puts "#{key['name']}: #{key['prefix']}*** (#{key['type']})"
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
# Create / list / get
template = client.templates.create(
  name: "Order shipped",
  body: "Hi {{name}}, order #{{order_id}} has shipped!",
  is_published: true
)
client.templates.list(type: "custom")[:templates].each { |t| puts t.name }
t = client.templates.get(template.id)

# Update, publish/unpublish, clone
client.templates.update(template.id, body: "Hi {{name}}, your order is on the way!")
client.templates.publish(template.id)
client.templates.unpublish(template.id)
client.templates.clone(template.id, name: "Order shipped (copy)")
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
- Faraday 2.0+

## License

MIT
