# sendly (Ruby)

## 4.1.0

### Minor Changes

- **Voice calls: `client.calls`.** Place phone calls handled by your AI agents, list and inspect them, end one early and fetch recordings, over the new `/api/v1/calls` routes. `create(to:, agent_id:, from: nil, context: nil, metadata: nil)` returns a `Sendly::Call` that is `ringing`; `list` takes `limit:`, `offset:`, `status:`, `direction:`, `kind:`, `agent_id:`, `to:` and `from:` and returns an Enumerable `Sendly::CallList` with `total`, `limit`, `offset` and `has_more?`; `get(id)` adds the `transcript` (an array of `Sendly::CallTranscriptLine`) on agent-handled calls and leaves it `nil` otherwise; `hangup(id)` cancels a ringing call or completes an active one and returns an already-ended call unchanged; `recording(id)` returns a `Sendly::CallRecording` whose signed `url` is set only while `ready?` and expires after five minutes. `create` and `hangup` send the client's usual `Idempotency-Key` and accept `idempotency_key:`. `Sendly::Call` also reads the snake_case object carried by the `call.started`, `call.completed` and `call.recording.ready` webhooks, including the new `billing` and `metadata` keys. Vocabularies are published as `Sendly::Call::STATUSES`, `::HANGUP_CLASSES` and `::ERROR_CODES`. `Sendly::PhoneNumber` gains `voice_enabled` (with `voice_enabled?`), `voice_mode` (`Sendly::PhoneNumber::VOICE_MODES`) and `raw`, so `client.numbers.list` can pick the `from` number for a call. Reads need the `calls:read` scope; writes need `calls:write` and a live key. Voice is enabled workspace by workspace: until it is on for yours the routes answer 404 `voice_not_enabled`, which raises `Sendly::NotFoundError`.

  ```ruby
  call = client.calls.create(
    to: "+15555550123",
    agent_id: "3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b",
    context: "Confirm the 3pm appointment on Tuesday."
  )
  call = client.calls.get(call.id)
  call.transcript&.each { |line| puts "#{line.speaker}: #{line.text}" }
  ```

## 4.0.0

**Upgrading from 3.40.0:** that release already contained the breaking changes below, published by mistake as a minor version. 4.0.0 carries them under the correct major. Relative to 3.40.0, the only new changes are under **Security**.

### Breaking Changes

- **A webhook that is not a message is no longer presented as one.** `parse_event` built a `Sendly::WebhookMessageData` out of every `data.object`, whatever the event was. For an `rcs_*`, `whatsapp_*`, `call.*`, `brand.*`, `campaign.*`, `assignment.*`, `number.*`, `port*`, `contact*`, `conversation.*` or `draft.*` payload that dropped every field the event actually carried — `agent_id`, `stage`, `port_request_id`, `duration_secs` and the rest were unreachable — and filled the gaps with message fields that were never sent. `event.data` is now a `Sendly::WebhookObject`, a hash-like view of `data.object`: read a key with `[]` (String or Symbol), a reader method of the same name, or `to_h`. `event.message` is the message view and is `nil` for all of the above; `message.*` events are unchanged, and `event.data` is still the `WebhookMessageData` there.

  ```ruby
  # before — "" for every RCS event, and the agent was unreachable
  event.data.from
  # after
  event.data[:agent_id]   # => "bb22cc33-..."
  event.message           # => nil
  ```

- **Absent fields are `nil` instead of a plausible-looking default.** `WebhookMessageData` defaulted `segments` to `1`, `credits_used` to `0`, `direction` to `"outbound"`, `from` to `""` and `id` to `""`, none of which a handler could tell from a real value. They are now `nil` when the payload did not carry them, and `data.key?(:segments)` says which case you are in. `WebhookVerificationData` loses the same kind of defaults (`delivery_status` `"queued"`, `attempts` `0`, `max_attempts` `3`), though nothing could reach that class before this release.

- **JSON `null` survives as `nil`.** `from` and `to` on a `call.*` event are `null` for every in-app call; `from` used to arrive as `""`. Code branching on `from.empty?` should branch on `nil` now.

