# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Idempotency keys' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:messages) { client.messages }

  let(:auto_key_pattern) do
    /\Asendly-ruby-retry-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  end

  # Stubs method+path, records the Idempotency-Key header of every attempt
  # into the returned array, and replies with the given responses in order.
  def capture_keys(method, path, *responses)
    keys = []
    stub_request(method, "#{base_url}#{path}")
      .with { |req| keys << req.headers['Idempotency-Key'] }
      .to_return(*responses)
    keys
  end

  def ok(body)
    { status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def server_error(status = 500)
    { status: status, body: { message: 'Internal server error' }.to_json,
      headers: { 'Content-Type' => 'application/json' } }
  end

  before do
    # Skip the exponential backoff between retry attempts
    allow(client).to receive(:sleep)
  end

  describe 'automatic key generation' do
    it 'attaches an auto-generated key to POST requests' do
      keys = capture_keys(:post, '/messages', ok(message_response))

      messages.send(to: '+15551234567', text: 'Hello!')

      expect(keys.first).to match(auto_key_pattern)
      expect(keys.first.length).to be <= 255
    end

    it 'does not attach a key to GET requests' do
      keys = capture_keys(:get, '/messages?limit=10&offset=0', ok(message_list_response))

      messages.list(limit: 10)

      expect(keys.first).to be_nil
    end

    it 'does not attach a key to DELETE requests' do
      keys = capture_keys(:delete, '/messages/scheduled/sched_abc123',
                          ok('id' => 'sched_abc123', 'status' => 'cancelled', 'creditsRefunded' => 1))

      messages.cancel_scheduled('sched_abc123')

      expect(keys.first).to be_nil
    end

    it 'does not auto-attach a key to batch sends (server dedupes by content)' do
      keys = capture_keys(:post, '/messages/batch', ok(batch_response))

      messages.send_batch(messages: [{ to: '+15551234567', text: 'Hi!' }])

      expect(keys.first).to be_nil
    end

    it 'auto-attaches a key to media uploads' do
      keys = capture_keys(:post, '/media', ok('id' => 'med_x', 'url' => 'https://cdn.example/x.jpg'))

      client.media.upload(StringIO.new('fake-image-bytes'), filename: 'x.jpg', content_type: 'image/jpeg')

      expect(keys.first).to match(auto_key_pattern)
    end

    it 'generates a distinct key for each logical request' do
      keys = capture_keys(:post, '/messages', ok(message_response), ok(message_response))

      messages.send(to: '+15551234567', text: 'First')
      messages.send(to: '+15551234567', text: 'Second')

      expect(keys[0]).to match(auto_key_pattern)
      expect(keys[1]).to match(auto_key_pattern)
      expect(keys[0]).not_to eq(keys[1])
    end
  end

  describe 'retry behavior' do
    # This client retries only rate limits (429 with retryAfter) and 5xx
    # responses; timeouts and network errors raise without retrying, so the
    # reuse-across-timeout cases from other SDKs do not apply here.

    it 'reuses the same key when retrying a rate-limited request (non-5xx response)' do
      keys = capture_keys(:post, '/messages',
                          { status: 429, body: { message: 'Rate limited', retryAfter: 0.01 }.to_json },
                          ok(message_response))

      message = messages.send(to: '+15551234567', text: 'Hello!')

      expect(message.id).to eq('msg_abc123')
      expect(keys.length).to eq(2)
      expect(keys[0]).to eq(keys[1])
    end

    it 'rotates the auto-generated key when retrying after a 5xx response' do
      keys = capture_keys(:post, '/messages', server_error, ok(message_response))

      message = messages.send(to: '+15551234567', text: 'Hello!')

      expect(message.id).to eq('msg_abc123')
      expect(keys.length).to eq(2)
      expect(keys[0]).to match(auto_key_pattern)
      expect(keys[1]).to match(auto_key_pattern)
      expect(keys[0]).not_to eq(keys[1])
    end

    it 'rotates the auto key on 5xx for media uploads too' do
      keys = capture_keys(:post, '/media',
                          server_error(502),
                          ok('id' => 'med_x', 'url' => 'https://cdn.example/x.jpg'))

      client.media.upload(StringIO.new('fake-image-bytes'))

      expect(keys.length).to eq(2)
      expect(keys[0]).to match(auto_key_pattern)
      expect(keys[1]).to match(auto_key_pattern)
      expect(keys[0]).not_to eq(keys[1])
    end
  end

  describe 'caller-supplied keys' do
    it 'sends the caller key verbatim' do
      keys = capture_keys(:post, '/messages', ok(message_response))

      messages.send(to: '+15551234567', text: 'Hello!', idempotency_key: 'order-4821-shipped')

      expect(keys.first).to eq('order-4821-shipped')
    end

    it 'never rotates the caller key, even across a 5xx retry' do
      keys = capture_keys(:post, '/messages', server_error, ok(message_response))

      messages.send(to: '+15551234567', text: 'Hello!', idempotency_key: 'order-4821-shipped')

      expect(keys.length).to eq(2)
      expect(keys[0]).to eq('order-4821-shipped')
      expect(keys[1]).to eq('order-4821-shipped')
    end

    it 'accepts a key on send_batch' do
      keys = capture_keys(:post, '/messages/batch', ok(batch_response))

      messages.send_batch(
        messages: [{ to: '+15551234567', text: 'Hi!' }],
        idempotency_key: 'campaign-77-wave-1'
      )

      expect(keys.first).to eq('campaign-77-wave-1')
    end

    it 'accepts a key on schedule' do
      keys = capture_keys(:post, '/messages/schedule', ok(scheduled_message_response))

      messages.schedule(
        to: '+15551234567',
        text: 'Reminder!',
        scheduled_at: '2025-01-20T10:00:00Z',
        idempotency_key: 'reminder-visit-31'
      )

      expect(keys.first).to eq('reminder-visit-31')
    end

    it 'accepts a key on send_group' do
      keys = capture_keys(:post, '/messages/group',
                          ok('id' => 'msg_x', 'group_message_id' => 'grp_x',
                             'to' => ['+14155551234', '+14155555678'], 'status' => 'sent'))

      messages.send_group(
        to: ['+14155551234', '+14155555678'],
        text: 'Team sync at noon',
        idempotency_key: 'standup-ping-0823'
      )

      expect(keys.first).to eq('standup-ping-0823')
    end

    it 'accepts a key on the WhatsApp send branch' do
      keys = capture_keys(:post, '/messages',
                          ok('id' => 'msg_wa', 'channel' => 'whatsapp', 'to' => '+15551234567',
                             'from' => '+15559876543', 'status' => 'queued',
                             'whatsapp' => { 'kind' => 'text' }))

      messages.send(
        channel: 'whatsapp',
        to: '+15551234567',
        from: '+15559876543',
        text: 'Hello!',
        idempotency_key: 'wa-hello-1'
      )

      expect(keys.first).to eq('wa-hello-1')
    end

    it 'accepts a key on the RCS send branch' do
      keys = capture_keys(:post, '/messages',
                          ok('id' => 'msg_rcs', 'channel' => 'rcs', 'to' => '+15551234567',
                             'status' => 'queued'))

      messages.send(channel: 'rcs', to: '+15551234567', text: 'Hello!', idempotency_key: 'rcs-hello-1')

      expect(keys.first).to eq('rcs-hello-1')
    end

    it 'ignores an empty-string key and still auto-generates' do
      keys = capture_keys(:post, '/messages', ok(message_response))

      messages.send(to: '+15551234567', text: 'Hello!', idempotency_key: '')

      expect(keys.first).to match(auto_key_pattern)
    end

    it 'ignores a whitespace-only key and still auto-generates' do
      keys = capture_keys(:post, '/messages', ok(message_response))

      messages.send(to: '+15551234567', text: 'Hello!', idempotency_key: '   ')

      expect(keys.first).to match(auto_key_pattern)
    end

    it 'trims surrounding whitespace from the caller key' do
      keys = capture_keys(:post, '/messages', ok(message_response))

      messages.send(to: '+15551234567', text: 'Hello!', idempotency_key: '  order-4821  ')

      expect(keys.first).to eq('order-4821')
    end

    it 'rejects a non-ASCII key immediately without a network call' do
      expect {
        messages.send(to: '+15551234567', text: 'Hello!', idempotency_key: 'Заказ-42')
      }.to raise_error(Sendly::ValidationError, /1-255 printable ASCII/)

      expect(a_request(:post, "#{base_url}/messages")).not_to have_been_made
    end

    it 'rejects a key longer than 255 characters immediately' do
      expect {
        messages.send(to: '+15551234567', text: 'Hello!', idempotency_key: 'k' * 256)
      }.to raise_error(Sendly::ValidationError, /1-255 printable ASCII/)

      expect(a_request(:post, "#{base_url}/messages")).not_to have_been_made
    end
  end
end
