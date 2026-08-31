# sendly (Ruby)

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