- **`event.data.to_h` returns `data.object` as it arrived.** It used to return a compacted subset of the typed message fields, which dropped `text`, `metadata`, `media_urls`, `message_format` and `organization_id`, renamed `message_id` to `id`, and emitted the invented `segments`/`credits_used` defaults. `event.to_h[:data]` is the same hash. For a current-shape payload the familiar keys are all still there.

- **`id` is no longer filled from an unrelated `id` key.** `contact.auto_flagged` carries the contact under `id` and the message that failed under `message_id`, so `event.data.message_id` returned the *contact* id — a handler that marked that message failed acted on the wrong row. Contact events have no message view at all now; read the message with `event.data[:message_id]`.

### Migrating from 3.x

Nothing outside webhook handling changed. The client, every resource and every
`message.*` handler you already have keep working as written; the list below is
the whole edit.

**1. Reading a message field off a lifecycle event now raises.** 3.x decoded
every `data.object` into a `Sendly::WebhookMessageData`, so an `rcs_agent.live`
handler that asked for `event.data.from` was handed `""`, `event.data.segments`
`1` and `event.data.credits_used` `0` — values the event never carried, not
distinguishable from real ones, and no error was raised. The same calls raise
`NoMethodError` in 4.0, naming the keys that did arrive. That failure is the
point of this release rather than an accident of it: the value it replaces was
wrong, and silently so.

```ruby
# 3.x — silently wrong, on every RCS event
event.data.from       # => ""
event.data.segments   # => 1

# 4.0 — the same call
event.data.from
# => NoMethodError: undefined method 'from' for Sendly::WebhookObject:
#    this event's data.object carries agent_id, name, stage, organization_id

# 4.0 — the edit: read the object the event actually carries
event.data[:agent_id]   # => "bb22cc33-dd44-4e55-9f66-001122334455"
event.data.stage        # => "live"
event.raw_object        # => the whole data.object Hash, untouched
```

**2. `event.data` is a message view only on `message.*` events.** In 3.x it was
a `WebhookMessageData` whatever the event was, so `event.data.id` and
`event.data.status` answered for anything — with the payload's value when the
key happened to exist, and with `''` or `nil` when it did not. In 4.0 a
lifecycle event's `event.data` is a `Sendly::WebhookObject`: the keys the
payload carried are readable and nothing else is. `event.message` is new in 4.0
and is the message view; it is `nil` outside `message.*`, so guard it with
`event.message?` rather than calling into it unconditionally.

```ruby
# 3.x — answered for every event type; "" when the payload had no id
mark_delivered(event.data.id)

# 4.0 — split the branches
case event.type
when Sendly::Webhooks::EVENT_MESSAGE_DELIVERED
  mark_delivered(event.message.id)         # same value as 3.x
when Sendly::Webhooks::EVENT_NUMBER_ACTIVATED
  number_active(event.data[:id])           # the number's id, as it always was
when Sendly::Webhooks::EVENT_RCS_AGENT_LIVE
  agent_went_live(event.data[:agent_id])   # unreachable in 3.x
end
```

**3. `contact.auto_flagged` no longer reports the contact as the message.** The
payload carries the contact under `id` and the message that failed under
`message_id`; 3.x filled the message view's `id` from the contact, so a handler
that marked "the message" failed acted on the wrong record.

```ruby
# 3.x — the CONTACT id, presented as a message id
event.data.message_id    # => "ct_9"

# 4.0
event.data[:id]          # => "ct_9"    the contact
event.data[:message_id]  # => "msg_77"  the message that failed
event.message            # => nil
```

**4. Message fields the payload omitted are `nil`, not a default.** On a
`message.*` event the readers still exist, so this raises nothing — it changes
what you get. `key?` separates "absent" from "arrived as null".

```ruby
# message.delivered, on a payload that carried no segments
event.data.segments          # 3.x => 1           4.0 => nil
event.data.credits_used      # 3.x => 0           4.0 => nil
event.data.direction         # 3.x => "outbound"  4.0 => nil
event.data.key?(:segments)   # => false when absent, true when it arrived as null
```

