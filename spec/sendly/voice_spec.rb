# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Voice' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:voice) { client.voice }

  let(:auto_key_pattern) do
    /\Asendly-ruby-retry-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  end

  let(:number_id) { '5f0c1c2e-2a44-4d4b-9d51-0a9b0f6f4a11' }
  let(:agent_id) { '3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b' }

  let(:number_body) do
    {
      'id' => number_id, 'object' => 'voice_number', 'phoneNumber' => '+15555550188',
      'phoneNumberType' => 'local', 'countryCode' => 'US', 'isDefault' => true,
      'voiceEnabled' => true, 'voiceMode' => 'agent', 'agentId' => agent_id,
      'emergencyAddress' => {
        'status' => 'active',
        'address' => {
          'street' => '500 Example Ave', 'unit' => 'Suite 2', 'city' => 'Austin',
          'state' => 'TX', 'zip' => '78701', 'country' => 'US'
        }
      },
      'ratePerMinute' => { 'inbound' => 2, 'outbound' => 2, 'agent' => 10 }
    }
  end

  let(:agent_body) do
    {
      'id' => agent_id, 'object' => 'voice_agent', 'name' => 'Front desk', 'enabled' => true,
      'voice' => 'ashley', 'voiceLabel' => 'Ashley (US, warm)', 'language' => 'en-US',
      'greeting' => 'Thanks for calling Acme, how can I help?',
      'instructions' => 'Answer questions about opening hours.',
      'tools' => { 'sendSms' => false, 'transferTo' => nil }, 'canSendSms' => true,
      'callsHandled' => 12, 'avgDurationSecs' => 74,
      'createdAt' => '2026-09-14T17:00:00.000Z', 'updatedAt' => '2026-09-14T17:05:00.000Z'
    }
  end

  def json(status, body)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def capture(method, path, response)
    seen = []
    stub_request(method, "#{base_url}#{path}")
      .with { |req| seen << req }
      .to_return(response)
    seen
  end

  it 'exposes a memoised voice resource with numbers, agents and voices' do
    expect(voice).to be_a(Sendly::VoiceResource)
    expect(client.voice).to equal(voice)
    expect(voice.numbers).to be_a(Sendly::VoiceNumbersResource)
    expect(voice.agents).to be_a(Sendly::VoiceAgentsResource)
    expect(voice.voices).to be_a(Sendly::VoiceVoicesResource)
    expect(Sendly::VoiceNumber::VOICE_MODES).to eq(%w[none ring_dashboard agent])
  end

  it 'publishes the voice configuration error codes' do
    expect(Sendly::Call::ERROR_CODES).to include(
      'number_not_found', 'agent_required', 'agent_in_use', 'agent_limit', 'invalid_voice_mode',
      'invalid_address', 'e911_not_applicable', 'voice_attach_failed', 'carrier_refused'
    )
  end

  describe 'numbers' do
    it 'GETs /voice/numbers and unwraps data into VoiceNumbers' do
      stub_request_with_auth(:get, '/voice/numbers', response_body: {
        'data' => [number_body, number_body.merge('id' => 'other', 'emergencyAddress' => nil,
                                                  'voiceEnabled' => false, 'voiceMode' => 'none',
                                                  'agentId' => nil)]
      })

      list = voice.numbers.list

      expect(list).to be_a(Sendly::VoiceNumberList)
      expect(list.size).to eq(2)
      expect(list.data.length).to eq(2)
      expect(list.count(&:voice_enabled?)).to eq(1)

      number = list.first
      expect(number).to be_a(Sendly::VoiceNumber)
      expect(number.id).to eq(number_id)
      expect(number.object).to eq('voice_number')
      expect(number.phone_number).to eq('+15555550188')
      expect(number.phone_number_type).to eq('local')
      expect(number.country_code).to eq('US')
      expect(number.default?).to be true
      expect(number.voice_enabled?).to be true
      expect(number.voice_mode).to eq('agent')
      expect(number.agent_id).to eq(agent_id)
      expect(number.emergency_address).to be_a(Sendly::VoiceNumberEmergencyAddress)
      expect(number.emergency_address.status).to eq('active')
      expect(number.emergency_address.active?).to be true
      expect(number.emergency_address.address).to be_a(Sendly::EmergencyAddress)
      expect(number.emergency_address.address.street).to eq('500 Example Ave')
      expect(number.emergency_address.address.unit).to eq('Suite 2')
      expect(number.emergency_address.address.zip).to eq('78701')
      expect(number.rate_per_minute).to be_a(Sendly::VoiceNumberRates)
      expect(number.rate_per_minute.inbound).to eq(2)
      expect(number.rate_per_minute.outbound).to eq(2)
      expect(number.rate_per_minute.agent).to eq(10)
      expect(number.raw).to eq(number_body)
      expect(number.to_h).to eq(
        id: number_id, object: 'voice_number', phone_number: '+15555550188', phone_number_type: 'local',
        country_code: 'US', is_default: true, voice_enabled: true, voice_mode: 'agent', agent_id: agent_id,
        emergency_address: {
          status: 'active',
          address: { street: '500 Example Ave', unit: 'Suite 2', city: 'Austin', state: 'TX', zip: '78701',
                     country: 'US' }
        },
        rate_per_minute: { inbound: 2, outbound: 2, agent: 10 }
      )

      off = list.last
      expect(off.voice_enabled?).to be false
      expect(off.voice_mode).to eq('none')
      expect(off.agent_id).to be_nil
      expect(off.emergency_address).to be_nil
    end

    it 'reads an empty list' do
      stub_request_with_auth(:get, '/voice/numbers', response_body: { 'data' => [] })

      expect(voice.numbers.list).to be_empty
    end

    it 'percent-encodes the + of an E.164 number in the path' do
      expect(client).to receive(:get).with('/voice/numbers/%2B15555550188').and_call_original
      stub_request_with_auth(:get, '/voice/numbers/%2B15555550188', response_body: number_body)

      number = voice.numbers.get('+15555550188')

      expect(number.phone_number).to eq('+15555550188')
    end

    it 'looks a number up by id' do
      stub = stub_request_with_auth(:get, "/voice/numbers/#{number_id}", response_body: number_body)

      voice.numbers.get(number_id)

      expect(stub).to have_been_requested
    end

    it 'raises ValidationError before any request when number is blank' do
      expect { voice.numbers.get('') }.to raise_error(Sendly::ValidationError, 'number is required')
      expect { voice.numbers.get(nil) }.to raise_error(Sendly::ValidationError, 'number is required')
      expect { voice.numbers.update('  ', voice_enabled: true) }
        .to raise_error(Sendly::ValidationError, 'number is required')
      expect(a_request(:any, /voice/)).not_to have_been_made
    end

    it 'raises NotFoundError on 404 number_not_found' do
      stub_request(:get, "#{base_url}/voice/numbers/%2B15555550199")
        .to_return(json(404, 'error' => 'number_not_found', 'message' => "This number isn't in your workspace."))

      expect { voice.numbers.get('+15555550199') }
        .to raise_error(Sendly::NotFoundError, /isn't in your workspace/) { |e|
          expect(e.response_body['error']).to eq('number_not_found')
        }
    end

    describe 'update' do
      it 'PATCHes camelCase voiceEnabled, voiceMode and agentId without an auto Idempotency-Key' do
        expect(client).to receive(:patch).with('/voice/numbers/%2B15555550188', any_args).and_call_original
        seen = capture(:patch, '/voice/numbers/%2B15555550188', json(200, number_body))

        number = voice.numbers.update('+15555550188', voice_enabled: true, voice_mode: 'agent', agent_id: agent_id)

        expect(seen.length).to eq(1)
        expect(JSON.parse(seen[0].body)).to eq('voiceEnabled' => true, 'voiceMode' => 'agent', 'agentId' => agent_id)
        expect(seen[0].body).not_to include('voiceAgentId')
        expect(seen[0].headers).not_to have_key('Idempotency-Key')
        expect(number).to be_a(Sendly::VoiceNumber)
        expect(number.voice_mode).to eq('agent')
      end

      it 'sends only the fields given, a caller key verbatim, and null when agent_id is nil' do
        seen = capture(:patch, "/voice/numbers/#{number_id}", json(200, number_body))

        voice.numbers.update(number_id, voice_mode: 'ring_dashboard', idempotency_key: 'voice-mode-1')
        voice.numbers.update(number_id, agent_id: nil)

        expect(JSON.parse(seen[0].body)).to eq('voiceMode' => 'ring_dashboard')
        expect(seen[0].headers['Idempotency-Key']).to eq('voice-mode-1')
        expect(JSON.parse(seen[1].body)).to eq('agentId' => nil)
      end

      it 'raises APIError with status 409 on agent_disabled' do
        stub_request(:patch, "#{base_url}/voice/numbers/#{number_id}")
          .to_return(json(409, 'error' => 'agent_disabled',
                               'message' => 'That agent is switched off. Turn it on before pointing a number at it.'))

        expect { voice.numbers.update(number_id, voice_mode: 'agent', agent_id: agent_id) }
          .to raise_error(Sendly::APIError, /switched off/) { |e|
            expect(e.status_code).to eq(409)
          }
      end

      it 'raises ValidationError on 400 agent_required' do
        stub_request(:patch, "#{base_url}/voice/numbers/#{number_id}")
          .to_return(json(400, 'error' => 'agent_required', 'message' => 'Choose an agent to answer this number.'))

        expect { voice.numbers.update(number_id, voice_mode: 'agent') }
          .to raise_error(Sendly::ValidationError, /Choose an agent/)
      end

      it 'raises ServerError, not APIError, on 502 voice_attach_failed' do
        no_retry = Sendly::Client.new(api_key: valid_api_key, max_retries: 0)
        stub_request(:patch, "#{base_url}/voice/numbers/#{number_id}")
          .to_return(json(502, 'error' => 'voice_attach_failed',
                               'message' => "Couldn't switch voice on for this number. Try again in a moment."))

        expect { no_retry.voice.numbers.update(number_id, voice_enabled: true) }
          .to raise_error(Sendly::ServerError, /Couldn't switch voice on/) { |e|
            expect(e.status_code).to eq(502)
            expect(e).not_to be_a(Sendly::APIError)
          }
      end
    end

    describe 'register_emergency_address' do
      it 'POSTs the address to /voice/numbers/:number/emergency-address with an auto Idempotency-Key' do
        expect(client).to receive(:post)
          .with('/voice/numbers/%2B15555550188/emergency-address', any_args).and_call_original
        seen = capture(:post, '/voice/numbers/%2B15555550188/emergency-address', json(200, number_body))

        number = voice.numbers.register_emergency_address(
          '+15555550188', street: '500 Example Ave', unit: 'Suite 2', city: 'Austin', state: 'TX',
                          zip: '78701', country: 'US'
        )

        expect(JSON.parse(seen[0].body)).to eq(
          'street' => '500 Example Ave', 'unit' => 'Suite 2', 'city' => 'Austin', 'state' => 'TX',
          'zip' => '78701', 'country' => 'US'
        )
        expect(seen[0].headers['Idempotency-Key']).to match(auto_key_pattern)
        expect(number.emergency_address.address.city).to eq('Austin')
      end

      it 'omits unit and country when they are not given and sends a caller key verbatim' do
        seen = capture(:post, "/voice/numbers/#{number_id}/emergency-address", json(200, number_body))

        voice.numbers.register_emergency_address(
          number_id, street: '500 Example Ave', city: 'Austin', state: 'TX', zip: '78701',
                     idempotency_key: 'e911-1'
        )

        expect(JSON.parse(seen[0].body)).to eq(
          'street' => '500 Example Ave', 'city' => 'Austin', 'state' => 'TX', 'zip' => '78701'
        )
        expect(seen[0].headers['Idempotency-Key']).to eq('e911-1')
      end

      it 'raises ValidationError before any request when a required field is blank' do
        address = { street: '500 Example Ave', city: 'Austin', state: 'TX', zip: '78701' }

        %i[street city state zip].each do |field|
          expect { voice.numbers.register_emergency_address(number_id, **address, field => ' ') }
            .to raise_error(Sendly::ValidationError, "#{field} is required")
        end
        expect { voice.numbers.register_emergency_address(nil, **address) }
          .to raise_error(Sendly::ValidationError, 'number is required')
        expect(a_request(:post, /emergency-address/)).not_to have_been_made
      end

      it 'raises ValidationError on 422 invalid_address and keeps the suggested address' do
        suggested = { 'street' => '500 Example Avenue', 'city' => 'Austin', 'state' => 'TX', 'zip' => '78701',
                      'country' => 'US' }
        stub_request(:post, "#{base_url}/voice/numbers/#{number_id}/emergency-address")
          .to_return(json(422, 'error' => 'invalid_address', 'message' => "We couldn't validate that address.",
                               'suggested' => suggested))

        expect do
          voice.numbers.register_emergency_address(number_id, street: '500 Example Ave', city: 'Austin',
                                                              state: 'TX', zip: '78701')
        end.to raise_error(Sendly::ValidationError) { |e|
          expect(e.response_body['error']).to eq('invalid_address')
          expect(e.response_body['suggested']).to eq(suggested)
        }
      end
    end
  end

  describe 'agents' do
    it 'GETs /voice/agents and unwraps data into VoiceAgents' do
      stub_request_with_auth(:get, '/voice/agents', response_body: { 'data' => [agent_body] })

      list = voice.agents.list

      expect(list).to be_a(Sendly::VoiceAgentList)
      expect(list.length).to eq(1)
      agent = list.first
      expect(agent).to be_a(Sendly::VoiceAgent)
      expect(agent.id).to eq(agent_id)
      expect(agent.object).to eq('voice_agent')
      expect(agent.name).to eq('Front desk')
      expect(agent.enabled?).to be true
      expect(agent.voice).to eq('ashley')
      expect(agent.voice_label).to eq('Ashley (US, warm)')
      expect(agent.language).to eq('en-US')
      expect(agent.greeting).to eq('Thanks for calling Acme, how can I help?')
      expect(agent.instructions).to eq('Answer questions about opening hours.')
      expect(agent.tools).to be_a(Sendly::VoiceAgentTools)
      expect(agent.tools.send_sms?).to be false
      expect(agent.tools.transfer_to).to be_nil
      expect(agent.can_send_sms?).to be true
      expect(agent.calls_handled).to eq(12)
      expect(agent.avg_duration_secs).to eq(74)
      expect(agent.created_at).to eq('2026-09-14T17:00:00.000Z')
      expect(agent.updated_at).to eq('2026-09-14T17:05:00.000Z')
      expect(agent.to_h).to eq(
        id: agent_id, object: 'voice_agent', name: 'Front desk', enabled: true, voice: 'ashley',
        voice_label: 'Ashley (US, warm)', language: 'en-US', greeting: 'Thanks for calling Acme, how can I help?',
        instructions: 'Answer questions about opening hours.', tools: { send_sms: false }, can_send_sms: true,
        calls_handled: 12, avg_duration_secs: 74, created_at: '2026-09-14T17:00:00.000Z',
        updated_at: '2026-09-14T17:05:00.000Z'
      )
    end

    describe 'create' do
      it 'POSTs /voice/agents with camelCase tools and an auto Idempotency-Key, and maps the 201' do
        seen = capture(:post, '/voice/agents', json(201, agent_body.merge(
          'tools' => { 'sendSms' => true, 'transferTo' => '+15125550142' }
        )))

        agent = voice.agents.create(
          name: 'Front desk', enabled: true, voice: 'ashley', language: 'en-US',
          greeting: 'Thanks for calling Acme, how can I help?',
          instructions: 'Answer questions about opening hours.',
          tools: { send_sms: true, transfer_to: '+15125550142' }
        )

        expect(JSON.parse(seen[0].body)).to eq(
          'name' => 'Front desk', 'enabled' => true, 'voice' => 'ashley', 'language' => 'en-US',
          'greeting' => 'Thanks for calling Acme, how can I help?',
          'instructions' => 'Answer questions about opening hours.',
          'tools' => { 'sendSms' => true, 'transferTo' => '+15125550142' }
        )
        expect(seen[0].headers['Idempotency-Key']).to match(auto_key_pattern)
        expect(agent.tools.send_sms?).to be true
        expect(agent.tools.transfer_to).to eq('+15125550142')
      end

      it 'sends only name when nothing else is given and passes camelCase tool keys through' do
        seen = capture(:post, '/voice/agents', json(201, agent_body))

        voice.agents.create(name: 'Front desk')
        voice.agents.create(name: 'Front desk', tools: { 'sendSms' => false }, idempotency_key: 'agent-1')

        expect(JSON.parse(seen[0].body)).to eq('name' => 'Front desk')
        expect(JSON.parse(seen[1].body)).to eq('name' => 'Front desk', 'tools' => { 'sendSms' => false })
        expect(seen[1].headers['Idempotency-Key']).to eq('agent-1')
      end

      it 'raises ValidationError before any request when name is blank' do
        expect { voice.agents.create(name: '') }.to raise_error(Sendly::ValidationError, 'name is required')
        expect { voice.agents.create(name: nil) }.to raise_error(Sendly::ValidationError, 'name is required')
        expect(a_request(:post, "#{base_url}/voice/agents")).not_to have_been_made
      end

      it 'raises APIError with status 409 on agent_limit' do
        stub_request(:post, "#{base_url}/voice/agents")
          .to_return(json(409, 'error' => 'agent_limit', 'message' => "You've reached the agent limit for this workspace."))

        expect { voice.agents.create(name: 'Front desk') }
          .to raise_error(Sendly::APIError, /agent limit/) { |e|
            expect(e.status_code).to eq(409)
          }
      end

      it 'raises NotFoundError while voice is not enabled for the workspace' do
        stub_request(:post, "#{base_url}/voice/agents")
          .to_return(json(404, 'error' => 'voice_not_enabled', 'message' => 'Voice is not enabled for your account.'))

        expect { voice.agents.create(name: 'Front desk') }.to raise_error(Sendly::NotFoundError, /not enabled/)
      end
    end

    it 'GETs /voice/agents/:id with the id percent-encoded and raises ValidationError when it is blank' do
      stub = stub_request_with_auth(:get, '/voice/agents/agent%2Fwith+space', response_body: agent_body)

      agent = voice.agents.get('agent/with space')

      expect(stub).to have_been_requested
      expect(agent.name).to eq('Front desk')
      expect { voice.agents.get('') }.to raise_error(Sendly::ValidationError, 'Agent ID is required')
      expect { voice.agents.get(nil) }.to raise_error(Sendly::ValidationError, 'Agent ID is required')
    end

    it 'PATCHes /voice/agents/:id with only the fields given and null for a cleared transfer number' do
      seen = capture(:patch, "/voice/agents/#{agent_id}", json(200, agent_body.merge('greeting' => 'Hi there')))

      agent = voice.agents.update(agent_id, greeting: 'Hi there', tools: { transfer_to: nil })

      expect(JSON.parse(seen[0].body)).to eq('greeting' => 'Hi there', 'tools' => { 'transferTo' => nil })
      expect(seen[0].headers).not_to have_key('Idempotency-Key')
      expect(agent.greeting).to eq('Hi there')
    end

    describe 'delete' do
      it 'DELETEs /voice/agents/:id and maps the confirmation' do
        seen = capture(:delete, "/voice/agents/#{agent_id}",
                       json(200, 'id' => agent_id, 'object' => 'voice_agent', 'deleted' => true))

        result = voice.agents.delete(agent_id)
        voice.agents.delete(agent_id, idempotency_key: 'delete-1')

        expect(result).to be_a(Sendly::DeletedVoiceAgent)
        expect(result.id).to eq(agent_id)
        expect(result.object).to eq('voice_agent')
        expect(result.deleted?).to be true
        expect(result.to_h).to eq(id: agent_id, object: 'voice_agent', deleted: true)
        expect(seen[0].headers).not_to have_key('Idempotency-Key')
        expect(seen[1].headers['Idempotency-Key']).to eq('delete-1')
      end

      it 'raises APIError with status 409 on agent_in_use and keeps the numbers' do
        stub_request(:delete, "#{base_url}/voice/agents/#{agent_id}")
          .to_return(json(409, 'error' => 'agent_in_use',
                               'message' => 'This agent answers 1 number. Point it elsewhere first.',
                               'numbers' => ['+15555550188']))

        expect { voice.agents.delete(agent_id) }
          .to raise_error(Sendly::APIError, /answers 1 number/) { |e|
            expect(e.status_code).to eq(409)
            expect(e.response_body['error']).to eq('agent_in_use')
            expect(e.response_body['numbers']).to eq(['+15555550188'])
          }
      end

      it 'raises NotFoundError on 404 agent_not_found' do
        stub_request(:delete, "#{base_url}/voice/agents/#{agent_id}")
          .to_return(json(404, 'error' => 'agent_not_found', 'message' => 'That agent was already removed.'))

        expect { voice.agents.delete(agent_id) }.to raise_error(Sendly::NotFoundError, /already removed/)
      end
    end
  end

  describe 'voices' do
    it 'GETs /voice/voices and unwraps data into Voices' do
      stub_request_with_auth(:get, '/voice/voices', response_body: {
        'data' => [
          { 'id' => 'ashley', 'label' => 'Ashley (US, warm)', 'language' => 'en' },
          { 'id' => 'marcus', 'label' => 'Marcus (US, calm)', 'language' => 'en' }
        ]
      })

      list = voice.voices.list

      expect(list).to be_a(Sendly::VoiceList)
      expect(list.map(&:id)).to eq(%w[ashley marcus])
      expect(list.first).to be_a(Sendly::Voice)
      expect(list.first.label).to eq('Ashley (US, warm)')
      expect(list.last.language).to eq('en')
      expect(list.first.to_h).to eq(id: 'ashley', label: 'Ashley (US, warm)', language: 'en')
    end
  end
end
