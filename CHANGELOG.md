# sendly (Ruby)

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
- `use_case` validation expanded from 23 entries to the full 43-value Telnyx enum.

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