**5. `event.data.to_h` is now `data.object` as it arrived.** It used to be a
compacted subset of the typed message fields, dropping `text`, `metadata`,
`media_urls`, `message_format` and `organization_id` and renaming `message_id`
to `id`. Code that persisted `to_h` will start seeing the full object.

```ruby
event.data.to_h == event.raw_object   # => true, for every event type
```

**6. If you want a typed object for a lifecycle event, ask for one.**
`#object_as` fills a Struct or Data class from the members it declares and
ignores the rest of the payload, so a field added to the event later cannot
break the call.

```ruby
AgentLive = Struct.new(:agent_id, :name, :stage)
agent = event.object_as(AgentLive)
agent.stage   # => "live"
```

### Deprecations

- **`Sendly::Webhooks::EVENT_MESSAGE_QUEUED` is deprecated.** The API has never
  emitted `message.queued`, and subscribing to it fails: `client.webhooks.create`
  and `client.webhooks.update` reject any event outside the API's list with a
  400, raised here as `Sendly::ValidationError`. The constant stays exported in
  4.0 so existing code still loads, and will be removed in the next major.
  `message.undelivered` is rejected on subscribe the same way and has never had
  a constant in this SDK. Subscribe to `message.sent`, `message.failed` and
  `message.bounced` instead. Every other `EVENT_*` constant matches the API's
  list exactly.

### Minor Changes

- **`Sendly::WebhookEvent#raw_object`** carries `data.object` exactly as it arrived, for every event type, and **`#object_as(klass)`** reads it as a type of your choosing (`event.object_as(AgentLive)`). `#object` is an alias for `raw_object`.

- **`Sendly::WebhookVerificationData` is reachable.** Nothing ever constructed it, and it read String keys while `parse_event` symbolizes names, so it could not have worked if anything had. `verification.*` events now build one, as `event.verification` and `event.data`, and every reader takes String or Symbol keys.

- **`Sendly::WebhookEvent` gains `#message?` and `#verification?`** for the two cases that have a typed view.

- **`Sendly::ValidationError#field_errors` is now populated.** It was always `nil` before, because the API path never passed it. It now carries the response body's `errors` array on any 400 or 422, on every resource rather than just RCS: `client.contacts.import` already returns one, for example. Each entry is a Hash. Code that treats a truthy `field_errors` as "this only happens for X" should be rechecked.


- **RCS agent registration is self-serve from the SDK.** `client.rcs` gains `registration.get`, `dossier.get`, `brands.create` / `brands.update`, and `agents.create` / `get` / `update` / `set_test_devices` / `submit` / `request_launch`, mirroring the dashboard: draft the brand and agent, submit them for Sendly's review, invite test devices once the agent is in testing, then request launch. Reads need the `rcs:read` scope and writes `rcs:write`; test and live keys both work. Nested hashes (address, contact, basics, campaign, testing) accept snake_case or camelCase keys. Logo, hero and call-to-action media must be public `https://` URLs; assets cannot be uploaded over the API. New models: `Sendly::RcsRegistration` (with `CUSTOMER_STAGES`, `REVIEW_STATUSES` and `ERROR_CODES`), `Sendly::RcsDossier`, `Sendly::RcsBrand`, `Sendly::RcsAddress`, `Sendly::RcsContact`, `Sendly::RcsAgentRegistration`, `Sendly::RcsAgentBasics`, `Sendly::RcsAgentCampaign`, `Sendly::RcsCampaignInteraction`, `Sendly::RcsConsentSettings`, `Sendly::RcsOptInMethod`, `Sendly::RcsAgentTesting` and `Sendly::RcsTestDevice`. `Sendly::RcsAgent` (from `agents.list`) gains `stage`. Every route stays behind the RCS rollout: while it is off for your account these calls raise `Sendly::NotFoundError` with `rcs_not_enabled`.

  ```ruby
  dossier = client.rcs.dossier.get
  brand = client.rcs.brands.create(**dossier.brand)
  agent = client.rcs.agents.create(brand_id: brand.id, display_name: "Acme Coffee",
                                   use_case: "MULTI_USE",
                                   basics: { logo_url: "https://acme.example/rcs/logo.png" })
  client.rcs.agents.submit(agent.id, idempotency_key: "rcs-submit-#{agent.id}")
  ```

