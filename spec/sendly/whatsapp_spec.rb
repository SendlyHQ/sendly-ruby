# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::WhatsAppResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:whatsapp) { client.whatsapp }

  def signup_session_response(overrides = {})
    {
      'id' => 'was_abc123',
      'connectUrl' => 'https://sendly.live/whatsapp/connect/was_abc123',
      'status' => 'initiated'
    }.merge(overrides)
  end

  def signup_response(overrides = {})
    {
      'id' => 'was_abc123',
      'status' => 'active',
      'phoneNumber' => '+15559876543',
      'businessAccountId' => 'waba_123',
      'failureReasons' => nil,
      'updatedAt' => '2026-07-15T10:00:00Z'
    }.merge(overrides)
  end

  def sender_response(overrides = {})
    {
      'phoneNumber' => '+15559876543',
      'displayName' => 'Acme Inc',
      'status' => 'active',
      'qualityRating' => 'GREEN',
      'createdAt' => '2026-07-15T10:00:00Z'
    }.merge(overrides)
  end

  def profile_response(overrides = {})
    {
      'phoneNumber' => '+15559876543',
      'displayName' => 'Acme Inc',
      'profilePhotoUrl' => 'https://example.com/logo.png',
      'category' => 'FOOD_AND_GROCERY',
      'about' => 'Fresh roasted coffee, delivered.',
      'description' => 'Small-batch roaster shipping nationwide.',
      'email' => 'hello@acme.example',
      'website' => 'https://acme.example',
      'address' => '123 Bean St, Portland, OR'
    }.merge(overrides)
  end

  def template_response(overrides = {})
    {
      'id' => 'wat_abc123',
      'name' => 'order_shipped',
      'language' => 'en_US',
      'category' => 'UTILITY',
      'status' => 'PENDING',
      'qualityRating' => nil,
      'rejectionReason' => nil,
      'createdAt' => '2026-07-15T10:00:00Z',
      'updatedAt' => '2026-07-15T10:00:00Z'
    }.merge(overrides)
  end

  describe '#signup' do
    describe '#create' do
      it 'posts the number and returns a WhatsAppSignupSession' do
        stub = stub_request(:post, "#{base_url}/whatsapp/signup")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: { phoneNumber: '+15559876543' }.to_json
          )
          .to_return(status: 200, body: signup_session_response.to_json)

        signup = whatsapp.signup.create(phone_number: '+15559876543')

        expect(stub).to have_been_requested
        expect(signup).to be_a(Sendly::WhatsAppSignupSession)
        expect(signup.id).to eq('was_abc123')
        expect(signup.connect_url).to eq('https://sendly.live/whatsapp/connect/was_abc123')
        expect(signup.status).to eq('initiated')
        expect(signup.active?).to be false
      end

      it 'raises ValidationError when phone_number is nil' do
        expect { whatsapp.signup.create(phone_number: nil) }
          .to raise_error(Sendly::ValidationError, /phone_number is required/)
      end

      it 'raises ValidationError when phone_number is empty' do
        expect { whatsapp.signup.create(phone_number: '') }
          .to raise_error(Sendly::ValidationError, /phone_number is required/)
      end
    end

    describe '#get' do
      it 'retrieves a signup by id' do
        stub_request_with_auth(:get, '/whatsapp/signup/was_abc123',
                               response_body: signup_response)

        signup = whatsapp.signup.get('was_abc123')

        expect(signup).to be_a(Sendly::WhatsAppSignup)
        expect(signup.id).to eq('was_abc123')
        expect(signup.status).to eq('active')
        expect(signup.phone_number).to eq('+15559876543')
        expect(signup.business_account_id).to eq('waba_123')
        expect(signup.active?).to be true
        expect(signup.failed?).to be false
      end

      it 'exposes failure_reasons on a failed signup' do
        stub_request_with_auth(:get, '/whatsapp/signup/was_abc123',
                               response_body: signup_response(
                                 'status' => 'failed',
                                 'businessAccountId' => nil,
                                 'failureReasons' => ['display name rejected']
                               ))

        signup = whatsapp.signup.get('was_abc123')

        expect(signup.failed?).to be true
        expect(signup.failure_reasons).to eq(['display name rejected'])
        expect(signup.business_account_id).to be_nil
      end

      it 'URL-encodes the signup id' do
        stub = stub_request(:get, "#{base_url}/whatsapp/signup/was%2Fweird")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: signup_response.to_json,
                     headers: { 'Content-Type' => 'application/json' })

        whatsapp.signup.get('was/weird')
        expect(stub).to have_been_requested
      end

      it 'raises ValidationError when id is nil' do
        expect { whatsapp.signup.get(nil) }
          .to raise_error(Sendly::ValidationError, /id is required/)
      end

      it 'raises NotFoundError on 404' do
        stub_request_with_auth(:get, '/whatsapp/signup/was_missing',
                               status: 404,
                               response_body: { message: 'Signup not found' })

        expect { whatsapp.signup.get('was_missing') }
          .to raise_error(Sendly::NotFoundError)
      end
    end
  end

  describe '#senders' do
    describe '#list' do
      it 'lists senders as WhatsAppSender models' do
        stub_request_with_auth(:get, '/whatsapp/senders',
                               response_body: {
                                 'senders' => [
                                   sender_response,
                                   sender_response('phoneNumber' => '+15551112222',
                                                   'displayName' => nil,
                                                   'status' => 'pending',
                                                   'qualityRating' => nil)
                                 ]
                               })

        result = whatsapp.senders.list
        senders = result[:senders]

        expect(senders.length).to eq(2)
        expect(senders.first).to be_a(Sendly::WhatsAppSender)
        expect(senders.first.phone_number).to eq('+15559876543')
        expect(senders.first.display_name).to eq('Acme Inc')
        expect(senders.first.quality_rating).to eq('GREEN')
        expect(senders.first.active?).to be true
        expect(senders.last.display_name).to be_nil
        expect(senders.last.pending?).to be true
      end

      it 'handles an empty sender list' do
        stub_request_with_auth(:get, '/whatsapp/senders',
                               response_body: { 'senders' => [] })

        expect(whatsapp.senders.list[:senders]).to be_empty
      end
    end

    describe '#get_profile' do
      it 'returns the business profile as a WhatsAppSenderProfile' do
        stub_request_with_auth(:get, '/whatsapp/senders/%2B15559876543/profile',
                               response_body: profile_response)

        profile = whatsapp.senders.get_profile('+15559876543')

        expect(profile).to be_a(Sendly::WhatsAppSenderProfile)
        expect(profile.phone_number).to eq('+15559876543')
        expect(profile.display_name).to eq('Acme Inc')
        expect(profile.profile_photo_url).to eq('https://example.com/logo.png')
        expect(profile.category).to eq('FOOD_AND_GROCERY')
        expect(profile.about).to eq('Fresh roasted coffee, delivered.')
        expect(profile.website).to eq('https://acme.example')
      end

      it 'leaves unset fields nil' do
        stub_request_with_auth(:get, '/whatsapp/senders/%2B15559876543/profile',
                               response_body: profile_response('about' => nil,
                                                               'description' => nil,
                                                               'address' => nil))

        profile = whatsapp.senders.get_profile('+15559876543')

        expect(profile.about).to be_nil
        expect(profile.description).to be_nil
        expect(profile.address).to be_nil
        expect(profile.to_h).not_to have_key(:about)
      end

      it 'raises NotFoundError when the number is not connected to WhatsApp' do
        stub_request_with_auth(:get, '/whatsapp/senders/%2B15559876543/profile',
                               status: 404,
                               response_body: {
                                 'error' => 'whatsapp_sender_not_connected',
                                 'message' => "This number isn't connected to WhatsApp yet."
                               })

        expect { whatsapp.senders.get_profile('+15559876543') }
          .to raise_error(Sendly::NotFoundError)
      end

      it 'raises ValidationError when phone_number is missing' do
        expect { whatsapp.senders.get_profile(nil) }
          .to raise_error(Sendly::ValidationError, /phone_number is required/)
      end
    end

    describe '#update_profile' do
      it 'patches only the given fields and returns the updated profile' do
        stub = stub_request(:patch, "#{base_url}/whatsapp/senders/%2B15559876543/profile")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: { about: 'Now roasting decaf too.', website: 'https://acme.example' }.to_json
          )
          .to_return(status: 200,
                     body: profile_response('about' => 'Now roasting decaf too.').to_json)

        profile = whatsapp.senders.update_profile('+15559876543',
                                                  about: 'Now roasting decaf too.',
                                                  website: 'https://acme.example')

        expect(stub).to have_been_requested
        expect(profile).to be_a(Sendly::WhatsAppSenderProfile)
        expect(profile.about).to eq('Now roasting decaf too.')
      end

      it 'raises ValidationError when no field is given' do
        expect { whatsapp.senders.update_profile('+15559876543') }
          .to raise_error(Sendly::ValidationError, /Provide at least one profile field/)
      end

      it 'raises ValidationError when phone_number is missing' do
        expect { whatsapp.senders.update_profile('', about: 'Hi') }
          .to raise_error(Sendly::ValidationError, /phone_number is required/)
      end
    end
  end

  describe '#templates' do
    describe '#list' do
      it 'lists templates as WhatsAppTemplate models' do
        stub_request_with_auth(:get, '/whatsapp/templates',
                               response_body: {
                                 'templates' => [
                                   template_response,
                                   template_response('id' => 'wat_def456',
                                                     'status' => 'APPROVED',
                                                     'qualityRating' => 'GREEN')
                                 ]
                               })

        templates = whatsapp.templates.list[:templates]

        expect(templates.length).to eq(2)
        expect(templates.first).to be_a(Sendly::WhatsAppTemplate)
        expect(templates.first.name).to eq('order_shipped')
        expect(templates.first.pending?).to be true
        expect(templates.last.approved?).to be true
        expect(templates.last.quality_rating).to eq('GREEN')
      end
    end

    describe '#create' do
      it 'posts the template and returns the pending WhatsAppTemplate' do
        stub = stub_request(:post, "#{base_url}/whatsapp/templates")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: {
              sender: '+15559876543',
              name: 'order_shipped',
              language: 'en_US',
              category: 'UTILITY',
              body: 'Hi {{1}}, your order {{2}} has shipped!',
              examples: { '1' => 'Sam', '2' => '#4821' }
            }.to_json
          )
          .to_return(status: 200, body: template_response.to_json)

        template = whatsapp.templates.create(
          sender: '+15559876543',
          name: 'order_shipped',
          language: 'en_US',
          category: 'UTILITY',
          body: 'Hi {{1}}, your order {{2}} has shipped!',
          examples: { '1' => 'Sam', '2' => '#4821' }
        )

        expect(stub).to have_been_requested
        expect(template).to be_a(Sendly::WhatsAppTemplate)
        expect(template.status).to eq('PENDING')
      end

      it 'includes header, footer, and buttons when given' do
        stub = stub_request(:post, "#{base_url}/whatsapp/templates")
          .with(
            body: {
              sender: '+15559876543',
              name: 'spring_sale',
              language: 'en_US',
              category: 'MARKETING',
              body: 'Our spring sale is on!',
              header: 'Spring Sale',
              footer: 'Reply STOP to opt out',
              buttons: [{ 'type' => 'quick_reply', 'text' => 'Stop promotions' }]
            }.to_json
          )
          .to_return(status: 200, body: template_response('name' => 'spring_sale').to_json)

        whatsapp.templates.create(
          sender: '+15559876543',
          name: 'spring_sale',
          language: 'en_US',
          category: 'MARKETING',
          body: 'Our spring sale is on!',
          header: 'Spring Sale',
          footer: 'Reply STOP to opt out',
          buttons: [{ 'type' => 'quick_reply', 'text' => 'Stop promotions' }]
        )

        expect(stub).to have_been_requested
      end

      it 'surfaces submission warnings' do
        stub_request_with_auth(:post, '/whatsapp/templates',
                               response_body: template_response(
                                 'warnings' => ['marketing template has no opt-out button']
                               ))

        template = whatsapp.templates.create(
          sender: '+15559876543',
          name: 'order_shipped',
          language: 'en_US',
          category: 'UTILITY',
          body: 'Your order has shipped!'
        )

        expect(template.warnings).to eq(['marketing template has no opt-out button'])
      end

      it 'raises ValidationError when sender is empty' do
        expect {
          whatsapp.templates.create(sender: '', name: 'x', language: 'en_US',
                                    category: 'UTILITY', body: 'Hello')
        }.to raise_error(Sendly::ValidationError, /sender is required/)
      end

      it 'raises ValidationError when body is empty' do
        expect {
          whatsapp.templates.create(sender: '+15559876543', name: 'x',
                                    language: 'en_US', category: 'UTILITY', body: '')
        }.to raise_error(Sendly::ValidationError, /body is required/)
      end
    end

    describe '#update' do
      it 'patches only the supplied fields' do
        stub = stub_request(:patch, "#{base_url}/whatsapp/templates/wat_abc123")
          .with(
            headers: { 'Authorization' => "Bearer #{valid_api_key}" },
            body: {
              body: 'Hi {{1}}, your order {{2}} is on its way!',
              examples: { '1' => 'Sam', '2' => '#4821' }
            }.to_json
          )
          .to_return(status: 200, body: template_response.to_json)

        template = whatsapp.templates.update('wat_abc123',
                                             body: 'Hi {{1}}, your order {{2}} is on its way!',
                                             examples: { '1' => 'Sam', '2' => '#4821' })

        expect(stub).to have_been_requested
        expect(template).to be_a(Sendly::WhatsAppTemplate)
        expect(template.pending?).to be true
      end

      it 'URL-encodes the template id' do
        stub = stub_request(:patch, "#{base_url}/whatsapp/templates/wat%2Fweird")
          .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
          .to_return(status: 200, body: template_response.to_json)

        whatsapp.templates.update('wat/weird', body: 'New body')
        expect(stub).to have_been_requested
      end

      it 'raises ValidationError when id is nil' do
        expect { whatsapp.templates.update(nil, body: 'x') }
          .to raise_error(Sendly::ValidationError, /id is required/)
      end
    end

    describe '#delete' do
      it 'deletes the template and returns the confirmation' do
        stub_request_with_auth(:delete, '/whatsapp/templates/wat_abc123',
                               response_body: { 'id' => 'wat_abc123', 'deleted' => true })

        result = whatsapp.templates.delete('wat_abc123')

        expect(result).to be_a(Sendly::WhatsAppTemplateDeletion)
        expect(result.id).to eq('wat_abc123')
        expect(result.deleted?).to be true
      end

      it 'raises ValidationError when id is empty' do
        expect { whatsapp.templates.delete('') }
          .to raise_error(Sendly::ValidationError, /id is required/)
      end

      it 'raises NotFoundError on 404' do
        stub_request_with_auth(:delete, '/whatsapp/templates/wat_missing',
                               status: 404,
                               response_body: { message: 'Template not found' })

        expect { whatsapp.templates.delete('wat_missing') }
          .to raise_error(Sendly::NotFoundError)
      end
    end
  end

  describe '#window' do
    it 'returns an open window with its expiry' do
      stub_request_with_auth(:get, '/whatsapp/window?from=%2B15559876543&to=%2B15551234567',
                             response_body: { 'open' => true, 'expiresAt' => '2026-07-16T10:00:00Z' })

      window = whatsapp.window(from: '+15559876543', to: '+15551234567')

      expect(window).to be_a(Sendly::WhatsAppWindow)
      expect(window.open?).to be true
      expect(window.expires_at).to eq('2026-07-16T10:00:00Z')
    end

    it 'returns a closed window with nil expiry' do
      stub_request_with_auth(:get, '/whatsapp/window?from=%2B15559876543&to=%2B15551234567',
                             response_body: { 'open' => false, 'expiresAt' => nil })

      window = whatsapp.window(from: '+15559876543', to: '+15551234567')

      expect(window.open?).to be false
      expect(window.expires_at).to be_nil
    end

    it 'raises ValidationError when from is missing' do
      expect { whatsapp.window(from: nil, to: '+15551234567') }
        .to raise_error(Sendly::ValidationError, /from is required/)
    end

    it 'raises ValidationError when to is missing' do
      expect { whatsapp.window(from: '+15559876543', to: '') }
        .to raise_error(Sendly::ValidationError, /to is required/)
    end
  end
