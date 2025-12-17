# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::Client do
  describe '#initialize' do
    context 'with valid API key' do
      it 'creates a client with test key' do
        client = Sendly::Client.new(api_key: 'sk_test_v1_abc123')
        expect(client.api_key).to eq('sk_test_v1_abc123')
        expect(client.base_url).to eq('https://sendly.live/api/v1')
        expect(client.timeout).to eq(30)
        expect(client.max_retries).to eq(3)
      end

      it 'creates a client with live key' do
        client = Sendly::Client.new(api_key: 'sk_live_v1_xyz789')
        expect(client.api_key).to eq('sk_live_v1_xyz789')
      end

      it 'accepts custom base_url' do
        client = Sendly::Client.new(
          api_key: 'sk_test_v1_abc123',
          base_url: 'https://api.example.com'
        )
        expect(client.base_url).to eq('https://api.example.com')
      end

      it 'strips trailing slash from base_url' do
        client = Sendly::Client.new(
          api_key: 'sk_test_v1_abc123',
          base_url: 'https://api.example.com/'
        )
        expect(client.base_url).to eq('https://api.example.com')
      end

      it 'accepts custom timeout' do
        client = Sendly::Client.new(
          api_key: 'sk_test_v1_abc123',
          timeout: 60
        )
        expect(client.timeout).to eq(60)
      end

      it 'accepts custom max_retries' do
        client = Sendly::Client.new(
          api_key: 'sk_test_v1_abc123',
          max_retries: 5
        )
        expect(client.max_retries).to eq(5)
      end
    end

    context 'with invalid API key' do
      it 'raises error for nil API key' do
        expect {
          Sendly::Client.new(api_key: nil)
        }.to raise_error(Sendly::AuthenticationError, 'API key is required')
      end

      it 'raises error for empty API key' do
        expect {
          Sendly::Client.new(api_key: '')
        }.to raise_error(Sendly::AuthenticationError, 'API key is required')
      end

      it 'raises error for invalid format' do
        expect {
          Sendly::Client.new(api_key: 'invalid_key')
        }.to raise_error(Sendly::AuthenticationError, /Invalid API key format/)
      end

      it 'raises error for wrong prefix' do
        expect {
          Sendly::Client.new(api_key: 'pk_test_v1_abc123')
        }.to raise_error(Sendly::AuthenticationError, /Invalid API key format/)
      end

      it 'raises error for wrong version' do
        expect {
          Sendly::Client.new(api_key: 'sk_test_v2_abc123')
        }.to raise_error(Sendly::AuthenticationError, /Invalid API key format/)
      end

      it 'raises error for missing environment' do
        expect {
          Sendly::Client.new(api_key: 'sk_v1_abc123')
        }.to raise_error(Sendly::AuthenticationError, /Invalid API key format/)
      end
    end
  end

  describe '#messages' do
    it 'returns Messages instance' do
      client = Sendly::Client.new(api_key: valid_api_key)
      expect(client.messages).to be_a(Sendly::Messages)
    end

    it 'returns same instance on repeated calls' do
      client = Sendly::Client.new(api_key: valid_api_key)
      messages1 = client.messages
      messages2 = client.messages
      expect(messages1).to be(messages2)
    end
  end

  describe '#get' do
    let(:client) { Sendly::Client.new(api_key: valid_api_key) }

    it 'makes GET request with query parameters' do
      stub = stub_request_with_auth(:get, '/messages?limit=10&offset=0',
                                     response_body: { data: [] })

      client.get('/messages', { limit: 10, offset: 0 })
      expect(stub).to have_been_requested
    end

    it 'URL encodes query parameters' do
      stub = stub_request(:get, "#{base_url}/messages?to=%2B15551234567")
        .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
        .to_return(status: 200, body: '{}')

      client.get('/messages', { to: '+15551234567' })
      expect(stub).to have_been_requested
    end

    it 'returns parsed JSON response' do
      stub_request_with_auth(:get, '/messages',
                             response_body: { data: [{ id: 'msg_123' }] })

      result = client.get('/messages')
      expect(result).to eq({ 'data' => [{ 'id' => 'msg_123' }] })
    end
  end

  describe '#post' do
    let(:client) { Sendly::Client.new(api_key: valid_api_key) }

    it 'makes POST request with JSON body' do
      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: { to: '+15551234567', text: 'Hello' }.to_json
        )
        .to_return(status: 200, body: message_response.to_json)

      client.post('/messages', { to: '+15551234567', text: 'Hello' })
      expect(stub).to have_been_requested
    end

    it 'returns parsed JSON response' do
      stub_request_with_auth(:post, '/messages',
                             response_body: message_response)

      result = client.post('/messages', { to: '+15551234567', text: 'Hello' })
      expect(result['id']).to eq('msg_abc123')
    end
  end

  describe '#delete' do
    let(:client) { Sendly::Client.new(api_key: valid_api_key) }

    it 'makes DELETE request' do
      stub = stub_request(:delete, "#{base_url}/messages/scheduled/sched_123")
        .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
        .to_return(status: 200, body: '{}')

      client.delete('/messages/scheduled/sched_123')
      expect(stub).to have_been_requested
    end
  end

  describe 'error handling' do
    let(:client) { Sendly::Client.new(api_key: valid_api_key) }

    context 'HTTP 401 - Authentication failure' do
      it 'raises AuthenticationError' do
        stub_request_with_auth(:get, '/messages',
                               status: 401,
                               response_body: { message: 'Invalid API key' })

        expect {
          client.get('/messages')
        }.to raise_error(Sendly::AuthenticationError, 'Invalid API key')
      end
    end

    context 'HTTP 402 - Insufficient credits' do
      it 'raises InsufficientCreditsError' do
        stub_request_with_auth(:post, '/messages',
                               status: 402,
                               response_body: { message: 'Insufficient credits' })

        expect {
          client.post('/messages', {})
        }.to raise_error(Sendly::InsufficientCreditsError, 'Insufficient credits')
      end
    end

    context 'HTTP 404 - Not found' do
      it 'raises NotFoundError' do
        stub_request_with_auth(:get, '/messages/msg_nonexistent',
                               status: 404,
                               response_body: { message: 'Message not found' })

        expect {
          client.get('/messages/msg_nonexistent')
        }.to raise_error(Sendly::NotFoundError, 'Message not found')
      end
    end

    context 'HTTP 429 - Rate limit' do
      it 'raises RateLimitError with retry_after' do
        stub_request_with_auth(:post, '/messages',
                               status: 429,
                               response_body: { message: 'Rate limit exceeded', retryAfter: 0.01 })

        expect {
          client.post('/messages', {})
        }.to raise_error(Sendly::RateLimitError) do |error|
          expect(error.message).to eq('Rate limit exceeded')
          expect(error.retry_after).to eq(0.01)
        end
      end

      it 'retries after rate limit with retry_after' do
        client_with_retries = Sendly::Client.new(api_key: valid_api_key, max_retries: 1)

        stub_request(:post, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(
            { status: 429, body: { message: 'Rate limited', retryAfter: 0.1 }.to_json },
            { status: 200, body: message_response.to_json }
          )

        result = client_with_retries.post('/messages', {})
        expect(result['id']).to eq('msg_abc123')
      end

      it 'raises after max retries exceeded' do
        client_with_retries = Sendly::Client.new(api_key: valid_api_key, max_retries: 2)

        stub_request(:post, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 429, body: { message: 'Rate limited', retryAfter: 0.1 }.to_json)

        expect {
          client_with_retries.post('/messages', {})
        }.to raise_error(Sendly::RateLimitError, 'Rate limited')
      end
    end

    context 'HTTP 500 - Server error' do
      it 'raises ServerError' do
        stub_request_with_auth(:get, '/messages',
                               status: 500,
                               response_body: { message: 'Internal server error' })

        expect {
          client.get('/messages')
        }.to raise_error(Sendly::ServerError, 'Internal server error')
      end

      it 'retries on server error' do
        client_with_retries = Sendly::Client.new(api_key: valid_api_key, max_retries: 1)

        stub_request(:get, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(
            { status: 500, body: { message: 'Server error' }.to_json },
            { status: 200, body: message_list_response([]).to_json }
          )

        result = client_with_retries.get('/messages')
        expect(result['data']).to eq([])
      end

      it 'raises after max retries exceeded on server error' do
        client_with_retries = Sendly::Client.new(api_key: valid_api_key, max_retries: 2)

        stub_request(:get, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 500, body: { message: 'Server error' }.to_json)

        expect {
          client_with_retries.get('/messages')
        }.to raise_error(Sendly::ServerError, 'Server error')
      end
    end

    context 'Network errors' do
      it 'raises TimeoutError on read timeout' do
        stub_request(:get, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_timeout

        expect {
          client.get('/messages')
        }.to raise_error(Sendly::TimeoutError, /Request timed out/)
      end

      it 'raises NetworkError on connection refused' do
        stub_request(:get, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(Errno::ECONNREFUSED)

        expect {
          client.get('/messages')
        }.to raise_error(Sendly::NetworkError, /Connection failed/)
      end

      it 'raises NetworkError on connection reset' do
        stub_request(:get, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(Errno::ECONNRESET)

        expect {
          client.get('/messages')
        }.to raise_error(Sendly::NetworkError, /Connection failed/)
      end

      it 'raises NetworkError on socket error' do
        stub_request(:get, "#{base_url}/messages")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_raise(SocketError.new('getaddrinfo: Name or service not known'))

        expect {
          client.get('/messages')
        }.to raise_error(Sendly::NetworkError, /Connection failed/)
      end
    end
  end
end