- **`client.patch` and `client.put` accept `idempotency_key:`.** Neither generates a key on its own (unchanged), but a key you pass is now sent, so the RCS `update` and `set_test_devices` calls can be replayed safely.

- **`Sendly::ValidationError#field_errors` carries the API's `errors` list** (`[{ "path", "message" }, ...]`) when a 400 or 422 response includes one, instead of always being `nil`. RCS registration uses it to say which brand, agent, campaign or device field needs attention.


### Security

- **Path parameters are percent-encoded.** Every id you pass is now encoded (`URI.encode_www_form_component`) before it goes into the request path. An id containing `/`, `?` or `#` used to change which endpoint the request reached: an id of `../../account/keys` left its collection and hit another endpoint carrying your API key. Ordinary ids are sent byte-for-byte as before.

## 3.38.0

### Minor Changes

- **Every `POST` now sends an `Idempotency-Key` header.** The client generates one key per logical request (`sendly-ruby-retry-<uuid>`) and holds it across its own retries, so a request that already reached the server before a rate-limit retry is recognised as a repeat instead of being executed a second time. The server records a key only once the first attempt has finished, so this narrows the duplicate-send window rather than closing it: a retry that fires while the original is still running is not seen as a repeat. No code change is needed to get this. To extend the same protection across process restarts or your own retry loop, supply the key yourself:

  ```ruby
  client.messages.send(
    to: "+15551234567",
    text: "Your order shipped",
    idempotency_key: "order-4821-shipped"
  )
  ```

  Repeating a request with the same key inside 24 hours returns the original response instead of sending again. `idempotency_key:` is accepted on `messages.send` (the SMS, WhatsApp and RCS branches alike), `messages.send_group`, `messages.schedule`, `messages.send_batch`, and on `client.post` for any call you assemble by hand. A key must be 1 to 255 printable ASCII characters. Surrounding whitespace is trimmed, an empty or whitespace-only key is treated as if you passed nothing, and anything else raises `Sendly::ValidationError` before a request leaves the process.

- **How keys behave across retries.** On a rate-limit retry the same key is reused. On a 5xx retry an auto-generated key is swapped for a fresh one, because the server responded, so the outcome is known and the retry should be a fresh attempt rather than a repeat of the failed one. The server does not record a 5xx against a key either. A key you supplied is never swapped, which is the whole point of supplying one. `messages.send_batch` is the deliberate exception: it sends no auto-generated key, because the batch endpoint already dedupes header-less retries by hashing the send itself and an auto key would step around that safety net. A key you pass to `send_batch` yourself is still sent. Worth knowing: this client raises `Sendly::TimeoutError` on a timeout rather than retrying, so a timeout is exactly the case where you should pass your own `idempotency_key:` before retrying by hand.

- **Multipart uploads carry a key as well.** `media.upload`, the enterprise verification-document upload, and `business_upgrade.start` / `business_upgrade.resubmit` now attach an auto-generated `Idempotency-Key` to their uploads, so a retried document upload is far less likely to land twice. These methods generate the key internally and do not take an `idempotency_key:` argument yet.

- **Templates were addressing a path the API does not serve. They now work.** Every method on `client.templates` other than `generate` pointed at `/verify/templates...`, which is not registered at any version of the API, so `list`, `get`, `create`, `update`, `delete` and `publish` could only ever raise `Sendly::NotFoundError`. They now address `/api/v1/templates`, which is served, and have been exercised end to end against production. If you wrote code against this resource and concluded it was broken, note carefully that it is live now: calls that previously failed without side effects will really create, edit, publish and delete templates.

- **`Sendly::Template` now mirrors what the API actually returns**, and templates have a draft/published lifecycle. The response body field is `text`, not `body`, and a template carries `status` (`"draft"` or `"published"`, see the new `Sendly::Template::STATUSES`), `version`, `published_at`, `is_preset` and `preset_slug`. New templates are always created as drafts; call `publish` to make one usable. Only drafts can be edited, so an `update` on a published template is rejected by the API, and preset templates cannot be edited at all.

  ```ruby
  t = client.templates.create(name: "Order shipped", text: "Hi {{name}}, order {{order_id}} has shipped!")
  t.status          # => "draft"
  client.templates.publish(t.id)
  client.templates.list[:templates].each { |x| puts "#{x.name}: #{x.status}" }
  ```