end

RSpec.describe Sendly::Messages, 'WhatsApp sends' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:messages) { client.messages }

  def whatsapp_message_response(overrides = {})
    {
      'id' => 'msg_wa123',
      'channel' => 'whatsapp',
      'message_format' => 'whatsapp',
      'to' => '+15551234567',
      'from' => '+15559876543',
      'text' => 'Your table is ready!',
      'status' => 'queued',
      'segments' => 1,
      'creditsUsed' => 1,
      'whatsapp' => { 'kind' => 'text', 'messageId' => nil },
      'createdAt' => '2026-07-15T10:00:00Z'
    }.merge(overrides)
  end

  describe '#send with channel: whatsapp' do
    it 'sends free-form text and returns a WhatsAppMessage' do
      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: {
            channel: 'whatsapp',
            to: '+15551234567',
            from: '+15559876543',
            text: 'Your table is ready!'
          }.to_json
        )
        .to_return(status: 200, body: whatsapp_message_response.to_json)

      message = messages.send(
        channel: 'whatsapp',
        to: '+15551234567',
        from: '+15559876543',
        text: 'Your table is ready!'
      )

      expect(stub).to have_been_requested
      expect(message).to be_a(Sendly::WhatsAppMessage)
      expect(message.id).to eq('msg_wa123')
      expect(message.channel).to eq('whatsapp')
      expect(message.message_format).to eq('whatsapp')
      expect(message.segments).to eq(1)
      expect(message.credits_used).to eq(1)
      expect(message.whatsapp.kind).to eq('text')
      expect(message.whatsapp.message_id).to be_nil
    end

    it 'sends media with the text as its caption' do
      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          body: {
            channel: 'whatsapp',
            to: '+15551234567',
            from: '+15559876543',
            text: 'Here is your receipt',
            mediaUrls: ['https://example.com/receipt.pdf']
          }.to_json
        )
        .to_return(status: 200, body: whatsapp_message_response(
          'text' => nil,
          'whatsapp' => { 'kind' => 'media', 'messageId' => nil }
        ).to_json)

      message = messages.send(
        channel: 'whatsapp',
        to: '+15551234567',
        from: '+15559876543',
        text: 'Here is your receipt',
        media_urls: ['https://example.com/receipt.pdf']
      )

      expect(stub).to have_been_requested
      expect(message.whatsapp.kind).to eq('media')
      expect(message.text).to be_nil
    end

    it 'sends a template with variables and buttons' do
      template = {
        name: 'order_shipped',
        language: 'en_US',
        variables: { '1' => 'Acme Inc', '2' => '#4821' },
        buttons: [{ index: 0, variables: { '1' => '4821' } }]
      }

      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          body: {
            channel: 'whatsapp',
            to: '+15551234567',
            from: '+15559876543',
            template: template
          }.to_json
        )
        .to_return(status: 200, body: whatsapp_message_response(
          'text' => nil,
          'whatsapp' => {
            'kind' => 'template',
            'template' => { 'name' => 'order_shipped', 'language' => 'en_US', 'category' => 'utility' },
            'messageId' => nil
          }
        ).to_json)

      message = messages.send(
        channel: 'whatsapp',
        to: '+15551234567',
        from: '+15559876543',
        template: template
      )

      expect(stub).to have_been_requested
      expect(message.whatsapp.kind).to eq('template')
      expect(message.whatsapp.template).to eq(
        name: 'order_shipped', language: 'en_US', category: 'utility'
      )
    end

    it 'attaches metadata when given' do
      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          body: {
            channel: 'whatsapp',
            to: '+15551234567',
            from: '+15559876543',
            text: 'Hello!',
            metadata: { 'orderId' => '4821' }
          }.to_json
        )
        .to_return(status: 200, body: whatsapp_message_response.to_json)

      messages.send(
        channel: 'whatsapp',
        to: '+15551234567',
        from: '+15559876543',
        text: 'Hello!',
        metadata: { 'orderId' => '4821' }
      )

      expect(stub).to have_been_requested
    end

    it 'raises ValidationError when no text, media, or template is given' do
      expect {
        messages.send(channel: 'whatsapp', to: '+15551234567', from: '+15559876543')
      }.to raise_error(Sendly::ValidationError, /Provide 'text', 'media_urls', or 'template'/)
    end

    it 'raises ValidationError when from is missing' do
      expect {
        messages.send(channel: 'whatsapp', to: '+15551234567', text: 'Hello!')
      }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
    end

    it 'raises ValidationError when from is not E.164' do
      expect {
        messages.send(channel: 'whatsapp', to: '+15551234567', from: 'ACME', text: 'Hello!')
      }.to raise_error(Sendly::ValidationError, /Invalid phone number format/)
    end

    it 'leaves SMS sends unchanged when channel is omitted' do
      stub = stub_request(:post, "#{base_url}/messages")
        .with(body: { to: '+15551234567', text: 'Hello!' }.to_json)
        .to_return(status: 200, body: message_response.to_json)

      message = messages.send(to: '+15551234567', text: 'Hello!')

      expect(stub).to have_been_requested
      expect(message).to be_a(Sendly::Message)
    end
  end
end
