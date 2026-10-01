# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'

RSpec.describe Sendly::WhatsAppResource, 'extras' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:whatsapp) { client.whatsapp }
  let(:signup_id) { '5b0f6c2e-8d1a-4f3b-9c7e-2a4d6e8f0b13' }
  let(:waba_id) { '102290129340398' }
  let(:phone) { '+15555550123' }
  let(:encoded_phone) { '%2B15555550123' }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  def json(status, body, headers = {})
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' }.merge(headers) }
  end

  def verifying_signup(overrides = {})
    {
      'id' => signup_id,
      'status' => 'verifying',
      'phoneNumber' => phone,
      'businessAccountId' => waba_id,
      'failureReasons' => nil,
      'verificationMethod' => 'sms',
      'verificationAttemptsRemaining' => 5,
      'updatedAt' => '2026-10-01T10:00:00.000Z'
    }.merge(overrides)
  end

  def active_signup
    {
      'id' => signup_id,
      'status' => 'active',
      'phoneNumber' => phone,
      'businessAccountId' => waba_id,
      'failureReasons' => nil,
      'updatedAt' => '2026-10-01T10:02:00.000Z'
    }
  end

  def profile_body(overrides = {})
    {
      'phoneNumber' => phone,
      'displayName' => 'Acme Coffee',
      'profilePhotoUrl' => 'https://cdn.example.com/acme.png',
      'category' => nil,
      'about' => 'Fresh roasted coffee, delivered.',
      'description' => nil,
      'email' => nil,
      'website' => nil,
      'address' => nil
    }.merge(overrides)
  end

  def components_body(overrides = {})
    {
      'phoneNumber' => phone,
      'iceBreakers' => ['Track my order', 'Opening hours'],
      'commands' => [{ 'command' => 'menu', 'description' => "See today's menu" }]
    }.merge(overrides)
  end

  describe 'signup statuses' do
    it 'includes verifying in both status vocabularies' do
      expect(Sendly::WhatsAppSignup::STATUSES).to include('verifying')
      expect(Sendly::WhatsAppSignupSession::STATUSES).to include('verifying')
    end
  end

  describe 'signup.create on an already-connected account' do
    it 'sends businessAccountId, verificationMethod and displayName and reads the verifying session' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup")
        .with(body: {
          phoneNumber: phone,
          businessAccountId: waba_id,
          verificationMethod: 'voice',
          displayName: 'Acme Coffee'
        }.to_json)
        .to_return(json(201, verifying_signup('verificationMethod' => 'voice')))

      signup = whatsapp.signup.create(phone_number: phone, business_account_id: waba_id,
                                      verification_method: 'voice', display_name: 'Acme Coffee')

      expect(stub).to have_been_requested
      expect(signup).to be_a(Sendly::WhatsAppSignupSession)
      expect(signup.id).to eq(signup_id)
      expect(signup.status).to eq('verifying')
      expect(signup.verifying?).to be true
      expect(signup.connect_url).to be_nil
      expect(signup.phone_number).to eq(phone)
      expect(signup.business_account_id).to eq(waba_id)
      expect(signup.verification_method).to eq('voice')
      expect(signup.verification_attempts_remaining).to eq(5)
      expect(signup.to_h).not_to have_key(:connect_url)
      expect(signup.to_h[:verification_method]).to eq('voice')
    end

    it 'sends only businessAccountId when the other options are left out' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup")
        .with(body: { phoneNumber: phone, businessAccountId: waba_id }.to_json)
        .to_return(json(200, verifying_signup))

      whatsapp.signup.create(phone_number: phone, business_account_id: waba_id)

      expect(stub).to have_been_requested
    end

    it 'sends a numeric business account id as a string' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup")
        .with(body: { phoneNumber: phone, businessAccountId: waba_id }.to_json)
        .to_return(json(201, verifying_signup))

      whatsapp.signup.create(phone_number: phone, business_account_id: waba_id.to_i)

      expect(stub).to have_been_requested
    end

    it 'add-by-code create keeps updatedAt (always sent with the projection)' do
      stub_request(:post, "#{base_url}/whatsapp/signup")
        .to_return(status: 201, headers: json_headers, body: {
          'id' => '6f1d2c7e-3a4b-4c5d-9e8f-0a1b2c3d4e5f', 'status' => 'verifying',
          'phoneNumber' => '+14155550142', 'businessAccountId' => '104996582519384',
          'failureReasons' => nil, 'verificationMethod' => 'sms',
          'verificationAttemptsRemaining' => 5, 'updatedAt' => '2026-10-01T14:02:55.311Z'
        }.to_json)
      signup = client.whatsapp.signup.create(phone_number: '+14155550142', business_account_id: '104996582519384')
      expect(signup.updated_at).to eq('2026-10-01T14:02:55.311Z')
    end

    it 'add-by-code create keeps failureReasons when the projected session already failed' do
      stub_request(:post, "#{base_url}/whatsapp/signup")
        .to_return(status: 200, headers: json_headers, body: {
          'id' => '6f1d2c7e-3a4b-4c5d-9e8f-0a1b2c3d4e5f', 'status' => 'failed',
          'phoneNumber' => '+14155550142', 'businessAccountId' => nil,
          'failureReasons' => ['verification_start_failed'], 'updatedAt' => '2026-10-01T14:02:56.002Z'
        }.to_json)
      signup = client.whatsapp.signup.create(phone_number: '+14155550142', business_account_id: '104996582519384')
      expect(signup.failed?).to be true
      expect(signup.failure_reasons).to eq(['verification_start_failed'])
    end

    it 'puts failure_reasons and updated_at in to_h, and leaves out a null failureReasons' do
      stub_request(:post, "#{base_url}/whatsapp/signup")
        .to_return(json(201, verifying_signup))
        .then.to_return(json(200, 'id' => signup_id, 'status' => 'failed', 'phoneNumber' => phone,
                                  'businessAccountId' => nil, 'failureReasons' => ['verification_start_failed'],
                                  'updatedAt' => '2026-10-01T10:00:01.000Z'))

      verifying = whatsapp.signup.create(phone_number: phone, business_account_id: waba_id)
      failed = whatsapp.signup.create(phone_number: phone, business_account_id: waba_id)

      expect(verifying.to_h).to eq(id: signup_id, status: 'verifying', phone_number: phone,
                                   business_account_id: waba_id, verification_method: 'sms',
                                   verification_attempts_remaining: 5, updated_at: '2026-10-01T10:00:00.000Z')
      expect(failed.to_h).to eq(id: signup_id, status: 'failed', phone_number: phone,
                                failure_reasons: ['verification_start_failed'],
                                updated_at: '2026-10-01T10:00:01.000Z')
    end

    it 'reads failure_reasons and updated_at from snake_case keys too' do
      session = Sendly::WhatsAppSignupSession.new('id' => signup_id, 'status' => 'failed',
                                                  'failure_reasons' => ['verification_start_failed'],
                                                  'updated_at' => '2026-10-01T10:00:01.000Z')

      expect(session.failure_reasons).to eq(['verification_start_failed'])
      expect(session.updated_at).to eq('2026-10-01T10:00:01.000Z')
    end

    it 'keeps the to_h of a Facebook signup to id, connect_url and status' do
      stub_request(:post, "#{base_url}/whatsapp/signup")
        .with(body: { phoneNumber: phone }.to_json)
        .to_return(json(201, 'id' => signup_id, 'connectUrl' => 'https://sendly.live/whatsapp/connect?token=wct_3f9a2c',
                             'status' => 'initiated'))

      signup = whatsapp.signup.create(phone_number: phone)

      expect(signup.to_h).to eq(id: signup_id, connect_url: 'https://sendly.live/whatsapp/connect?token=wct_3f9a2c',
                                status: 'initiated')
    end

    it 'raises NotFoundError for an account that is not connected in the workspace' do
      stub_request(:post, "#{base_url}/whatsapp/signup")
        .to_return(json(404, 'error' => 'whatsapp_business_account_not_found',
                             'message' => "There's no connected WhatsApp Business account with this id in your workspace."))

      expect { whatsapp.signup.create(phone_number: phone, business_account_id: waba_id) }
        .to raise_error(Sendly::NotFoundError) { |e|
          expect(e.response_body['error']).to eq('whatsapp_business_account_not_found')
        }
    end

    it 'raises ValidationError for a final 422 whatsapp_verification_start_failed without retrying' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup")
        .to_return(json(422, 'error' => 'whatsapp_verification_start_failed',
                             'message' => 'WhatsApp refused to verify this number.'))

      expect { whatsapp.signup.create(phone_number: phone, business_account_id: waba_id) }
        .to raise_error(Sendly::ValidationError)
      expect(stub).to have_been_requested.once
    end

    it 'raises ServerError for a 502 whatsapp_verification_start_failed at once, without starting another charged session' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup")
        .to_return(json(502, 'error' => 'whatsapp_verification_start_failed',
                             'message' => "WhatsApp couldn't start verifying this number. Any setup fee is refunded automatically. Please try again shortly."))

      expect { whatsapp.signup.create(phone_number: phone, business_account_id: waba_id) }
        .to raise_error(Sendly::ServerError) { |e|
          expect(e.status_code).to eq(502)
          expect(e.response_body['error']).to eq('whatsapp_verification_start_failed')
        }
      expect(stub).to have_been_requested.once
    end

    it 'raises any other 5xx at once too, without retrying' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup")
        .to_return(json(500, 'error' => 'internal_error',
                             'message' => 'Something went wrong asking WhatsApp for the code. Any setup fee is refunded automatically. Please try again.'))

      expect { whatsapp.signup.create(phone_number: phone, business_account_id: waba_id) }
        .to raise_error(Sendly::ServerError) { |e| expect(e.status_code).to eq(500) }
      expect(stub).to have_been_requested.once
    end

    it 'raises a timeout or a dropped connection at once, without starting another session' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup").to_timeout
      expect { whatsapp.signup.create(phone_number: phone, business_account_id: waba_id) }
        .to raise_error(Sendly::TimeoutError)
      expect(stub).to have_been_requested.once

      WebMock.reset!
      stub = stub_request(:post, "#{base_url}/whatsapp/signup").to_raise(Errno::ECONNRESET)
      expect { whatsapp.signup.create(phone_number: phone, business_account_id: waba_id) }
        .to raise_error(Sendly::NetworkError)
      expect(stub).to have_been_requested.once
    end

    it 'raises ValidationError for an empty business_account_id, without sending it as the Facebook signup' do
      expect { whatsapp.signup.create(phone_number: phone, business_account_id: '') }
        .to raise_error(Sendly::ValidationError, /business_account_id must be a non-empty string/)
    end

    it 'still retries a 5xx on the Facebook signup' do
      allow_any_instance_of(Sendly::Client).to receive(:sleep)
      stub = stub_request(:post, "#{base_url}/whatsapp/signup")
        .with(body: { phoneNumber: phone }.to_json)
        .to_return(json(503, { 'error' => 'whatsapp_unavailable',
                               'message' => 'WhatsApp connections are temporarily unavailable.',
                               'retryAfter' => 3600 }, 'Retry-After' => '3600'))
        .then.to_return(json(201, 'id' => signup_id, 'connectUrl' => 'https://sendly.live/whatsapp/connect/tok', 'status' => 'initiated'))

      signup = whatsapp.signup.create(phone_number: phone)

      expect(signup.connect_url).to eq('https://sendly.live/whatsapp/connect/tok')
      expect(stub).to have_been_requested.twice
    end

    it 'raises APIError 409 with the session id when the Facebook flow meets a verifying number' do
      stub_request(:post, "#{base_url}/whatsapp/signup")
        .with(body: { phoneNumber: phone }.to_json)
        .to_return(json(409, 'error' => 'whatsapp_verification_in_progress',
                             'message' => 'This number is already being added.', 'id' => signup_id))

      expect { whatsapp.signup.create(phone_number: phone) }
        .to raise_error(Sendly::APIError) { |e|
          expect(e.status_code).to eq(409)
          expect(e.response_body['id']).to eq(signup_id)
        }
    end
  end

  describe 'signup.get while verifying' do
    it 'reads the verification fields and the code once it has arrived' do
      stub_request_with_auth(:get, "/whatsapp/signup/#{signup_id}",
                             response_body: verifying_signup('verificationAttemptsRemaining' => 4,
                                                             'verificationCode' => '482913'))

      signup = whatsapp.signup.get(signup_id)

      expect(signup.verifying?).to be true
      expect(signup.business_account_id).to eq(waba_id)
      expect(signup.verification_method).to eq('sms')
      expect(signup.verification_attempts_remaining).to eq(4)
      expect(signup.verification_code).to eq('482913')
      expect(signup.to_h[:verification_code]).to eq('482913')
    end

    it 'leaves verification_code nil before the code arrives' do
      stub_request_with_auth(:get, "/whatsapp/signup/#{signup_id}",
                             response_body: verifying_signup('verificationCode' => nil))

      signup = whatsapp.signup.get(signup_id)

      expect(signup.verification_code).to be_nil
      expect(signup.to_h).not_to have_key(:verification_code)
    end

    it 'leaves the verification fields nil on a Facebook signup' do
      stub_request_with_auth(:get, "/whatsapp/signup/#{signup_id}", response_body: active_signup)

      signup = whatsapp.signup.get(signup_id)

      expect(signup.verifying?).to be false
      expect(signup.verification_method).to be_nil
      expect(signup.verification_attempts_remaining).to be_nil
      expect(signup.verification_code).to be_nil
    end
  end

  describe 'signup.verify' do
    it 'posts the code and returns the active signup' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/verify")
        .with(body: { code: '482913' }.to_json)
        .to_return(json(200, active_signup))

      signup = whatsapp.signup.verify(signup_id, code: '482913')

      expect(stub).to have_been_requested
      expect(signup).to be_a(Sendly::WhatsAppSignup)
      expect(signup.active?).to be true
      expect(signup.business_account_id).to eq(waba_id)
    end

    it 'raises ValidationError with attemptsRemaining for a wrong code' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/verify")
        .to_return(json(422, 'error' => 'whatsapp_verification_code_invalid',
                             'message' => "That code wasn't accepted. Check it, or request a new one.",
                             'attemptsRemaining' => 4))

      expect { whatsapp.signup.verify(signup_id, code: '000000') }
        .to raise_error(Sendly::ValidationError) { |e|
          expect(e.response_body['error']).to eq('whatsapp_verification_code_invalid')
          expect(e.response_body['attemptsRemaining']).to eq(4)
        }
      expect(stub).to have_been_requested.once
    end

    it 'raises APIError 409 once the session has failed on too many wrong codes' do
      stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/verify")
        .to_return(json(409, 'error' => 'whatsapp_verification_failed',
                             'message' => 'Too many wrong codes.'))

      expect { whatsapp.signup.verify(signup_id, code: '000000') }
        .to raise_error(Sendly::APIError) { |e| expect(e.status_code).to eq(409) }
    end

    it 'raises a 502 whatsapp_activation_pending at once, without submitting the code again' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/verify")
        .to_return(json(502, 'error' => 'whatsapp_activation_pending',
                             'message' => "WhatsApp accepted the code, but we couldn't finish connecting the number. Our team has been alerted; check back shortly."))

      expect { whatsapp.signup.verify(signup_id, code: '482913') }
        .to raise_error(Sendly::ServerError) { |e|
          expect(e.status_code).to eq(502)
          expect(e.response_body['error']).to eq('whatsapp_activation_pending')
        }
      expect(stub).to have_been_requested.once
    end

    it 'raises a 502 whatsapp_verification_unavailable at once, without retrying' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/verify")
        .to_return(json(502, 'error' => 'whatsapp_verification_unavailable',
                             'message' => "WhatsApp couldn't check the code right now. Please try again shortly."))

      expect { whatsapp.signup.verify(signup_id, code: '482913') }
        .to raise_error(Sendly::ServerError)
      expect(stub).to have_been_requested.once
    end

    it 'raises a timeout or a dropped connection at once, without submitting the code again' do
      path = "#{base_url}/whatsapp/signup/#{signup_id}/verify"
      stub = stub_request(:post, path).to_timeout
      expect { whatsapp.signup.verify(signup_id, code: '482913') }.to raise_error(Sendly::TimeoutError)
      expect(stub).to have_been_requested.once

      WebMock.reset!
      stub = stub_request(:post, path).to_raise(Errno::ECONNRESET)
      expect { whatsapp.signup.verify(signup_id, code: '482913') }.to raise_error(Sendly::NetworkError)
      expect(stub).to have_been_requested.once
    end

    it 'still waits out and retries an ordinary 429 the server never ran' do
      allow_any_instance_of(Sendly::Client).to receive(:sleep)
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/verify")
        .to_return(json(429, { 'error' => 'rate_limit_exceeded', 'message' => 'Too many requests', 'retryAfter' => 1 },
                        'Retry-After' => '1'))
        .then.to_return(json(200, active_signup))

      signup = whatsapp.signup.verify(signup_id, code: '482913')

      expect(signup.active?).to be true
      expect(stub).to have_been_requested.twice
    end

    it 'URL-encodes the signup id' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/a%2Fb/verify")
        .to_return(json(200, active_signup))

      whatsapp.signup.verify('a/b', code: '482913')

      expect(stub).to have_been_requested
    end

    it 'raises ValidationError before sending when id or code is missing' do
      expect { whatsapp.signup.verify(nil, code: '482913') }
        .to raise_error(Sendly::ValidationError, /id is required/)
      expect { whatsapp.signup.verify(signup_id, code: '') }
        .to raise_error(Sendly::ValidationError, /code is required/)
    end
  end

  describe 'signup.resend' do
    it 'posts an empty body by default and returns the signup' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/resend")
        .with(body: {}.to_json)
        .to_return(json(200, verifying_signup))

      signup = whatsapp.signup.resend(signup_id)

      expect(stub).to have_been_requested
      expect(signup).to be_a(Sendly::WhatsAppSignup)
      expect(signup.verifying?).to be true
    end

    it 'sends the verification method when given' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/resend")
        .with(body: { verificationMethod: 'voice' }.to_json)
        .to_return(json(200, verifying_signup('verificationMethod' => 'voice')))

      signup = whatsapp.signup.resend(signup_id, verification_method: 'voice')

      expect(stub).to have_been_requested
      expect(signup.verification_method).to eq('voice')
    end

    it 'raises RateLimitError with retry_after when asked too soon, without waiting' do
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/resend")
        .to_return(json(429, { 'error' => 'whatsapp_verification_resend_too_soon',
                               'message' => 'Wait 30 seconds before requesting another code.',
                               'retryAfter' => 30 }, 'Retry-After' => '30'))

      expect { whatsapp.signup.resend(signup_id) }
        .to raise_error(Sendly::RateLimitError) { |e|
          expect(e.retry_after).to eq(30)
          expect(e.response_body['error']).to eq('whatsapp_verification_resend_too_soon')
        }
      expect(stub).to have_been_requested.once
    end

    it 'retries a 502 whatsapp_verification_resend_failed like any 5xx' do
      allow_any_instance_of(Sendly::Client).to receive(:sleep)
      stub = stub_request(:post, "#{base_url}/whatsapp/signup/#{signup_id}/resend")
        .to_return(json(502, 'error' => 'whatsapp_verification_resend_failed',
                             'message' => "WhatsApp couldn't send another code right now. Please try again shortly."))
        .then.to_return(json(200, verifying_signup))

      signup = whatsapp.signup.resend(signup_id)

      expect(signup.verifying?).to be true
      expect(stub).to have_been_requested.twice
    end

    it 'raises ValidationError before sending when id is missing' do
      expect { whatsapp.signup.resend('') }
        .to raise_error(Sendly::ValidationError, /id is required/)
    end
  end

  describe 'senders.list' do
    it 'reads the business account, business name and calling fields' do
      stub_request_with_auth(:get, '/whatsapp/senders', response_body: {
        'senders' => [
          {
            'phoneNumber' => phone, 'displayName' => 'Acme Coffee', 'status' => 'active',
            'qualityRating' => 'GREEN', 'businessAccountId' => waba_id,
            'businessName' => 'Acme Coffee Ltd', 'callingEnabled' => true,
            'outboundCallingAllowed' => false, 'createdAt' => '2026-10-01T09:00:00.000Z'
          },
          {
            'phoneNumber' => '+15555550124', 'displayName' => nil, 'status' => 'pending',
            'qualityRating' => nil, 'businessAccountId' => nil, 'businessName' => nil,
            'callingEnabled' => false, 'outboundCallingAllowed' => false,
            'createdAt' => '2026-10-01T09:30:00.000Z'
          }
        ]
      })

      active, pending = whatsapp.senders.list[:senders]

      expect(active.business_account_id).to eq(waba_id)
      expect(active.business_name).to eq('Acme Coffee Ltd')
      expect(active.calling_enabled).to be true
      expect(active.calling_enabled?).to be true
      expect(active.outbound_calling_allowed).to be false
      expect(active.outbound_calling_allowed?).to be false
      expect(active.to_h).to include(business_account_id: waba_id, calling_enabled: true,
                                     outbound_calling_allowed: false)
      expect(pending.business_account_id).to be_nil
      expect(pending.business_name).to be_nil
      expect(pending.calling_enabled).to be false
    end
  end

  describe 'senders.upload_profile_photo' do
    let(:png) { "\x89PNG\r\n\x1A\n".b + ('x' * 64) }

    it 'uploads the photo as the multipart field "file" and returns the profile' do
      stub = stub_request(:post, "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo")
        .with { |req|
          req.headers['Content-Type'].start_with?('multipart/form-data; boundary=') &&
            req.body.include?('Content-Disposition: form-data; name="file"; filename="logo.png"') &&
            req.body.include?('Content-Type: image/png') &&
            req.body.b.include?(png)
        }
        .to_return(json(200, profile_body))

      profile = whatsapp.senders.upload_profile_photo(phone, StringIO.new(png),
                                                      content_type: 'image/png', filename: 'logo.png')

      expect(stub).to have_been_requested
      expect(profile).to be_a(Sendly::WhatsAppSenderProfile)
      expect(profile.profile_photo_url).to eq('https://cdn.example.com/acme.png')
    end

    it 'reads the photo from a file path' do
      path = File.join(Dir.tmpdir, "sendly-wa-photo-#{Process.pid}.png")
      File.binwrite(path, png)
      stub = stub_request(:post, "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo")
        .with { |req| req.body.b.include?(png) }
        .to_return(json(200, profile_body))

      whatsapp.senders.upload_profile_photo(phone, path, content_type: 'image/png')

      expect(stub).to have_been_requested
    ensure
      File.delete(path) if path && File.exist?(path)
    end

    it 'uploads a profile photo whose filename is not ASCII' do
      png = "\x89PNG\r\n\x1A\n".b + ("\xFF\x00".b * 8)
      stub = stub_request(:post, "#{base_url}/whatsapp/senders/%2B14155550123/profile/photo")
        .with { |req| req.body.b.include?(png) }
        .to_return(status: 200, headers: json_headers, body: {
          'phoneNumber' => '+14155550123', 'displayName' => nil, 'profilePhotoUrl' => nil, 'category' => nil,
          'about' => nil, 'description' => nil, 'email' => nil, 'website' => nil, 'address' => nil
        }.to_json)
      client.whatsapp.senders.upload_profile_photo('+14155550123', StringIO.new(png),
                                                   content_type: 'image/png', filename: 'café.png')
      expect(stub).to have_been_requested.once
    end

    it 'keeps the Content-Disposition of the "file" part a valid quoted-string when the filename has a quote' do
      png = "\x89PNG\r\n\x1A\n".b + ('x' * 8)
      disposition = nil
      stub_request(:post, "#{base_url}/whatsapp/senders/%2B14155550123/profile/photo")
        .with { |req| disposition = req.body.b[/^Content-Disposition:[^\r\n]*/]; true }
        .to_return(status: 200, headers: json_headers, body: { 'phoneNumber' => '+14155550123' }.to_json)
      client.whatsapp.senders.upload_profile_photo('+14155550123', StringIO.new(png), filename: 'my "logo".png')
      expect(disposition).to match(/\AContent-Disposition: form-data; name="file"; filename="(?:[^"\\\r\n]|\\.)*"\z/)
    end

    it 'keeps a line break in the filename from ending the headers of the "file" part' do
      sent = nil
      stub_request(:post, "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo")
        .with { |req| sent = req.body.b; true }
        .to_return(json(200, profile_body))

      whatsapp.senders.upload_profile_photo(phone, StringIO.new(png),
                                            content_type: 'image/png',
                                            filename: "logo\r\nContent-Type: text/plain\n.png")

      expect(sent).to include(
        "Content-Disposition: form-data; name=\"file\"; filename=\"logo%0D%0AContent-Type: text/plain%0A.png\"\r\n" \
        "Content-Type: image/png\r\n\r\n".b + png
      )
    end

    it 'raises APIError 413 for a photo over 5 MB' do
      stub_request(:post, "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo")
        .to_return(json(413, 'error' => 'whatsapp_profile_photo_too_large',
                             'message' => 'The photo must be 5 MB or smaller.'))

      expect { whatsapp.senders.upload_profile_photo(phone, StringIO.new(png)) }
        .to raise_error(Sendly::APIError) { |e|
          expect(e.status_code).to eq(413)
          expect(e.response_body['error']).to eq('whatsapp_profile_photo_too_large')
        }
    end

    it 'raises ValidationError for an image that is not JPEG or PNG' do
      stub_request(:post, "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo")
        .to_return(json(400, 'error' => 'whatsapp_profile_photo_invalid',
                             'message' => 'The photo must be a JPEG or PNG image.'))

      expect { whatsapp.senders.upload_profile_photo(phone, StringIO.new('GIF89a')) }
        .to raise_error(Sendly::ValidationError, /JPEG or PNG/)
    end

    it 'raises a 502 whatsapp_profile_update_failed at once, without uploading again' do
      stub = stub_request(:post, "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo")
        .to_return(json(502, 'error' => 'whatsapp_profile_update_failed',
                             'message' => "The photo couldn't be uploaded. WhatsApp needs a square JPEG or PNG at least 192 pixels wide. Please try again shortly."))

      expect { whatsapp.senders.upload_profile_photo(phone, StringIO.new(png), content_type: 'image/png') }
        .to raise_error(Sendly::ServerError) { |e|
          expect(e.status_code).to eq(502)
          expect(e.response_body['error']).to eq('whatsapp_profile_update_failed')
        }
      expect(stub).to have_been_requested.once
    end

    it 'raises a timeout or a dropped connection at once, without uploading again' do
      path = "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo"
      stub = stub_request(:post, path).to_timeout
      expect { whatsapp.senders.upload_profile_photo(phone, StringIO.new(png)) }.to raise_error(Sendly::TimeoutError)
      expect(stub).to have_been_requested.once

      WebMock.reset!
      stub = stub_request(:post, path).to_raise(Errno::ECONNRESET)
      expect { whatsapp.senders.upload_profile_photo(phone, StringIO.new(png)) }.to raise_error(Sendly::NetworkError)
      expect(stub).to have_been_requested.once
    end

    it 'raises ValidationError before sending when phone_number or file is missing' do
      expect { whatsapp.senders.upload_profile_photo(nil, StringIO.new(png)) }
        .to raise_error(Sendly::ValidationError, /phone_number is required/)
      expect { whatsapp.senders.upload_profile_photo(phone, nil) }
        .to raise_error(Sendly::ValidationError, /file is required/)
    end
  end

  describe 'senders.delete_profile_photo' do
    it 'deletes the photo and returns the profile without one' do
      stub = stub_request(:delete, "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo")
        .to_return(json(200, profile_body('profilePhotoUrl' => nil)))

      profile = whatsapp.senders.delete_profile_photo(phone)

      expect(stub).to have_been_requested
      expect(profile).to be_a(Sendly::WhatsAppSenderProfile)
      expect(profile.profile_photo_url).to be_nil
    end

    it 'raises NotFoundError when the number is not connected' do
      stub_request(:delete, "#{base_url}/whatsapp/senders/#{encoded_phone}/profile/photo")
        .to_return(json(404, 'error' => 'whatsapp_sender_not_connected',
                             'message' => "This number isn't connected to WhatsApp yet."))

      expect { whatsapp.senders.delete_profile_photo(phone) }.to raise_error(Sendly::NotFoundError)
    end
  end

  describe 'senders.get_conversational_components' do
    it 'returns the ice breakers and commands' do
      stub_request_with_auth(:get, "/whatsapp/senders/#{encoded_phone}/conversational_components",
                             response_body: components_body)

      components = whatsapp.senders.get_conversational_components(phone)

      expect(components).to be_a(Sendly::WhatsAppConversationalComponents)
      expect(components.phone_number).to eq(phone)
      expect(components.ice_breakers).to eq(['Track my order', 'Opening hours'])
      expect(components.commands.length).to eq(1)
      expect(components.commands.first).to be_a(Sendly::WhatsAppCommand)
      expect(components.commands.first.command).to eq('menu')
      expect(components.commands.first.description).to eq("See today's menu")
      expect(components.to_h).to eq(
        phone_number: phone,
        ice_breakers: ['Track my order', 'Opening hours'],
        commands: [{ command: 'menu', description: "See today's menu" }]
      )
    end

    it 'reads empty lists' do
      stub_request_with_auth(:get, "/whatsapp/senders/#{encoded_phone}/conversational_components",
                             response_body: components_body('iceBreakers' => [], 'commands' => []))

      components = whatsapp.senders.get_conversational_components(phone)

      expect(components.ice_breakers).to eq([])
      expect(components.commands).to eq([])
    end
  end

  describe 'senders.update_conversational_components' do
    let(:path) { "#{base_url}/whatsapp/senders/#{encoded_phone}/conversational_components" }

    it 'patches only the ice breakers when only they are given' do
      stub = stub_request(:patch, path)
        .with(body: { iceBreakers: ['Track my order'] }.to_json)
        .to_return(json(200, components_body('iceBreakers' => ['Track my order'])))

      components = whatsapp.senders.update_conversational_components(phone, ice_breakers: ['Track my order'])

      expect(stub).to have_been_requested
      expect(components.ice_breakers).to eq(['Track my order'])
    end

    it 'sends an empty list to clear one' do
      stub = stub_request(:patch, path)
        .with(body: { commands: [] }.to_json)
        .to_return(json(200, components_body('commands' => [])))

      components = whatsapp.senders.update_conversational_components(phone, commands: [])

      expect(stub).to have_been_requested
      expect(components.commands).to eq([])
    end

    it 'sends commands given as hashes or as the WhatsAppCommand objects a read returned' do
      stub = stub_request(:patch, path)
        .with(body: {
          iceBreakers: [],
          commands: [
            { command: 'menu', description: "See today's menu" },
            { command: 'hours', description: 'Opening hours' }
          ]
        }.to_json)
        .to_return(json(200, components_body))

      existing = Sendly::WhatsAppCommand.new('command' => 'menu', 'description' => "See today's menu")
      whatsapp.senders.update_conversational_components(
        phone,
        ice_breakers: [],
        commands: [existing, { command: 'hours', description: 'Opening hours' }]
      )

      expect(stub).to have_been_requested
    end

    it 'raises ValidationError with the API message for an invalid list' do
      stub_request(:patch, path)
        .to_return(json(400, 'error' => 'invalid_request',
                             'message' => 'At most 4 ice breakers are allowed.'))

      expect { whatsapp.senders.update_conversational_components(phone, ice_breakers: %w[a b c d e]) }
        .to raise_error(Sendly::ValidationError, /At most 4 ice breakers/)
    end

    it 'raises ValidationError before sending when neither list is given' do
      expect { whatsapp.senders.update_conversational_components(phone) }
        .to raise_error(Sendly::ValidationError, /ice_breakers, commands, or both/)
    end
  end

  describe 'senders.set_calling' do
    let(:path) { "#{base_url}/whatsapp/senders/#{encoded_phone}/calling" }

    it 'patches enabled and returns the calling settings' do
      stub = stub_request(:patch, path)
        .with(body: { enabled: true }.to_json)
        .to_return(json(200, 'phoneNumber' => phone, 'callingEnabled' => true,
                             'outboundCallingAllowed' => false))

      settings = whatsapp.senders.set_calling(phone, enabled: true)

      expect(stub).to have_been_requested
      expect(settings).to be_a(Sendly::WhatsAppCallingSettings)
      expect(settings.phone_number).to eq(phone)
      expect(settings.calling_enabled).to be true
      expect(settings.calling_enabled?).to be true
      expect(settings.outbound_calling_allowed).to be false
      expect(settings.outbound_calling_allowed?).to be false
      expect(settings.to_h).to eq(phone_number: phone, calling_enabled: true, outbound_calling_allowed: false)
    end

    it 'sends enabled false to switch calling off' do
      stub = stub_request(:patch, path)
        .with(body: { enabled: false }.to_json)
        .to_return(json(200, 'phoneNumber' => phone, 'callingEnabled' => false,
                             'outboundCallingAllowed' => false))

      settings = whatsapp.senders.set_calling(phone, enabled: false)

      expect(stub).to have_been_requested
      expect(settings.calling_enabled).to be false
    end

    it 'raises APIError 409 voice_not_enabled when the number has no voice' do
      stub_request(:patch, path)
        .to_return(json(409, 'error' => 'voice_not_enabled',
                             'message' => 'Turn on calls for this number first.'))

      expect { whatsapp.senders.set_calling(phone, enabled: true) }
        .to raise_error(Sendly::APIError) { |e|
          expect(e.status_code).to eq(409)
          expect(e.response_body['error']).to eq('voice_not_enabled')
        }
    end

    it 'raises ValidationError 422 whatsapp_calling_unavailable when Meta refuses' do
      stub_request(:patch, path)
        .to_return(json(422, 'error' => 'whatsapp_calling_unavailable',
                             'message' => "WhatsApp didn't allow calling on this number."))

      expect { whatsapp.senders.set_calling(phone, enabled: true) }
        .to raise_error(Sendly::ValidationError) { |e|
          expect(e.response_body['error']).to eq('whatsapp_calling_unavailable')
        }
    end
  end
end

RSpec.describe Sendly::Messages, 'WhatsApp send outcomes' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }

  it 'raises APIError 409 whatsapp_send_unconfirmed once, without retrying' do
    stub = stub_request(:post, "#{base_url}/messages")
      .to_return(status: 409, headers: { 'Content-Type' => 'application/json' }, body: {
        'error' => 'whatsapp_send_unconfirmed',
        'errorCode' => 'E024',
        'message' => "We couldn't confirm whether WhatsApp accepted this message."
      }.to_json)

    expect {
      client.messages.send(channel: 'whatsapp', to: '+15555550100', from: '+15555550123', text: 'Hi')
    }.to raise_error(Sendly::APIError) { |e|
      expect(e.status_code).to eq(409)
      expect(e.response_body['error']).to eq('whatsapp_send_unconfirmed')
    }
    expect(stub).to have_been_requested.once
  end
end