- **Template members that disappeared in the reshape are back, and deprecated.** If your editor or `ruby -w` starts pointing at these, this is why:
  - `Template#body` is an alias of `#text`. Use `#text`.
  - `Template#type` is derived from `#is_preset` and still returns `"preset"` or `"custom"`. Use `#is_preset` or `#preset?`. `Template::TYPES` is kept for the same reason.
  - `Template#is_published` is derived from `#status`. Use `#status` or `#published?`.
  - `Template#locale` is **always `nil`** and `Template#is_default` is **always `false`**. These are not deprecated in favour of anything: templates are not scoped by locale and the API has no concept of a default template, so it returns no such fields. There is no replacement. Keep per-locale wording in separate templates.

  `Template#to_h` includes all of the above alongside the current fields, so hashes built from it keep their old keys.

- **Deprecated template keyword arguments now raise instead of lying.** `templates.list` accepts `limit:`, `type:` and `locale:` again, and `templates.create` / `templates.update` accept `body:`, `locale:` and `is_published:` again, but the ones the API cannot honour raise `ArgumentError` with an explanation rather than silently doing nothing:
  - `list(limit:)` and `list(type:)` raise: the list route returns every visible template in one response and neither paginates nor filters. Slice the returned array, or select over it with `Template#preset?` / `#custom?`. `list` still returns a `:pagination` key so existing destructuring does not blow up, but it is always `nil`.
  - `locale:` raises everywhere it is accepted.
  - `create(is_published: true)` and `update(is_published: true)` raise, and point you at `publish(id)`. `is_published: false` is accepted as a no-op, since templates are created as drafts and an update never changes status.
  - `body:` on `create` and `update` is accepted and sent as `text`. Prefer `text:`.

- **API key management was pointed at routes that do not exist.** `account.api_keys`, `account.api_key(id)` and `account.api_key_usage(id)` requested `/keys...`, which the versioned API does not serve, so they returned 404 no matter what. They now use `/account/keys...`. `account.api_keys` also unwraps the `keys` envelope the API returns, which it previously did not, so it now gives you the `Sendly::ApiKey` array its signature always promised.

- **`account.revoke_api_key` could never revoke anything.** It sent `DELETE /account/keys/:id`, and that path is registered for `GET` only, so every revocation failed. It now sends `PATCH /account/keys/:id/revoke`, which is the verb the server accepts, takes an optional `reason:` recorded on the key's audit trail, and returns the `{ "id", "name", "revoked", "revokedAt" }` hash from the API instead of nothing. Treat this as live: code that has been calling it fruitlessly will now actually revoke keys.

  ```ruby
  client.account.revoke_api_key("key_abc123", reason: "rotated")
  ```

- **`account.transactions` raised `TypeError` on every call.** The endpoint returns `{ "transactions": [...] }` and the SDK mapped over that hash directly, so it tried to index an array with a string and blew up before you saw any data. It now unwraps the envelope and returns `Sendly::CreditTransaction` objects, or an empty array for an account with no history. One caveat: `offset:` is still accepted by the method but the endpoint ignores it, so it has no effect. `limit:` works and the server caps it at 100 (50 when omitted).

- **Not fixed, so you are not left hunting:** `templates.unpublish` and `templates.clone` now address `/api/v1/templates/:id/unpublish` and `/api/v1/templates/:id/clone`, but the versioned API serves neither route, so both still fail with a 404. Their docs say so. To retire a published template today, create and publish a replacement and delete the old one; to copy one, read it with `get` and pass its `text` to `create`. Separately, `account.create_api_key` still fails with a 400: the API requires a `type` of `"test"` or `"live"` and the SDK does not send one. Mint keys from the dashboard until that is fixed.

### Patch Changes

