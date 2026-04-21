# sendly (Ruby)

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
