# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::Webhooks do
  let(:webhook_secret) { 'whsec_test123abc' }

  describe '.verify_signature' do
    context 'with valid signature' do
      it 'returns true for valid signature' do
        payload = '{"id":"evt_123","type":"message.delivered"}'
        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        result = Sendly::Webhooks.verify_signature(payload, signature, webhook_secret)
        expect(result).to be true
      end

      it 'validates signature with special characters in payload' do
        payload = '{"text":"Hello! How are you? 👋"}'
        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        result = Sendly::Webhooks.verify_signature(payload, signature, webhook_secret)
        expect(result).to be true
      end

      it 'validates signature with unicode characters' do
        payload = '{"text":"测试消息"}'
        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        result = Sendly::Webhooks.verify_signature(payload, signature, webhook_secret)
        expect(result).to be true
      end

      it 'validates signature with newlines in payload' do
        payload = "{\n  \"id\": \"evt_123\",\n  \"type\": \"message.delivered\"\n}"
        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        result = Sendly::Webhooks.verify_signature(payload, signature, webhook_secret)
        expect(result).to be true
      end
    end

    context 'with invalid signature' do
      it 'returns false for tampered payload' do
        payload = '{"id":"evt_123","type":"message.delivered"}'
        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        tampered_payload = '{"id":"evt_123","type":"message.failed"}'
        result = Sendly::Webhooks.verify_signature(tampered_payload, signature, webhook_secret)
        expect(result).to be false
      end

      it 'returns false for wrong secret' do
        payload = '{"id":"evt_123","type":"message.delivered"}'
        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        result = Sendly::Webhooks.verify_signature(payload, signature, 'wrong_secret')
        expect(result).to be false
      end

      it 'returns false for malformed signature' do
        payload = '{"id":"evt_123","type":"message.delivered"}'
        result = Sendly::Webhooks.verify_signature(payload, 'invalid_signature', webhook_secret)
        expect(result).to be false
      end

      it 'returns false for signature without sha256 prefix' do
        payload = '{"id":"evt_123","type":"message.delivered"}'
        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)
        signature_without_prefix = signature.sub('sha256=', '')

        result = Sendly::Webhooks.verify_signature(payload, signature_without_prefix, webhook_secret)
        expect(result).to be false
      end

      it 'returns false for empty signature' do
        payload = '{"id":"evt_123","type":"message.delivered"}'
        result = Sendly::Webhooks.verify_signature(payload, '', webhook_secret)
        expect(result).to be false
      end

      it 'returns false for nil signature' do
        payload = '{"id":"evt_123","type":"message.delivered"}'
        result = Sendly::Webhooks.verify_signature(payload, nil, webhook_secret)
        expect(result).to be false
      end
    end

    context 'with invalid inputs' do
      it 'returns false for nil payload' do
        signature = 'sha256=abc123'
        result = Sendly::Webhooks.verify_signature(nil, signature, webhook_secret)
        expect(result).to be false
      end

      it 'returns false for empty payload' do
        signature = 'sha256=abc123'
        result = Sendly::Webhooks.verify_signature('', signature, webhook_secret)
        expect(result).to be false
      end

      it 'returns false for nil secret' do
        payload = '{"id":"evt_123"}'
        signature = 'sha256=abc123'
        result = Sendly::Webhooks.verify_signature(payload, signature, nil)
        expect(result).to be false
      end

      it 'returns false for empty secret' do
        payload = '{"id":"evt_123"}'
        signature = 'sha256=abc123'
        result = Sendly::Webhooks.verify_signature(payload, signature, '')
        expect(result).to be false
      end
    end
  end

  describe '.parse_event' do
    context 'with valid event' do
      it 'parses message.delivered event' do
        payload = {
          id: 'evt_123',
          type: 'message.delivered',
          data: {
            message_id: 'msg_abc123',
            status: 'delivered',
            to: '+15551234567',
            from: '',
            delivered_at: '2025-01-15T10:00:00Z',
            segments: 1,
            credits_used: 1
          },
          created_at: '2025-01-15T10:00:00Z',
          api_version: '2024-01-01'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        event = Sendly::Webhooks.parse_event(payload, signature, webhook_secret)

        expect(event).to be_a(Sendly::WebhookEvent)
        expect(event.id).to eq('evt_123')
        expect(event.type).to eq('message.delivered')
        expect(event.data.message_id).to eq('msg_abc123')
        expect(event.data.status).to eq('delivered')
        expect(event.data.to).to eq('+15551234567')
        expect(event.api_version).to eq('2024-01-01')
      end

      it 'parses message.failed event with error details' do
        payload = {
          id: 'evt_456',
          type: 'message.failed',
          data: {
            message_id: 'msg_xyz789',
            status: 'failed',
            to: '+15551234567',
            from: '',
            error: 'Invalid phone number',
            error_code: 'INVALID_PHONE',
            failed_at: '2025-01-15T10:00:00Z'
          },
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        event = Sendly::Webhooks.parse_event(payload, signature, webhook_secret)

        expect(event.type).to eq('message.failed')
        expect(event.data.error).to eq('Invalid phone number')
        expect(event.data.error_code).to eq('INVALID_PHONE')
        expect(event.data.failed_at).to eq('2025-01-15T10:00:00Z')
      end

      it 'parses event without api_version (defaults to 2024-01-01)' do
        payload = {
          id: 'evt_123',
          type: 'message.sent',
          data: { message_id: 'msg_123', status: 'sent', to: '+15551234567', from: '' },
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)
        event = Sendly::Webhooks.parse_event(payload, signature, webhook_secret)

        expect(event.api_version).to eq('2024-01-01')
      end

      it 'converts event to hash' do
        payload = {
          id: 'evt_123',
          type: 'message.delivered',
          data: { message_id: 'msg_123', status: 'delivered', to: '+15551234567', from: '' },
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)
        event = Sendly::Webhooks.parse_event(payload, signature, webhook_secret)

        hash = event.to_h
        expect(hash[:id]).to eq('evt_123')
        expect(hash[:type]).to eq('message.delivered')
        expect(hash[:data][:message_id]).to eq('msg_123')
      end

      it 'converts event data to hash' do
        payload = {
          id: 'evt_123',
          type: 'message.delivered',
          data: {
            message_id: 'msg_123',
            status: 'delivered',
            to: '+15551234567',
            from: 'ACME',
            segments: 2,
            credits_used: 2
          },
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)
        event = Sendly::Webhooks.parse_event(payload, signature, webhook_secret)

        data_hash = event.data.to_h
        expect(data_hash[:message_id]).to eq('msg_123')
        expect(data_hash[:status]).to eq('delivered')
        expect(data_hash[:segments]).to eq(2)
        expect(data_hash[:credits_used]).to eq(2)
      end
    end

    context 'with invalid signature' do
      it 'raises WebhookSignatureError for invalid signature' do
        payload = {
          id: 'evt_123',
          type: 'message.delivered',
          data: { message_id: 'msg_123', status: 'delivered', to: '+15551234567', from: '' },
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        expect {
          Sendly::Webhooks.parse_event(payload, 'invalid_signature', webhook_secret)
        }.to raise_error(Sendly::WebhookSignatureError, 'Invalid webhook signature')
      end

      it 'raises WebhookSignatureError for tampered payload' do
        payload = {
          id: 'evt_123',
          type: 'message.delivered',
          data: { message_id: 'msg_123', status: 'delivered', to: '+15551234567', from: '' },
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        tampered_payload = payload.gsub('delivered', 'failed')

        expect {
          Sendly::Webhooks.parse_event(tampered_payload, signature, webhook_secret)
        }.to raise_error(Sendly::WebhookSignatureError, 'Invalid webhook signature')
      end
    end

    context 'with malformed payload' do
      it 'raises WebhookSignatureError for invalid JSON' do
        payload = 'not valid json'
        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        expect {
          Sendly::Webhooks.parse_event(payload, signature, webhook_secret)
        }.to raise_error(Sendly::WebhookSignatureError, /Failed to parse webhook payload/)
      end

      it 'raises WebhookSignatureError for missing id field' do
        payload = {
          type: 'message.delivered',
          data: { message_id: 'msg_123', status: 'delivered', to: '+15551234567', from: '' },
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        expect {
          Sendly::Webhooks.parse_event(payload, signature, webhook_secret)
        }.to raise_error(Sendly::WebhookSignatureError, 'Invalid event structure')
      end

      it 'raises WebhookSignatureError for missing type field' do
        payload = {
          id: 'evt_123',
          data: { message_id: 'msg_123', status: 'delivered', to: '+15551234567', from: '' },
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        expect {
          Sendly::Webhooks.parse_event(payload, signature, webhook_secret)
        }.to raise_error(Sendly::WebhookSignatureError, 'Invalid event structure')
      end

      it 'raises WebhookSignatureError for missing data field' do
        payload = {
          id: 'evt_123',
          type: 'message.delivered',
          created_at: '2025-01-15T10:00:00Z'
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        expect {
          Sendly::Webhooks.parse_event(payload, signature, webhook_secret)
        }.to raise_error(Sendly::WebhookSignatureError, 'Invalid event structure')
      end

      it 'raises WebhookSignatureError for missing created_at field' do
        payload = {
          id: 'evt_123',
          type: 'message.delivered',
          data: { message_id: 'msg_123', status: 'delivered', to: '+15551234567', from: '' }
        }.to_json

        signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

        expect {
          Sendly::Webhooks.parse_event(payload, signature, webhook_secret)
        }.to raise_error(Sendly::WebhookSignatureError, 'Invalid event structure')
      end
    end
  end

  describe '.generate_signature' do
    it 'generates sha256 signature with correct format' do
      payload = '{"test":"data"}'
      signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

      expect(signature).to start_with('sha256=')
      expect(signature.length).to be > 7
    end

    it 'generates consistent signatures for same input' do
      payload = '{"test":"data"}'
      sig1 = Sendly::Webhooks.generate_signature(payload, webhook_secret)
      sig2 = Sendly::Webhooks.generate_signature(payload, webhook_secret)

      expect(sig1).to eq(sig2)
    end

    it 'generates different signatures for different payloads' do
      sig1 = Sendly::Webhooks.generate_signature('{"a":1}', webhook_secret)
      sig2 = Sendly::Webhooks.generate_signature('{"a":2}', webhook_secret)

      expect(sig1).not_to eq(sig2)
    end

    it 'generates different signatures for different secrets' do
      payload = '{"test":"data"}'
      sig1 = Sendly::Webhooks.generate_signature(payload, 'secret1')
      sig2 = Sendly::Webhooks.generate_signature(payload, 'secret2')

      expect(sig1).not_to eq(sig2)
    end

    it 'works with empty payload' do
      signature = Sendly::Webhooks.generate_signature('', webhook_secret)
      expect(signature).to start_with('sha256=')
    end

    it 'generates valid signature that passes verification' do
      payload = '{"id":"evt_123","type":"message.delivered"}'
      signature = Sendly::Webhooks.generate_signature(payload, webhook_secret)

      verified = Sendly::Webhooks.verify_signature(payload, signature, webhook_secret)
      expect(verified).to be true
    end
  end

  describe Sendly::WebhookSignatureError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::WebhookSignatureError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::WebhookSignatureError.new
      expect(error.message).to eq('Invalid webhook signature')
    end

    it 'accepts custom message' do
      error = Sendly::WebhookSignatureError.new('Custom error message')
      expect(error.message).to eq('Custom error message')
    end

    it 'has error code' do
      error = Sendly::WebhookSignatureError.new
      expect(error.code).to eq('WEBHOOK_SIGNATURE_ERROR')
    end
  end

  describe Sendly::WebhookEvent do
    it 'initializes with required fields' do
      data = {
        id: 'evt_123',
        type: 'message.delivered',
        data: { message_id: 'msg_123', status: 'delivered', to: '+15551234567', from: '' },
        created_at: '2025-01-15T10:00:00Z'
      }

      event = Sendly::WebhookEvent.new(data)

      expect(event.id).to eq('evt_123')
      expect(event.type).to eq('message.delivered')
      expect(event.created_at).to eq('2025-01-15T10:00:00Z')
      expect(event.data).to be_a(Sendly::WebhookMessageData)
    end
  end

  describe Sendly::WebhookMessageData do
    it 'initializes with message data' do
      data = {
        message_id: 'msg_123',
        status: 'delivered',
        to: '+15551234567',
        from: 'ACME',
        delivered_at: '2025-01-15T10:00:00Z',
        segments: 2,
        credits_used: 2
      }

      message_data = Sendly::WebhookMessageData.new(data)

      expect(message_data.message_id).to eq('msg_123')
      expect(message_data.status).to eq('delivered')
      expect(message_data.to).to eq('+15551234567')
      expect(message_data.from).to eq('ACME')
      expect(message_data.delivered_at).to eq('2025-01-15T10:00:00Z')
      expect(message_data.segments).to eq(2)
      expect(message_data.credits_used).to eq(2)
    end

    it 'handles missing optional fields' do
      data = {
        message_id: 'msg_123',
        status: 'sent',
        to: '+15551234567'
      }

      message_data = Sendly::WebhookMessageData.new(data)

      expect(message_data.from).to eq('')
      expect(message_data.error).to be_nil
      expect(message_data.error_code).to be_nil
      expect(message_data.segments).to eq(1)
      expect(message_data.credits_used).to eq(0)
    end

    it 'includes error fields for failed messages' do
      data = {
        message_id: 'msg_123',
        status: 'failed',
        to: '+15551234567',
        from: '',
        error: 'Invalid phone number',
        error_code: 'INVALID_PHONE',
        failed_at: '2025-01-15T10:00:00Z'
      }

      message_data = Sendly::WebhookMessageData.new(data)

      expect(message_data.error).to eq('Invalid phone number')
      expect(message_data.error_code).to eq('INVALID_PHONE')
      expect(message_data.failed_at).to eq('2025-01-15T10:00:00Z')
    end
  end
end