- **`faraday` and `faraday-retry` are deprecated dependencies.** The client is built on Ruby's standard-library `net/http` and has not used Faraday at runtime for some time. Both gems stay declared in the gemspec so that this minor release does not pull a dependency out from under anyone resolving it transitively, but they are unused and are slated for removal in the next major version. The README no longer lists Faraday as a requirement.
- The gem's packaged file list is now an explicit manifest plus `lib/**/*.rb` and `examples/**/*.rb`, rather than a `git ls-files` shell-out. The contents are unchanged, but building the gem from a source tree that is not a git checkout now produces the same gem instead of an empty one.

## 3.33.0

### Minor Changes

- New `client.conversations.suggest_replies(id)` method — `POST /api/v1/conversations/:id/suggest-replies`. Returns AI-generated reply suggestions for a conversation based on its recent message history, mirroring the Node SDK's `conversations.suggestReplies()` and the equivalent methods on the other Sendly SDKs (closes a feature parity gap). Returns a `Sendly::SuggestRepliesResponse`, which is `Enumerable` over its `SuggestedReply` entries and also exposes `#suggestions`, `#based_on_message_id`, and `#model`.

  ```ruby
  client = Sendly::Client.new("sk_live_v1_xxx")

  result = client.conversations.suggest_replies("conv_abc123")
  result.suggestions.each do |reply|
    puts "[#{reply.tone}] #{reply.text}"
  end
  ```

## 3.32.0

### Minor Changes

- New `business_upgrade` resource for the toll-free entity-upgrade ("fork-with-new-number") flow. When a customer forms a new legal entity (e.g. an LLC), this resource lets them reserve a new toll-free number under the new entity, submit it for carrier review, and atomically swap to it on approval — without disrupting outbound SMS during the 1-2 week review window. Mirrors the Node SDK's `businessUpgrade` resource at parity.

  ```ruby
  client = Sendly::Client.new("sk_live_v1_xxx")

  # Validate before submitting (no writes)
  preview = client.business_upgrade.preflight(
    business_name: "Acme Holdings LLC",
    brn: "12-3456789",
    brn_type: "EIN",
    brn_country: "US",
    entity_type: "PRIVATE_PROFIT"
  )

  # Best-of prefill across all the caller's verified workspaces
  prefill = client.business_upgrade.best_prefill

  # Submit the upgrade with the IRS letter (multipart upload)
  result = client.business_upgrade.start(
    "ws_abc",
    business_name: "Acme Holdings LLC",
    brn: "12-3456789",
    brn_type: "EIN",
    brn_country: "US",
    entity_type: "PRIVATE_PROFIT",
    ein_doc_path: "./CP-575.pdf"
  )

  # Status, cancel, resubmit, set old-number disposition
  client.business_upgrade.status("ws_abc")
  client.business_upgrade.cancel("ws_abc")
  client.business_upgrade.resubmit("ws_abc", contact_email: "new@acme.com")
  client.business_upgrade.set_disposition("ws_abc", disposition: "released")
  client.business_upgrade.set_disposition("ws_abc", disposition: "moved", target_workspace_id: "ws_xyz")
  ```

  Methods: `preflight`, `best_prefill`, `start`, `status`, `cancel`, `resubmit`, `set_disposition`. EIN PDFs can be passed via `ein_doc_path:` (file path) or `ein_doc:` (raw bytes / IO).

## 3.31.0

### Patch Changes

- **`Sendly::Client.new` now accepts the API key positionally** in addition to as a keyword argument. Every code sample in our docs used positional, so `Sendly::Client.new("sk_live_...")` previously raised `ArgumentError: missing keyword: :api_key`. Both styles now work and produce identical clients:

  ```ruby
  # Positional (matches our docs)
  client = Sendly::Client.new("sk_live_v1_xxx")
  client = Sendly::Client.new("sk_live_v1_xxx", timeout: 60)

  # Keyword (existing v3.30.0 signature — unchanged)
  client = Sendly::Client.new(api_key: "sk_live_v1_xxx")
  ```

  Passing `api_key` both positionally and as a keyword raises `ArgumentError`; passing more than one positional argument also raises. Backward-compatible with all v3.30.0 callers.

## 3.30.0

### Minor Changes

