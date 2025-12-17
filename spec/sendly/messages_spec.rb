# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::Messages do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:messages) { client.messages }

  describe '#send' do
    context 'with valid parameters' do
      it 'sends SMS and returns message object' do
        stub_request_with_auth(:post, '/messages',
                               response_body: message_response)

        message = messages.send(to: '+15551234567', text: 'Hello, world!')

        expect(message).to be_a(Sendly::Message)
        expect(message.id).to eq('msg_abc123')
        expect(message.to).to eq('+15551234567')
        expect(message.text).to eq('Hello, world!')
        expect(message.status).to eq('sent')
        expect(message.segments).to eq(1)
        expect(message.credits_used).to eq(1)
      end

      it 'sends request with correct payload' do
        stub = stub_request(:post, "#{base_url}/messages")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: { to: '+15551234567', text: 'Test message' }.to_json
          )
          .to_return(status: 200, body: message_response.to_json)

        messages.send(to: '+15551234567', text: 'Test message')
        expect(stub).to have_been_requested
      end

      it 'handles long messages' do
        long_text = 'a' * 1600
        stub_request_with_auth(:post, '/messages',
                               response_body: message_response(text: long_text, segments: 10))

        message = messages.send(to: '+15551234567', text: long_text)
        expect(message.segments).to eq(10)
      end

      it 'handles international numbers' do
        stub_request_with_auth(:post, '/messages',
                               response_body: message_response(to: '+447911123456'))

        message = messages.send(to: '+447911123456', text: 'Hello UK!')
        expect(message.to).to eq('+447911123456')
      end
    end

    context 'validation errors - invalid phone format' do
      it 'raises error for missing plus sign' do
        expect {
          messages.send(to: '15551234567', text: 'Hello')
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end

      it 'raises error for letters in phone number' do
        expect {
          messages.send(to: '+1555CALLME', text: 'Hello')
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end

      it 'raises error for too short number' do
        expect {
          messages.send(to: '+1', text: 'Hello')
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end

      it 'raises error for too long number' do
        expect {
          messages.send(to: '+' + '1' * 20, text: 'Hello')
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end

      it 'raises error for phone starting with zero' do
        expect {
          messages.send(to: '+0551234567', text: 'Hello')
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end

      it 'raises error for nil phone' do
        expect {
          messages.send(to: nil, text: 'Hello')
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end

      it 'raises error for empty phone' do
        expect {
          messages.send(to: '', text: 'Hello')
        }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
      end
    end

    context 'validation errors - invalid text' do
      it 'raises error for nil text' do
        expect {
          messages.send(to: '+15551234567', text: nil)
        }.to raise_error(Sendly::ValidationError, 'Message text is required')
      end

      it 'raises error for empty text' do
        expect {
          messages.send(to: '+15551234567', text: '')
        }.to raise_error(Sendly::ValidationError, 'Message text is required')
      end

      it 'raises error for text exceeding maximum length' do
        long_text = 'a' * 1601
        expect {
          messages.send(to: '+15551234567', text: long_text)
        }.to raise_error(Sendly::ValidationError, /exceeds maximum length/)
      end
    end

    context 'HTTP 401 - Authentication failure' do
      it 'raises AuthenticationError' do
        stub_request_with_auth(:post, '/messages',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.send(to: '+15551234567', text: 'Hello')
        }.to raise_error(Sendly::AuthenticationError, 'Invalid API key')
      end
    end

    context 'HTTP 402 - Insufficient credits' do
      it 'raises InsufficientCreditsError' do
        stub_request_with_auth(:post, '/messages',
                               status: 402,
                               response_body: { message: 'Insufficient credits' })

        expect {
          messages.send(to: '+15551234567', text: 'Hello')
        }.to raise_error(Sendly::InsufficientCreditsError, 'Insufficient credits')
      end
    end

    context 'HTTP 429 - Rate limit' do
      it 'raises RateLimitError with retry_after' do
        stub_request_with_auth(:post, '/messages',
                               status: 429,
                               response_body: { message: 'Rate limit exceeded', retryAfter: 10 })

        expect {
          messages.send(to: '+15551234567', text: 'Hello')
        }.to raise_error(Sendly::RateLimitError) do |error|
          expect(error.retry_after).to eq(10)
        end
      end
    end

    context 'HTTP 500 - Server error' do
      it 'raises ServerError' do
        stub_request_with_auth(:post, '/messages',
                               status: 500,
                               response_body: { message: 'Internal server error' })

        expect {
          messages.send(to: '+15551234567', text: 'Hello')
        }.to raise_error(Sendly::ServerError, 'Internal server error')
      end
    end

    context 'Network error' do
      it 'raises NetworkError on connection failure' do
        stub_request(:post, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(Errno::ECONNREFUSED)

        expect {
          messages.send(to: '+15551234567', text: 'Hello')
        }.to raise_error(Sendly::NetworkError, /Connection failed/)
      end
    end
  end

  describe '#list' do
    context 'with valid parameters' do
      it 'lists messages with default pagination' do
        response = message_list_response([
          message_response(id: 'msg_1'),
          message_response(id: 'msg_2')
        ], total: 2)

        stub_request_with_auth(:get, '/messages?limit=20&offset=0',
                               response_body: response)

        list = messages.list
        expect(list).to be_a(Sendly::MessageList)
        expect(list.data.length).to eq(2)
        expect(list.data[0].id).to eq('msg_1')
        expect(list.data[1].id).to eq('msg_2')
        expect(list.total).to eq(2)
        expect(list.has_more).to be false
      end

      it 'accepts custom limit and offset' do
        stub = stub_request(:get, "#{base_url}/messages?limit=50&offset=100")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: message_list_response([]).to_json)

        messages.list(limit: 50, offset: 100)
        expect(stub).to have_been_requested
      end

      it 'caps limit at 100' do
        stub = stub_request(:get, "#{base_url}/messages?limit=100&offset=0")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: message_list_response([]).to_json)

        messages.list(limit: 200)
        expect(stub).to have_been_requested
      end

      it 'filters by status' do
        stub = stub_request(:get, "#{base_url}/messages?limit=20&offset=0&status=delivered")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: message_list_response([]).to_json)

        messages.list(status: 'delivered')
        expect(stub).to have_been_requested
      end

      it 'filters by recipient' do
        stub = stub_request(:get, "#{base_url}/messages?limit=20&offset=0&to=%2B15551234567")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: message_list_response([]).to_json)

        messages.list(to: '+15551234567')
        expect(stub).to have_been_requested
      end

      it 'filters by both status and recipient' do
        stub = stub_request(:get, "#{base_url}/messages?limit=20&offset=0&status=sent&to=%2B15551234567")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: message_list_response([]).to_json)

        messages.list(status: 'sent', to: '+15551234567')
        expect(stub).to have_been_requested
      end

      it 'handles empty result set' do
        stub_request_with_auth(:get, '/messages?limit=20&offset=0',
                               response_body: message_list_response([]))

        list = messages.list
        expect(list.data).to be_empty
        expect(list.total).to eq(0)
      end

      it 'indicates has_more when more pages exist' do
        response = {
          'data' => [message_response],
          'count' => 100,
          'limit' => 20,
          'offset' => 0
        }

        stub_request_with_auth(:get, '/messages?limit=20&offset=0',
                               response_body: response)

        list = messages.list
        expect(list.has_more).to be true
      end
    end

    context 'HTTP errors' do
      it 'raises AuthenticationError on 401' do
        stub_request_with_auth(:get, '/messages?limit=20&offset=0',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.list
        }.to raise_error(Sendly::AuthenticationError)
      end

      it 'raises ServerError on 500' do
        stub_request_with_auth(:get, '/messages?limit=20&offset=0',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.list
        }.to raise_error(Sendly::ServerError)
      end
    end
  end

  describe '#get' do
    context 'with valid ID' do
      it 'retrieves message by ID' do
        stub_request_with_auth(:get, '/messages/msg_abc123',
                               response_body: message_response(id: 'msg_abc123'))

        message = messages.get('msg_abc123')
        expect(message).to be_a(Sendly::Message)
        expect(message.id).to eq('msg_abc123')
      end

      it 'URL encodes message ID' do
        stub = stub_request(:get, "#{base_url}/messages/msg_123%2Fspecial")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: message_response(id: 'msg_123/special').to_json)

        message = messages.get('msg_123/special')
        expect(message.id).to eq('msg_123/special')
        expect(stub).to have_been_requested
      end
    end

    context 'validation errors' do
      it 'raises error for nil ID' do
        expect {
          messages.get(nil)
        }.to raise_error(Sendly::ValidationError, 'Message ID is required')
      end

      it 'raises error for empty ID' do
        expect {
          messages.get('')
        }.to raise_error(Sendly::ValidationError, 'Message ID is required')
      end
    end

    context 'HTTP 404 - Not found' do
      it 'raises NotFoundError' do
        stub_request_with_auth(:get, '/messages/msg_nonexistent',
                               status: 404,
                               response_body: { message: 'Message not found' })

        expect {
          messages.get('msg_nonexistent')
        }.to raise_error(Sendly::NotFoundError, 'Message not found')
      end
    end

    context 'HTTP 401 - Authentication failure' do
      it 'raises AuthenticationError' do
        stub_request_with_auth(:get, '/messages/msg_abc123',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.get('msg_abc123')
        }.to raise_error(Sendly::AuthenticationError)
      end
    end

    context 'HTTP 500 - Server error' do
      it 'raises ServerError' do
        stub_request_with_auth(:get, '/messages/msg_abc123',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.get('msg_abc123')
        }.to raise_error(Sendly::ServerError)
      end
    end
  end

  describe '#each' do
    context 'with pagination' do
      it 'iterates through all messages with automatic pagination' do
        # First page
        page1 = message_list_response([
          message_response(id: 'msg_1'),
          message_response(id: 'msg_2')
        ], total: 4)
        page1['offset'] = 0

        # Second page
        page2 = message_list_response([
          message_response(id: 'msg_3'),
          message_response(id: 'msg_4')
        ], total: 4)
        page2['offset'] = 2

        stub_request_with_auth(:get, '/messages?limit=2&offset=0',
                               response_body: page1)
        stub_request_with_auth(:get, '/messages?limit=2&offset=2',
                               response_body: page2)

        collected = []
        messages.each(batch_size: 2) { |msg| collected << msg.id }

        expect(collected).to eq(['msg_1', 'msg_2', 'msg_3', 'msg_4'])
      end

      it 'handles empty result set' do
        stub_request_with_auth(:get, '/messages?limit=100&offset=0',
                               response_body: message_list_response([]))

        collected = []
        messages.each { |msg| collected << msg }

        expect(collected).to be_empty
      end

      it 'passes filters to pagination requests' do
        stub1 = stub_request(:get, "#{base_url}/messages?limit=100&offset=0&status=sent&to=%2B15551234567")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: message_list_response([message_response]).to_json)

        collected = []
        messages.each(status: 'sent', to: '+15551234567') { |msg| collected << msg }

        expect(stub1).to have_been_requested
        expect(collected.length).to eq(1)
      end

      it 'returns enumerator when no block given' do
        stub_request_with_auth(:get, '/messages?limit=100&offset=0',
                               response_body: message_list_response([message_response]))

        enumerator = messages.each
        expect(enumerator).to be_a(Enumerator)
        expect(enumerator.first).to be_a(Sendly::Message)
      end

      it 'stops pagination when no more pages' do
        stub_request_with_auth(:get, '/messages?limit=100&offset=0',
                               response_body: message_list_response([message_response]))

        # Should only make one request
        collected = []
        messages.each { |msg| collected << msg.id }

        expect(collected).to eq(['msg_abc123'])
      end
    end

    context 'HTTP errors' do
      it 'raises AuthenticationError on 401' do
        stub_request_with_auth(:get, '/messages?limit=100&offset=0',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          messages.each { |msg| puts msg }
        }.to raise_error(Sendly::AuthenticationError)
      end

      it 'raises ServerError on 500' do
        stub_request_with_auth(:get, '/messages?limit=100&offset=0',
                               status: 500,
                               response_body: { message: 'Server error' })

        expect {
          messages.each { |msg| puts msg }
        }.to raise_error(Sendly::ServerError)
      end
    end
  end
end
