# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::Messages, 'Batch' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:messages) { client.messages }

  describe '#send_batch' do
    context 'with valid parameters' do
      it 'sends batch of messages' do
        stub_request_with_auth(:post, '/messages/batch',
                               response_body: batch_response)

        result = messages.send_batch(
          messages: [
            { to: '+15551234567', text: 'Hello Alice!' },
            { to: '+15559876543', text: 'Hello Bob!' }
          ]
        )

        expect(result['batchId']).to eq('batch_abc123')
        expect(result['total']).to eq(2)
        expect(result['queued']).to eq(2)
        expect(result['status']).to eq('processing')
      end

      it 'sends request with correct payload' do
        stub = stub_request(:post, "#{base_url}/messages/batch")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: {
              messages: [
                { to: '+15551234567', text: 'Test 1' },
                { to: '+15559876543', text: 'Test 2' }
              ]
            }.to_json
          )
          .to_return(status: 200, body: batch_response.to_json)

        messages.send_batch(
          messages: [
            { to: '+15551234567', text: 'Test 1' },
            { to: '+15559876543', text: 'Test 2' }
          ]
        )
        expect(stub).to have_been_requested
      end

      it 'includes optional from parameter' do
        stub = stub_request(:post, "#{base_url}/messages/batch")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: {
              messages: [
                { to: '+15551234567', text: 'Test' }
              ],
              from: 'ACME'
            }.to_json
          )
          .to_return(status: 200, body: batch_response.to_json)

        messages.send_batch(
          messages: [{ to: '+15551234567', text: 'Test' }],
          from: 'ACME'
        )
        expect(stub).to have_been_requested
      end

      it 'handles large batch' do
        large_batch = 100.times.map do |i|
          { to: "+1555123#{i.to_s.rjust(4, '0')}", text: "Message #{i}" }
        end

        stub_request_with_auth(:post, '/messages/batch',
                               response_body: batch_response(total: 100, queued: 100))

        result = messages.send_batch(messages: large_batch)
        expect(result['total']).to eq(100)
      end

      it 'accepts messages with string keys' do
        stub_request_with_auth(:post, '/messages/batch',
                               response_body: batch_response)

        result = messages.send_batch(
          messages: [
            { 'to' => '+15551234567', 'text' => 'Test' }
          ]
        )
        expect(result['batchId']).to eq('batch_abc123')
      end
    end

    context 'validation errors - invalid messages array' do
      it 'raises error for nil messages' do
        expect {
          messages.send_batch(messages: nil)
        }.to raise_error(Sendly::ValidationError, 'Messages array is required')
      end

      it 'raises error for empty messages array' do
        expect {
          messages.send_batch(messages: [])
        }.to raise_error(Sendly::ValidationError, 'Messages array is required')
      end

      it 'raises error for message missing to field' do
        expect {
          messages.send_batch(
            messages: [
              { text: 'Hello' }
            ]
          )
        }.to raise_error(Sendly::ValidationError, /Message at index 0 missing 'to'/)
      end

      it 'raises error for message missing text field' do
        expect {
          messages.send_batch(
            messages: [
              { to: '+15551234567' }
            ]
          )
        }.to raise_error(Sendly::ValidationError, /Message at index 0 missing 'text'/)
      end

      it 'raises error for invalid phone in batch' do
        expect {
          messages.send_batch(
            messages: [
              { to: '+15551234567', text: 'Valid' },
              { to: '15559876543', text: 'Invalid phone' }
            ]
          )
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end

      it 'raises error for empty text in batch' do
        expect {
          messages.send_batch(
            messages: [
              { to: '+15551234567', text: '' }
            ]
          )
        }.to raise_error(Sendly::ValidationError, 'Message text is required')
      end

      it 'raises error for text exceeding maximum length in batch' do
        expect {
          messages.send_batch(
            messages: [
              { to: '+15551234567', text: 'a' * 1601 }
            ]
          )
        }.to raise_error(Sendly::ValidationError, /exceeds maximum length/)
      end

      it 'reports correct index for validation error' do
        expect {
          messages.send_batch(
            messages: [
              { to: '+15551234567', text: 'Valid' },
              { to: '+15559876543', text: 'Valid' },
              { text: 'Missing to' }
            ]
          )
        }.to raise_error(Sendly::ValidationError, /Message at index 2 missing 'to'/)
      end
    end

    context 'HTTP 401 - Authentication failure' do
      it 'raises AuthenticationError' do
        stub_request_with_auth(:post, '/messages/batch',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.send_batch(
            messages: [{ to: '+15551234567', text: 'Test' }]
          )
        }.to raise_error(Sendly::AuthenticationError)
      end
    end

    context 'HTTP 402 - Insufficient credits' do
      it 'raises InsufficientCreditsError' do
        stub_request_with_auth(:post, '/messages/batch',
                               status: 402,
                               response_body: { message: 'Insufficient credits for batch' })

        expect {
          messages.send_batch(
            messages: [{ to: '+15551234567', text: 'Test' }]
          )
        }.to raise_error(Sendly::InsufficientCreditsError, 'Insufficient credits for batch')
      end
    end

    context 'HTTP 429 - Rate limit' do
      it 'raises RateLimitError' do
        stub_request_with_auth(:post, '/messages/batch',
                               status: 429,
                               response_body: { message: 'Rate limit exceeded', retryAfter: 0.01 })

        expect {
          messages.send_batch(
            messages: [{ to: '+15551234567', text: 'Test' }]
          )
        }.to raise_error(Sendly::RateLimitError)
      end
    end

    context 'HTTP 500 - Server error' do
      it 'raises ServerError' do
        stub_request_with_auth(:post, '/messages/batch',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.send_batch(
            messages: [{ to: '+15551234567', text: 'Test' }]
          )
        }.to raise_error(Sendly::ServerError)
      end
    end

    context 'Network error' do
      it 'raises NetworkError on connection failure' do
        stub_request(:post, "#{base_url}/messages/batch")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(Errno::ECONNREFUSED)

        expect {
          messages.send_batch(
            messages: [{ to: '+15551234567', text: 'Test' }]
          )
        }.to raise_error(Sendly::NetworkError)
      end
    end
  end

  describe '#get_batch' do
    context 'with valid batch ID' do
      it 'retrieves batch status' do
        response = batch_response(
          batchId: 'batch_abc123',
          total: 10,
          queued: 0,
          sent: 8,
          failed: 2,
          status: 'completed'
        )

        stub_request_with_auth(:get, '/messages/batch/batch_abc123',
                               response_body: response)

        result = messages.get_batch('batch_abc123')
        expect(result['batchId']).to eq('batch_abc123')
        expect(result['total']).to eq(10)
        expect(result['sent']).to eq(8)
        expect(result['failed']).to eq(2)
        expect(result['status']).to eq('completed')
      end

      it 'URL encodes batch ID' do
        stub = stub_request(:get, "#{base_url}/messages/batch/batch_123%2Fspecial")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: batch_response(batchId: 'batch_123/special').to_json)

        result = messages.get_batch('batch_123/special')
        expect(result['batchId']).to eq('batch_123/special')
        expect(stub).to have_been_requested
      end

      it 'handles processing status' do
        stub_request_with_auth(:get, '/messages/batch/batch_abc123',
                               response_body: batch_response(status: 'processing'))

        result = messages.get_batch('batch_abc123')
        expect(result['status']).to eq('processing')
      end

      it 'handles failed status' do
        stub_request_with_auth(:get, '/messages/batch/batch_abc123',
                               response_body: batch_response(status: 'failed'))

        result = messages.get_batch('batch_abc123')
        expect(result['status']).to eq('failed')
      end
    end

    context 'validation errors' do
      it 'raises error for nil batch ID' do
        expect {
          messages.get_batch(nil)
        }.to raise_error(Sendly::ValidationError, 'Batch ID is required')
      end

      it 'raises error for empty batch ID' do
        expect {
          messages.get_batch('')
        }.to raise_error(Sendly::ValidationError, 'Batch ID is required')
      end
    end

    context 'HTTP 404 - Not found' do
      it 'raises NotFoundError' do
        stub_request_with_auth(:get, '/messages/batch/batch_nonexistent',
                               status: 404,
                               response_body: { message: 'Batch not found' })

        expect {
          messages.get_batch('batch_nonexistent')
        }.to raise_error(Sendly::NotFoundError, 'Batch not found')
      end
    end

    context 'HTTP 401 - Authentication failure' do
      it 'raises AuthenticationError' do
        stub_request_with_auth(:get, '/messages/batch/batch_abc123',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.get_batch('batch_abc123')
        }.to raise_error(Sendly::AuthenticationError)
      end
    end

    context 'HTTP 500 - Server error' do
      it 'raises ServerError' do
        stub_request_with_auth(:get, '/messages/batch/batch_abc123',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.get_batch('batch_abc123')
        }.to raise_error(Sendly::ServerError)
      end
    end

    context 'Network error' do
      it 'raises NetworkError on connection failure' do
        stub_request(:get, "#{base_url}/messages/batch/batch_abc123")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(Errno::ECONNREFUSED)

        expect {
          messages.get_batch('batch_abc123')
        }.to raise_error(Sendly::NetworkError)
      end
    end
  end

  describe '#list_batches' do
    context 'with valid parameters' do
      it 'lists batches with default pagination' do
        response = {
          'data' => [
            batch_response(batchId: 'batch_1'),
            batch_response(batchId: 'batch_2')
          ],
          'count' => 2,
          'limit' => 20,
          'offset' => 0
        }

        stub_request_with_auth(:get, '/messages/batches?limit=20&offset=0',
                               response_body: response)

        result = messages.list_batches
        expect(result['data'].length).to eq(2)
        expect(result['data'][0]['batchId']).to eq('batch_1')
        expect(result['data'][1]['batchId']).to eq('batch_2')
      end

      it 'accepts custom limit and offset' do
        stub = stub_request(:get, "#{base_url}/messages/batches?limit=50&offset=100")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: { data: [], count: 0, limit: 50, offset: 100 }.to_json)

        messages.list_batches(limit: 50, offset: 100)
        expect(stub).to have_been_requested
      end

      it 'caps limit at 100' do
        stub = stub_request(:get, "#{base_url}/messages/batches?limit=100&offset=0")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: { data: [], count: 0, limit: 100, offset: 0 }.to_json)

        messages.list_batches(limit: 200)
        expect(stub).to have_been_requested
      end

      it 'filters by status' do
        stub = stub_request(:get, "#{base_url}/messages/batches?limit=20&offset=0&status=completed")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: { data: [], count: 0, limit: 20, offset: 0 }.to_json)

        messages.list_batches(status: 'completed')
        expect(stub).to have_been_requested
      end

      it 'handles empty result set' do
        stub_request_with_auth(:get, '/messages/batches?limit=20&offset=0',
                               response_body: { data: [], count: 0, limit: 20, offset: 0 })

        result = messages.list_batches
        expect(result['data']).to be_empty
      end

      it 'handles multiple batch statuses' do
        response = {
          'data' => [
            batch_response(batchId: 'batch_1', status: 'processing'),
            batch_response(batchId: 'batch_2', status: 'completed'),
            batch_response(batchId: 'batch_3', status: 'failed')
          ],
          'count' => 3,
          'limit' => 20,
          'offset' => 0
        }

        stub_request_with_auth(:get, '/messages/batches?limit=20&offset=0',
                               response_body: response)

        result = messages.list_batches
        expect(result['data'][0]['status']).to eq('processing')
        expect(result['data'][1]['status']).to eq('completed')
        expect(result['data'][2]['status']).to eq('failed')
      end
    end

    context 'HTTP errors' do
      it 'raises AuthenticationError on 401' do
        stub_request_with_auth(:get, '/messages/batches?limit=20&offset=0',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.list_batches
        }.to raise_error(Sendly::AuthenticationError)
      end

      it 'raises ServerError on 500' do
        stub_request_with_auth(:get, '/messages/batches?limit=20&offset=0',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.list_batches
        }.to raise_error(Sendly::ServerError)
      end

      it 'raises RateLimitError on 429' do
        stub_request_with_auth(:get, '/messages/batches?limit=20&offset=0',
                               status: 429,
                               response_body: { message: 'Rate limit exceeded', retryAfter: 0.01 })

        expect {
          messages.list_batches
        }.to raise_error(Sendly::RateLimitError)
      end
    end

    context 'Network error' do
      it 'raises NetworkError on connection failure' do
        stub_request(:get, "#{base_url}/messages/batches?limit=20&offset=0")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(SocketError)

        expect {
          messages.list_batches
        }.to raise_error(Sendly::NetworkError)
      end
    end
  end
end