- `enterprise.workspaces.submit_verification(workspace_id, **fields)`: rewritten to match the actual API shape (camelCase keys on the wire, nested `address`/`contact` hashes, `entity_type` + `brn`/`brn_type`/`brn_country` instead of `business_type`/`ein`). The previous shape didn't match the server endpoint — calls were always returning 400.
- **Partial-update friendly:** for resubmits on existing workspaces, send only the fields you want to change — everything else is filled from the existing record. Hosted page URLs (`/biz/`, `/opt-in/`, `/legal/`) generated during provision are auto-preserved.
- `enterprise.workspaces.resubmit_verification(workspace_id, **partial_updates)`: convenience alias for resubmits — same as `submit_verification` but reads more naturally for one-field-change use cases.
- All top-level keys are accepted as snake_case Ruby keyword arguments (`business_name`, `use_case`, `opt_in_workflow`, etc.) and transformed to the camelCase keys the API expects. Nested `address` and `contact` hashes are passed through verbatim and should already use camelCase keys (e.g. `firstName`, `lastName`).

### Server-side fixes paired with this release

- `/api/v1/enterprise/workspaces/:id/verification/submit` now returns specific missing-field errors (e.g. `"Missing required fields: website"`) instead of listing every required field whether present or not.
- Endpoint accepts both flat and `{ verification: {...} }` wrapped shapes (matches `/enterprise/provision`).
- `use_case` validation expanded from 23 entries to the full 43-value carrier use-case enum.

## 3.29.0

### Minor Changes

- `contacts.bulk_mark_valid(ids: ..., list_id: ...)`: clear the invalid flag on many contacts at once (up to 10,000 per call). Escape hatch for when auto-mark misclassifies at scale.
- Four new list-health webhook event constants in `Sendly::Webhooks`: `EVENT_CONTACT_AUTO_FLAGGED`, `EVENT_CONTACT_MARKED_VALID`, `EVENT_CONTACTS_LOOKUP_COMPLETED`, `EVENT_CONTACTS_BULK_MARKED_VALID`.
- New `Sendly::Webhooks::ListHealthEventSource` module with frozen constants (`SEND_FAILURE | CARRIER_LOOKUP | USER_ACTION | BULK_MARK_VALID`) for the `source` field on auto-flag and mark-valid webhooks.
- `Contact` gains `user_marked_valid_at` — when a user manually cleared an auto-flag. Carrier re-checks respect this timestamp and leave the contact clean.

## 3.28.0

### Minor Changes

- `contacts.mark_valid(id)`: clear the auto-exclusion flag on a contact.
- `contacts.check_numbers(list_id: nil, force: false)`: trigger a background carrier lookup.
- `Contact` gains `line_type`, `carrier_name`, `line_type_checked_at`, `invalid_reason`, `invalidated_at` plus `invalid?` helper.

## 3.18.1

### Patch Changes

- fix: webhook signature verification and payload parsing now match server implementation
  - `verify_signature()` accepts `timestamp:` keyword argument for HMAC on `timestamp.payload` format
  - `parse_event()` handles `data[:object]` nesting (with flat `data` fallback for backwards compat)
  - `WebhookEvent` adds `livemode` attr, `created` field, `created_at` alias
  - `WebhookMessageData` renamed `message_id` to `id` (with `message_id` method alias)
  - Added `direction`, `organization_id`, `text`, `message_format`, `media_urls` attrs
  - `generate_signature()` accepts `timestamp:` keyword argument
  - 5-minute timestamp tolerance check prevents replay attacks

## 3.18.0

### Minor Changes

- Add MMS support for US/CA domestic messaging

## 3.17.0

### Minor Changes

- Add structured error classification and automatic message retry
- New `error_code` field with 13 structured codes (E001-E013, E099)
- New `retry_count` field tracks retry attempts
- New `retrying` status and `message.retrying` webhook event

## 3.16.0

### Minor Changes

- Add `transfer_credits` for moving credits between workspaces

## 3.15.2

### Patch Changes

- Add metadata support to Message class

## 3.13.0

### Minor Changes

- Campaigns, Contacts & Contact Lists resources with full CRUD
- Template clone method
