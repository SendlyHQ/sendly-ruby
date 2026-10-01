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
end
