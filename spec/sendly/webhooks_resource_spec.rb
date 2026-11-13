# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::WebhooksResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:webhooks) { client.webhooks }

  def json_response(body, status: 200)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def delivery_row(overrides = {})
    {
      'id' => 'del_1',
      'webhook_id' => 'whk_1',
      'event_id' => 'evt_1',
      'event_type' => 'message.delivered',
      'status' => 'failed',
      'success' => false,
      'response_status_code' => 500,
      'http_status' => 500,
      'response_time' => 42,
      'response_time_ms' => 42,
      'response_body' => 'upstream error',
      'error_message' => 'HTTP 500',
      'error_code' => 'http_error',
      'attempt_number' => 2,
      'max_attempts' => 6,
      'next_retry_at' => '2026-09-25T10:05:00.000Z',
      'created_at' => '2026-09-25T10:00:00.000Z',
      'delivered_at' => nil
    }.merge(overrides)
  end

  describe '#deliveries' do
    it 'reads the deliveries out of the {deliveries, pagination} envelope' do
      stub = stub_request(:get, "#{base_url}/webhooks/whk_1/deliveries?limit=10&offset=20&status=failed")
             .to_return(json_response({ 'deliveries' => [delivery_row],
                                        'pagination' => { 'limit' => 10, 'offset' => 20 } }))

      deliveries = webhooks.deliveries('whk_1', limit: 10, offset: 20, status: 'failed')

      expect(stub).to have_been_requested
      expect(deliveries.length).to eq(1)
      delivery = deliveries.first
      expect(delivery).to be_a(Sendly::WebhookDelivery)
      expect(delivery.id).to eq('del_1')
      expect(delivery.event_id).to eq('evt_1')
      expect(delivery.event_type).to eq('message.delivered')
      expect(delivery.response_status_code).to eq(500)
      expect(delivery.response_time_ms).to eq(42)
      expect(delivery.attempt_number).to eq(2)
      expect(delivery.max_attempts).to eq(6)
      expect(delivery.created_at).to be_a(Time)
      expect(delivery).to be_failed
    end

    it 'sends no query parameters when none are given' do
      stub = stub_request(:get, "#{base_url}/webhooks/whk_1/deliveries")
             .to_return(json_response({ 'deliveries' => [], 'pagination' => { 'limit' => 50, 'offset' => 0 } }))

      expect(webhooks.deliveries('whk_1')).to eq([])
      expect(stub).to have_been_requested
    end
  end

  describe '#rotate_secret' do
    let(:rotation_body) do
      {
        'success' => true,
        'id' => 'whk_1',
        'secret' => 'whsec_new',
        'new_secret' => 'whsec_new',
        'new_secret_version' => 2,
        'grace_period_hours' => 24,
        'rotated_at' => '2026-09-25T10:00:00.000Z',
        'message' => "Webhook secret rotated successfully. Save this secret - it won't be shown again."
      }
    end

    it 'returns the new secret from the body the API sends' do
      stub = stub_request(:post, "#{base_url}/webhooks/whk_1/rotate-secret")
             .to_return(json_response(rotation_body))

      rotation = webhooks.rotate_secret('whk_1')

      expect(stub).to have_been_requested
      expect(rotation).to be_a(Sendly::WebhookSecretRotation)
      expect(rotation.new_secret).to eq('whsec_new')
      expect(rotation.id).to eq('whk_1')
      expect(rotation.new_secret_version).to eq(2)
      expect(rotation.grace_period_hours).to eq(24)
      expect(rotation.rotated_at).to eq(Time.parse('2026-09-25T10:00:00.000Z'))
      expect(rotation.message).to start_with('Webhook secret rotated')
      expect(rotation.webhook).to be_nil
      expect(rotation.old_secret_expires_at).to be_nil
      expect(rotation.raw).to eq(rotation_body)
    end

    it 'still reads a body that carries only secret' do
      stub_request(:post, "#{base_url}/webhooks/whk_1/rotate-secret")
        .to_return(json_response({ 'success' => true, 'id' => 'whk_1', 'secret' => 'whsec_only' }))

      expect(webhooks.rotate_secret('whk_1').new_secret).to eq('whsec_only')
    end
  end

  describe '#test' do
    it 'reads the status code and timing from the test delivery' do
      body = {
        'success' => true,
        'message' => 'Test webhook delivered successfully in 87ms',
        'delivery' => {
          'id' => 'del_1',
          'delivery_id' => 'del_1',
          'webhook_url' => 'https://example.com/hook',
          'event_type' => 'webhook.test',
          'status' => 'delivered',
          'response_time' => 87,
          'status_code' => 200,
          'response_body' => 'ok',
          'delivered_at' => '2026-09-25T10:00:00.000Z'
        }
      }
      stub_request(:post, "#{base_url}/webhooks/whk_1/test").to_return(json_response(body))

      result = webhooks.test('whk_1')

      expect(result).to be_success
      expect(result.status_code).to eq(200)
      expect(result.response_time_ms).to eq(87)
      expect(result.delivery_id).to eq('del_1')
      expect(result.message).to eq('Test webhook delivered successfully in 87ms')
      expect(result.error).to be_nil
      expect(result.raw).to eq(body)
    end

    it 'raises ValidationError with the API message when the test delivery fails' do
      stub_request(:post, "#{base_url}/webhooks/whk_1/test")
        .to_return(json_response({ 'success' => false, 'message' => 'Test webhook failed: HTTP 500' }, status: 400))

      expect { webhooks.test('whk_1') }
        .to raise_error(Sendly::ValidationError, 'Test webhook failed: HTTP 500')
    end
  end

  describe '#recovery_preview' do
    let(:preview_body) do
      {
        'circuitState' => 'open',
        'circuitOpenedAt' => '2026-09-25T08:00:00.000Z',
        'failureCount' => 12,
        'auditFailures' => {
          'total' => 3,
          'byStatus' => { 'failed' => 2, 'cancelled' => 1 },
          'byEventType' => { 'message.delivered' => 2, 'message.opt_out' => 1 }
        },
        'missingFromMessages' => { 'total' => 4, 'byEventType' => { 'message.sent' => 4 } },
        'histogram' => [{ 'bucket' => '2026-09-25T08:00:00.000Z', 'missing' => 4, 'failed' => 3 }],
        'samples' => [{ 'id' => 'msg_1', 'toMasked' => '+1555***4567',
                        'eventType' => 'message.delivered', 'occurredAt' => '2026-09-25T08:30:00.000Z' }],
        'windowSuggestion' => { 'since' => '2026-09-25T08:00:00.000Z', 'until' => '2026-09-25T10:00:00.000Z' },
        'since' => '2026-09-24T10:00:00.000Z',
        'until' => '2026-09-25T10:00:00.000Z'
      }
    end

    it 'sends the window with comma-separated event_types and reads the camelCase preview' do
      stub = stub_request(:get, "#{base_url}/webhooks/whk_1/recovery-preview")
             .with(query: { 'since' => '2026-09-24T10:00:00.000Z', 'until' => '2026-09-25T10:00:00.000Z',
                            'event_types' => 'message.delivered,message.failed' })
             .to_return(json_response(preview_body))

      preview = webhooks.recovery_preview('whk_1', since: '2026-09-24T10:00:00.000Z',
                                                   until_: '2026-09-25T10:00:00.000Z',
                                                   event_types: %w[message.delivered message.failed])

      expect(stub).to have_been_requested
      expect(preview).to be_a(Sendly::WebhookRecoveryPreview)
      expect(preview.circuit_state).to eq('open')
      expect(preview).to be_circuit_open
      expect(preview.circuit_opened_at).to eq(Time.parse('2026-09-25T08:00:00.000Z'))
      expect(preview.failure_count).to eq(12)
      expect(preview.audit_failures[:total]).to eq(3)
      expect(preview.audit_failures[:by_status]).to eq('failed' => 2, 'cancelled' => 1)
      expect(preview.audit_failures[:by_event_type]['message.opt_out']).to eq(1)
      expect(preview.missing_from_messages[:total]).to eq(4)
      expect(preview.histogram.first[:missing]).to eq(4)
      expect(preview.samples.first[:to_masked]).to eq('+1555***4567')
      expect(preview.samples.first[:event_type]).to eq('message.delivered')
      expect(preview.window_suggestion[:since]).to eq(Time.parse('2026-09-25T08:00:00.000Z'))
      expect(preview.until).to eq(Time.parse('2026-09-25T10:00:00.000Z'))
      expect(preview.raw).to eq(preview_body)
    end

    it 'sends no query parameters when none are given' do
      body = preview_body.merge('circuitOpenedAt' => nil, 'windowSuggestion' => nil)
      stub = stub_request(:get, "#{base_url}/webhooks/whk_1/recovery-preview").to_return(json_response(body))

      preview = webhooks.recovery_preview('whk_1')

      expect(stub).to have_been_requested
      expect(preview.circuit_opened_at).to be_nil
      expect(preview.window_suggestion).to be_nil
    end

    it 'rejects an id that is not whk_ prefixed' do
      expect { webhooks.recovery_preview('bad') }.to raise_error(ArgumentError)
    end
  end

  describe 'stored metadata' do
    def stored_webhook(metadata)
      {
        'id' => 'whk_placeholder1',
        'url' => 'https://localhost/sendly-contract-capture',
        'events' => ['message.received'],
        'description' => 'Contract capture',
        'mode' => 'test',
        'is_active' => true,
        'failure_count' => 0,
        'circuit_state' => 'closed',
        'api_version' => '2024-01',
        'metadata' => metadata,
        'created_at' => '2026-01-01T00:00:00.000Z',
        'updated_at' => '2026-01-01T00:00:00.000Z',
        'total_deliveries' => 0,
        'successful_deliveries' => 0,
        'success_rate' => 0,
        'last_delivery_at' => nil
      }
    end

    it 'reads object metadata on get' do
      stub_request(:get, "#{base_url}/webhooks/whk_placeholder1")
        .to_return(json_response(stored_webhook({ 'purpose' => 'contract-capture' })))

      expect(webhooks.get('whk_placeholder1').metadata).to eq({ 'purpose' => 'contract-capture' })
    end

    [['a', 1], 'note', 7, true, nil].each do |stored|
      it "reads #{stored.inspect} metadata as an empty Hash on list" do
        stub_request(:get, "#{base_url}/webhooks").to_return(json_response([stored_webhook(stored)]))

        webhook = webhooks.list.first

        expect(webhook.id).to eq('whk_placeholder1')
        expect(webhook.metadata).to eq({})
        expect(webhook.to_h[:metadata]).to eq({})
      end
    end
  end
end
