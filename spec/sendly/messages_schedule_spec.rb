# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::Messages, 'Scheduling' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:messages) { client.messages }

  describe '#schedule' do
    context 'with valid parameters' do
      it 'schedules message for future delivery' do
        response = scheduled_message_response
        stub_request_with_auth(:post, '/messages/schedule',
                               response_body: response)

        result = messages.schedule(
          to: '+15551234567',
          text: 'Reminder!',
          scheduled_at: '2025-01-20T10:00:00Z'
        )

        expect(result['id']).to eq('sched_abc123')
        expect(result['status']).to eq('scheduled')
        expect(result['scheduledAt']).to eq('2025-01-20T10:00:00Z')
      end

      it 'sends request with correct payload' do
        stub = stub_request(:post, "#{base_url}/messages/schedule")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: {
              to: '+15551234567',
              text: 'Test',
              scheduledAt: '2025-01-20T10:00:00Z'
            }.to_json
          )
          .to_return(status: 200, body: scheduled_message_response.to_json)

        messages.schedule(
          to: '+15551234567',
          text: 'Test',
          scheduled_at: '2025-01-20T10:00:00Z'
        )
        expect(stub).to have_been_requested
      end

      it 'includes optional from parameter' do
        stub = stub_request(:post, "#{base_url}/messages/schedule")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: {
              to: '+15551234567',
              text: 'Test',
              scheduledAt: '2025-01-20T10:00:00Z',
              from: 'ACME'
            }.to_json
          )
          .to_return(status: 200, body: scheduled_message_response.to_json)

        messages.schedule(
          to: '+15551234567',
          text: 'Test',
          scheduled_at: '2025-01-20T10:00:00Z',
          from: 'ACME'
        )
        expect(stub).to have_been_requested
      end

      it 'accepts ISO 8601 datetime with timezone' do
        stub_request_with_auth(:post, '/messages/schedule',
                               response_body: scheduled_message_response)

        result = messages.schedule(
          to: '+15551234567',
          text: 'Test',
          scheduled_at: '2025-01-20T15:30:00+05:30'
        )

        expect(result['id']).to eq('sched_abc123')
      end
    end

    context 'validation errors - invalid phone format' do
      it 'raises error for invalid phone format' do
        expect {
          messages.schedule(
            to: '15551234567',
            text: 'Test',
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end

      it 'raises error for nil phone' do
        expect {
          messages.schedule(
            to: nil,
            text: 'Test',
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end
    end

    context 'validation errors - invalid text' do
      it 'raises error for nil text' do
        expect {
          messages.schedule(
            to: '+15551234567',
            text: nil,
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::ValidationError, 'Message text is required')
      end

      it 'raises error for empty text' do
        expect {
          messages.schedule(
            to: '+15551234567',
            text: '',
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::ValidationError, 'Message text is required')
      end

      it 'raises error for text exceeding maximum length' do
        expect {
          messages.schedule(
            to: '+15551234567',
            text: 'a' * 1601,
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::ValidationError, /exceeds maximum length/)
      end
    end

    context 'validation errors - invalid scheduled_at' do
      it 'raises error for nil scheduled_at' do
        expect {
          messages.schedule(
            to: '+15551234567',
            text: 'Test',
            scheduled_at: nil
          )
        }.to raise_error(Sendly::ValidationError, 'scheduled_at is required')
      end

      it 'raises error for empty scheduled_at' do
        expect {
          messages.schedule(
            to: '+15551234567',
            text: 'Test',
            scheduled_at: ''
          )
        }.to raise_error(Sendly::ValidationError, 'scheduled_at is required')
      end
    end

    context 'HTTP 401 - Authentication failure' do
      it 'raises AuthenticationError' do
        stub_request_with_auth(:post, '/messages/schedule',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.schedule(
            to: '+15551234567',
            text: 'Test',
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::AuthenticationError)
      end
    end

    context 'HTTP 402 - Insufficient credits' do
      it 'raises InsufficientCreditsError' do
        stub_request_with_auth(:post, '/messages/schedule',
                               status: 402,
                               response_body: { message: 'Insufficient credits' })

        expect {
          messages.schedule(
            to: '+15551234567',
            text: 'Test',
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::InsufficientCreditsError)
      end
    end

    context 'HTTP 429 - Rate limit' do
      it 'raises RateLimitError' do
        stub_request_with_auth(:post, '/messages/schedule',
                               status: 429,
                               response_body: { message: 'Rate limit exceeded', retryAfter: 0.01 })

        expect {
          messages.schedule(
            to: '+15551234567',
            text: 'Test',
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::RateLimitError)
      end
    end

    context 'HTTP 500 - Server error' do
      it 'raises ServerError' do
        stub_request_with_auth(:post, '/messages/schedule',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.schedule(
            to: '+15551234567',
            text: 'Test',
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::ServerError)
      end
    end

    context 'Network error' do
      it 'raises NetworkError on connection failure' do
        stub_request(:post, "#{base_url}/messages/schedule")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(Errno::ECONNREFUSED)

        expect {
          messages.schedule(
            to: '+15551234567',
            text: 'Test',
            scheduled_at: '2025-01-20T10:00:00Z'
          )
        }.to raise_error(Sendly::NetworkError)
      end
    end
  end

  describe '#list_scheduled' do
    context 'with valid parameters' do
      it 'lists scheduled messages with default pagination' do
        response = {
          'data' => [scheduled_message_response, scheduled_message_response(id: 'sched_2')],
          'count' => 2,
          'limit' => 20,
          'offset' => 0
        }

        stub_request_with_auth(:get, '/messages/scheduled?limit=20&offset=0',
                               response_body: response)

        result = messages.list_scheduled
        expect(result['data'].length).to eq(2)
        expect(result['data'][0]['id']).to eq('sched_abc123')
      end

      it 'accepts custom limit and offset' do
        stub = stub_request(:get, "#{base_url}/messages/scheduled?limit=50&offset=100")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: { data: [], count: 0, limit: 50, offset: 100 }.to_json)

        messages.list_scheduled(limit: 50, offset: 100)
        expect(stub).to have_been_requested
      end

      it 'caps limit at 100' do
        stub = stub_request(:get, "#{base_url}/messages/scheduled?limit=100&offset=0")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: { data: [], count: 0, limit: 100, offset: 0 }.to_json)

        messages.list_scheduled(limit: 200)
        expect(stub).to have_been_requested
      end

      it 'filters by status' do
        stub = stub_request(:get, "#{base_url}/messages/scheduled?limit=20&offset=0&status=scheduled")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: { data: [], count: 0, limit: 20, offset: 0 }.to_json)

        messages.list_scheduled(status: 'scheduled')
        expect(stub).to have_been_requested
      end

      it 'handles empty result set' do
        stub_request_with_auth(:get, '/messages/scheduled?limit=20&offset=0',
                               response_body: { data: [], count: 0, limit: 20, offset: 0 })

        result = messages.list_scheduled
        expect(result['data']).to be_empty
      end
    end

    context 'HTTP errors' do
      it 'raises AuthenticationError on 401' do
        stub_request_with_auth(:get, '/messages/scheduled?limit=20&offset=0',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.list_scheduled
        }.to raise_error(Sendly::AuthenticationError)
      end

      it 'raises ServerError on 500' do
        stub_request_with_auth(:get, '/messages/scheduled?limit=20&offset=0',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.list_scheduled
        }.to raise_error(Sendly::ServerError)
      end
    end
  end

  describe '#get_scheduled' do
    context 'with valid ID' do
      it 'retrieves scheduled message by ID' do
        stub_request_with_auth(:get, '/messages/scheduled/sched_abc123',
                               response_body: scheduled_message_response)

        result = messages.get_scheduled('sched_abc123')
        expect(result['id']).to eq('sched_abc123')
        expect(result['status']).to eq('scheduled')
      end

      it 'URL encodes scheduled message ID' do
        stub = stub_request(:get, "#{base_url}/messages/scheduled/sched_123%2Fspecial")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: scheduled_message_response(id: 'sched_123/special').to_json)

        result = messages.get_scheduled('sched_123/special')
        expect(result['id']).to eq('sched_123/special')
        expect(stub).to have_been_requested
      end
    end

    context 'validation errors' do
      it 'raises error for nil ID' do
        expect {
          messages.get_scheduled(nil)
        }.to raise_error(Sendly::ValidationError, 'Scheduled message ID is required')
      end

      it 'raises error for empty ID' do
        expect {
          messages.get_scheduled('')
        }.to raise_error(Sendly::ValidationError, 'Scheduled message ID is required')
      end
    end

    context 'HTTP 404 - Not found' do
      it 'raises NotFoundError' do
        stub_request_with_auth(:get, '/messages/scheduled/sched_nonexistent',
                               status: 404,
                               response_body: { message: 'Scheduled message not found' })

        expect {
          messages.get_scheduled('sched_nonexistent')
        }.to raise_error(Sendly::NotFoundError, 'Scheduled message not found')
      end
    end

    context 'HTTP 401 - Authentication failure' do
      it 'raises AuthenticationError' do
        stub_request_with_auth(:get, '/messages/scheduled/sched_abc123',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.get_scheduled('sched_abc123')
        }.to raise_error(Sendly::AuthenticationError)
      end
    end

    context 'HTTP 500 - Server error' do
      it 'raises ServerError' do
        stub_request_with_auth(:get, '/messages/scheduled/sched_abc123',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.get_scheduled('sched_abc123')
        }.to raise_error(Sendly::ServerError)
      end
    end
  end

  describe '#cancel_scheduled' do
    context 'with valid ID' do
      it 'cancels scheduled message and returns refund details' do
        response = {
          'id' => 'sched_abc123',
          'status' => 'cancelled',
          'creditsRefunded' => 1
        }

        stub_request(:delete, "#{base_url}/messages/scheduled/sched_abc123")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: response.to_json)

        result = messages.cancel_scheduled('sched_abc123')
        expect(result['id']).to eq('sched_abc123')
        expect(result['status']).to eq('cancelled')
        expect(result['creditsRefunded']).to eq(1)
      end

      it 'URL encodes scheduled message ID' do
        stub = stub_request(:delete, "#{base_url}/messages/scheduled/sched_123%2Fspecial")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: { id: 'sched_123/special', status: 'cancelled' }.to_json)

        messages.cancel_scheduled('sched_123/special')
        expect(stub).to have_been_requested
      end
    end

    context 'validation errors' do
      it 'raises error for nil ID' do
        expect {
          messages.cancel_scheduled(nil)
        }.to raise_error(Sendly::ValidationError, 'Scheduled message ID is required')
      end

      it 'raises error for empty ID' do
        expect {
          messages.cancel_scheduled('')
        }.to raise_error(Sendly::ValidationError, 'Scheduled message ID is required')
      end
    end

    context 'HTTP 404 - Not found' do
      it 'raises NotFoundError' do
        stub_request(:delete, "#{base_url}/messages/scheduled/sched_nonexistent")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 404, body: { message: 'Scheduled message not found' }.to_json)

        expect {
          messages.cancel_scheduled('sched_nonexistent')
        }.to raise_error(Sendly::NotFoundError, 'Scheduled message not found')
      end
    end

    context 'HTTP 401 - Authentication failure' do
      it 'raises AuthenticationError' do
        stub_request(:delete, "#{base_url}/messages/scheduled/sched_abc123")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 401, body: { message: 'Invalid API key' }.to_json)

        expect {
          messages.cancel_scheduled('sched_abc123')
        }.to raise_error(Sendly::AuthenticationError)
      end
    end

    context 'HTTP 400 - Validation error (cannot cancel)' do
      it 'raises ValidationError when message cannot be cancelled' do
        stub_request(:delete, "#{base_url}/messages/scheduled/sched_abc123")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 400, body: { message: 'Message already sent' }.to_json)

        expect {
          messages.cancel_scheduled('sched_abc123')
        }.to raise_error(Sendly::ValidationError, 'Message already sent')
      end
    end

    context 'HTTP 500 - Server error' do
      it 'raises ServerError' do
        stub_request(:delete, "#{base_url}/messages/scheduled/sched_abc123")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 500, body: { message: 'Server error' }.to_json)

        expect {
          messages.cancel_scheduled('sched_abc123')
        }.to raise_error(Sendly::ServerError)
      end
    end

    context 'Network error' do
      it 'raises NetworkError on connection failure' do
        stub_request(:delete, "#{base_url}/messages/scheduled/sched_abc123")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(Errno::ECONNREFUSED)

        expect {
          messages.cancel_scheduled('sched_abc123')
        }.to raise_error(Sendly::NetworkError)
      end
    end
  end
end
