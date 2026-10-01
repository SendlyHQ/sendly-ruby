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

      # v3.31.0: positional api_key support (matches our published docs)
      it 'accepts api_key positionally' do
        client = Sendly::Client.new('sk_test_v1_positional')
        expect(client.api_key).to eq('sk_test_v1_positional')
      end

      it 'accepts api_key positionally with keyword options' do
        client = Sendly::Client.new('sk_test_v1_positional', timeout: 60, max_retries: 5)
        expect(client.api_key).to eq('sk_test_v1_positional')
        expect(client.timeout).to eq(60)
        expect(client.max_retries).to eq(5)
      end

      it 'raises if api_key is passed both positionally and as keyword' do
        expect do
          Sendly::Client.new('sk_test_v1_pos', api_key: 'sk_test_v1_kw')
        end.to raise_error(ArgumentError, /both positionally and as keyword/)
      end

      it 'raises if more than one positional argument is given' do
        expect do
          Sendly::Client.new('sk_test_v1_a', 'sk_test_v1_b')
        end.to raise_error(ArgumentError, /at most one positional argument/)
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

  describe '#post_multipart' do
    let(:client) { Sendly::Client.new(api_key: valid_api_key) }

    it 'uploads media whose filename is not ASCII, with the name sent as UTF-8' do
      png = "\x89PNG\r\n\x1A\n".b + ("\xFF\x00".b * 8)
      sent = nil
      stub = stub_request(:post, "#{base_url}/media")
             .with { |req| sent = req.body.b; true }
             .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                        body: { 'id' => 'med_x', 'url' => 'https://cdn.example/x.png' }.to_json)

      media = client.media.upload(StringIO.new(png), content_type: 'image/png', filename: 'café.png')

      expect(stub).to have_been_requested.once
      expect(media.id).to eq('med_x')
      expect(sent).to include("name=\"file\"; filename=\"café.png\"\r\nContent-Type: image/png\r\n\r\n".b + png)
    end
  end

  describe 'ids in the request path' do
    let(:client) { Sendly::Client.new(api_key: valid_api_key) }

    ['', '.', '..', '%2e', '%2E%2e', '.%2e'].each do |bad|
      it "refuses the path segment #{bad.inspect} before sending anything" do
        expect { client.delete("/enterprise/workspaces/ws_1/keys/#{bad}") }
          .to raise_error(Sendly::ValidationError, /cannot be empty, '\.' or '\.\.'/)
        expect { client.get("/messages/#{bad}/status") }.to raise_error(Sendly::ValidationError)
        expect(a_request(:any, /sendly\.live/)).not_to have_been_made
      end
    end

    it 'refuses a dot-segment id from a resource method before sending anything' do
      expect { client.enterprise.workspaces.revoke_key('ws_1', '..') }
        .to raise_error(Sendly::ValidationError)
      expect { client.campaigns.delete('.') }.to raise_error(Sendly::ValidationError)
      expect { client.post_multipart('/media/..', StringIO.new('x')) }.to raise_error(Sendly::ValidationError)
      expect(a_request(:any, /sendly\.live/)).not_to have_been_made
    end

    it 'still sends ids that only contain dots among other characters, and leaves the query alone' do
      stub = stub_request(:delete, "#{base_url}/enterprise/workspaces/ws_1/keys/key...1")
             .to_return(status: 200, body: { success: true }.to_json)
      webhooks = stub_request(:delete, "#{base_url}/enterprise/workspaces/ws_1/webhooks?webhookId=..")
                 .to_return(status: 200, body: { success: true }.to_json)

      expect(client.enterprise.workspaces.revoke_key('ws_1', 'key...1')).to eq('success' => true)
      client.enterprise.workspaces.delete_webhooks('ws_1', webhook_id: '..')
      expect(stub).to have_been_requested.once
      expect(webhooks).to have_been_requested.once
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

      it 'waits out a busy API key check and retries it instead of raising' do
        allow(client).to receive(:sleep)
        stub = stub_request(:get, "#{base_url}/account")
               .to_return(
                 { status: 429, headers: { 'Retry-After' => '1' },
                   body: { error: 'too_many_concurrent_verifications',
                           message: 'Too many API key checks are already running for this account from this ' \
                                    'address. Try again in 1 second.',
                           retryAfter: 1 }.to_json },
                 { status: 200, body: { user: { id: 'user_1' } }.to_json }
               )

        expect(client.get('/account')).to eq('user' => { 'id' => 'user_1' })
        expect(stub).to have_been_requested.twice
        expect(client).to have_received(:sleep).with(1).once
      end

      it 'raises a failed API key lockout at once, without waiting it out' do
        allow(client).to receive(:sleep)
        stub = stub_request(:get, "#{base_url}/account")
               .to_return(status: 429, headers: { 'Retry-After' => '240' },
                          body: { error: 'too_many_failed_key_attempts',
                                  message: 'Too many failed API key attempts. Try again in 240 seconds.',
                                  retryAfter: 240 }.to_json)

        expect { client.get('/account') }.to raise_error(Sendly::RateLimitError) { |e|
          expect(e.retry_after).to eq(240)
          expect(e.response_body['error']).to eq('too_many_failed_key_attempts')
          expect(e.message).to eq('Too many failed API key attempts. Try again in 240 seconds.')
        }
        expect(stub).to have_been_requested.once
        expect(client).not_to have_received(:sleep)
      end

      it 'waits out the per-minute provisioning limit and retries with the same key' do
        allow(client).to receive(:sleep)
        keys = []
        stub = stub_request(:post, "#{base_url}/enterprise/workspaces/provision")
               .with { |request| keys << request.headers['Idempotency-Key'] }
               .to_return(
                 { status: 429,
                   body: { error: 'provision_rate_limit',
                           message: 'Max 120 provisions per minute.',
                           retryAfter: 42 }.to_json },
                 { status: 201, body: { workspace: { id: 'ws_1', name: 'Acme' } }.to_json }
               )

        expect(client.post('/enterprise/workspaces/provision', { name: 'Acme' }))
          .to eq('workspace' => { 'id' => 'ws_1', 'name' => 'Acme' })
        expect(stub).to have_been_requested.twice
        expect(client).to have_received(:sleep).with(42).once
        expect(keys.uniq.size).to eq(1)
      end

      it 'raises the hourly provisioning limit at once, with its retry_after' do
        allow(client).to receive(:sleep)
        stub = stub_request(:post, "#{base_url}/enterprise/workspaces/provision")
               .to_return(status: 429,
                          body: { error: 'provision_rate_limit',
                                  message: 'Max 1000 provisions per hour.',
                                  retryAfter: 3100 }.to_json)

        expect { client.post('/enterprise/workspaces/provision', { name: 'Acme' }) }
          .to raise_error(Sendly::RateLimitError) { |e| expect(e.retry_after).to eq(3100) }
        expect(stub).to have_been_requested.once
        expect(client).not_to have_received(:sleep)
      end

      it 'raises a rate limit longer than a minute at once' do
        allow(client).to receive(:sleep)
        stub = stub_request(:post, "#{base_url}/verify")
               .to_return(status: 429,
                          body: { error: 'rate_limit_exceeded',
                                  message: 'Too many OTPs sent to this phone number. Max 5 per 10 minutes.',
                                  retryAfter: 600 }.to_json)

        expect { client.post('/verify', { to: '+14155552673' }) }
          .to raise_error(Sendly::RateLimitError) { |e| expect(e.retry_after).to eq(600) }
        expect(stub).to have_been_requested.once
        expect(client).not_to have_received(:sleep)
      end

      it 'raises a failed API key lockout on an upload at once' do
        allow(client).to receive(:sleep)
        stub = stub_request(:post, "#{base_url}/media")
               .to_return(status: 429, headers: { 'Retry-After' => '240' },
                          body: { error: 'too_many_failed_key_attempts',
                                  message: 'Too many failed API key attempts. Try again in 240 seconds.',
                                  retryAfter: 240 }.to_json)

        expect { client.post_multipart('/media', StringIO.new('fake-image')) }
          .to raise_error(Sendly::RateLimitError)
        expect(stub).to have_been_requested.once
        expect(client).not_to have_received(:sleep)
      end

      it 'still waits out an ordinary rate limit' do
        allow(client).to receive(:sleep)
        stub = stub_request(:get, "#{base_url}/account")
               .to_return(
                 { status: 429, body: { error: 'rate_limit_exceeded',
                                        message: 'Rate limit exceeded. Limit: 60 requests per minute.',
                                        retryAfter: 7 }.to_json },
                 { status: 200, body: { user: { id: 'user_1' } }.to_json }
               )

        expect(client.get('/account')).to eq('user' => { 'id' => 'user_1' })
        expect(stub).to have_been_requested.twice
        expect(client).to have_received(:sleep).with(7).once
      end

      it 'waits out a 429 that carries only a Retry-After header and retries with the same key' do
        allow(client).to receive(:sleep)
        keys = []
        stub = stub_request(:post, "#{base_url}/messages")
               .with { |request| keys << request.headers['Idempotency-Key'] }
               .to_return(
                 { status: 429, headers: { 'Retry-After' => '2' }, body: '' },
                 { status: 200, body: message_response.to_json }
               )

        expect(client.post('/messages', {})['id']).to eq('msg_abc123')
        expect(stub).to have_been_requested.twice
        expect(client).to have_received(:sleep).with(2).once
        expect(keys.uniq.size).to eq(1)
      end

      it 'reads the Retry-After header before the body' do
        stub_request(:get, "#{base_url}/account")
          .to_return(status: 429, headers: { 'Retry-After' => '240' },
                     body: { error: 'too_many_failed_key_attempts', retryAfter: 239 }.to_json)

        expect { client.get('/account') }
          .to raise_error(Sendly::RateLimitError) { |e| expect(e.retry_after).to eq(240) }
      end

      it 'falls back to the body when the Retry-After header is not a number of seconds' do
        stub_request(:get, "#{base_url}/account")
          .to_return(status: 429, headers: { 'Retry-After' => 'Wed, 21 Oct 2026 07:28:00 GMT' },
                     body: { error: 'too_many_failed_key_attempts', retryAfter: 240 }.to_json)

        expect { client.get('/account') }
          .to raise_error(Sendly::RateLimitError) { |e| expect(e.retry_after).to eq(240) }
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
