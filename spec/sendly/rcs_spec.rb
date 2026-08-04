# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::RcsResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:rcs) { client.rcs }

  def agent_response(overrides = {})
    {
      'id' => 'rca_abc123',
      'name' => 'Acme Coffee',
      'status' => 'approved',
      'useCase' => 'PROMOTION',
      'sendable' => true,
      'createdAt' => '2026-07-15T10:00:00Z'
    }.merge(overrides)
  end

  it 'is reachable from the client and memoized' do
    expect(client.rcs).to be_a(Sendly::RcsResource)
    expect(client.rcs).to equal(client.rcs)
    expect(client.rcs.agents).to be_a(Sendly::RcsAgentsResource)
  end

  describe '#agents' do
    describe '#list' do
      it 'lists agents as RcsAgent models' do
        stub_request_with_auth(:get, '/rcs/agents',
                               response_body: {
                                 'agents' => [
                                   agent_response,
                                   agent_response('id' => 'rca_def456',
                                                  'name' => 'Acme Support',
                                                  'status' => 'submitted',
                                                  'useCase' => nil,
                                                  'sendable' => false)
                                 ]
                               })

        agents = rcs.agents.list[:agents]

        expect(agents.length).to eq(2)
        expect(agents.first).to be_a(Sendly::RcsAgent)
        expect(agents.first.id).to eq('rca_abc123')
        expect(agents.first.name).to eq('Acme Coffee')
        expect(agents.first.use_case).to eq('PROMOTION')
        expect(agents.first.approved?).to be true
        expect(agents.first.sendable?).to be true
        expect(agents.last.status).to eq('submitted')
        expect(agents.last.use_case).to be_nil
        expect(agents.last.sendable?).to be false
        expect(agents.last.approved?).to be false
      end

      it 'handles an empty agent list' do
        stub_request_with_auth(:get, '/rcs/agents', response_body: { 'agents' => [] })

        expect(rcs.agents.list[:agents]).to be_empty
      end

      it 'raises NotFoundError while the channel is not enabled for the account' do
        stub_request_with_auth(:get, '/rcs/agents',
                               status: 404,
                               response_body: { 'error' => 'not_found' })

        expect { rcs.agents.list }.to raise_error(Sendly::NotFoundError)
      end
    end
  end

  describe '#capability' do
    it 'returns a capable recipient with its feature tags' do
      stub_request_with_auth(:get, '/rcs/capability?to=%2B15551234567',
                             response_body: {
                               'to' => '+15551234567',
                               'agentId' => 'rca_abc123',
                               'capable' => true,
                               'features' => %w[RICHCARD_STANDALONE ACTION_OPEN_URL]
                             })

      capability = rcs.capability(to: '+15551234567')

      expect(capability).to be_a(Sendly::RcsCapability)
      expect(capability.to).to eq('+15551234567')
      expect(capability.agent_id).to eq('rca_abc123')
      expect(capability.capable?).to be true
      expect(capability.features).to eq(%w[RICHCARD_STANDALONE ACTION_OPEN_URL])
    end

    it 'returns an incapable recipient with no features' do
      stub_request_with_auth(:get, '/rcs/capability?to=%2B15551234567',
                             response_body: {
                               'to' => '+15551234567',
                               'agentId' => 'rca_abc123',
                               'capable' => false,
                               'features' => []
                             })

      capability = rcs.capability(to: '+15551234567')

      expect(capability.capable?).to be false
      expect(capability.features).to be_empty
    end

    it 'passes agent_id when the workspace has more than one agent' do
      stub = stub_request_with_auth(:get, '/rcs/capability?to=%2B15551234567&agentId=rca_def456',
                                    response_body: {
                                      'to' => '+15551234567',
                                      'agentId' => 'rca_def456',
                                      'capable' => true,
                                      'features' => []
                                    })

      capability = rcs.capability(to: '+15551234567', agent_id: 'rca_def456')

      expect(stub).to have_been_requested
      expect(capability.agent_id).to eq('rca_def456')
    end

    it 'raises ValidationError when to is missing' do
      expect { rcs.capability(to: nil) }
        .to raise_error(Sendly::ValidationError, /to is required/)
    end

    it 'raises ValidationError when to is empty' do
      expect { rcs.capability(to: '') }
        .to raise_error(Sendly::ValidationError, /to is required/)
    end
  end
end

RSpec.describe Sendly::Messages, 'RCS sends' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:messages) { client.messages }

  def rcs_message_response(overrides = {})
    {
      'id' => 'msg_rcs123',
      'channel' => 'rcs',
      'message_format' => 'rcs',
      'to' => '+15551234567',
      'from' => 'Acme Coffee',
      'text' => 'Your order has shipped!',
      'status' => 'sent',
      'segments' => 1,
      'creditsUsed' => 2,
      'rcs' => { 'kind' => 'text', 'agentId' => 'rca_abc123', 'agentName' => 'Acme Coffee' },
      'createdAt' => '2026-07-15T10:00:00Z',
      'metadata' => {}
    }.merge(overrides)
  end

  describe '#send with channel: rcs' do
    it 'sends text and returns an RcsMessage' do
      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: {
            channel: 'rcs',
            to: '+15551234567',
            text: 'Your order has shipped!'
          }.to_json
        )
        .to_return(status: 201, body: rcs_message_response.to_json)

      message = messages.send(
        channel: 'rcs',
        to: '+15551234567',
        text: 'Your order has shipped!'
      )

      expect(stub).to have_been_requested
      expect(message).to be_a(Sendly::RcsMessage)
      expect(message.id).to eq('msg_rcs123')
      expect(message.channel).to eq('rcs')
      expect(message.message_format).to eq('rcs')
      expect(message.credits_used).to eq(2)
      expect(message.fell_back?).to be false
      expect(message.rcs.kind).to eq('text')
      expect(message.rcs.agent_name).to eq('Acme Coffee')
    end

    it 'sends text with suggested replies and actions' do
      suggestions = [
        { reply: { text: 'Yes, notify me', postbackData: 'notify_yes' } },
        { action: { text: 'Track order', postbackData: 'track',
                    url: 'https://acme.example/orders/4821' } }
      ]

      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          body: {
            channel: 'rcs',
            to: '+15551234567',
            text: 'Your order has shipped! Want live updates?',
            suggestions: suggestions,
            metadata: { 'orderId' => '4821' }
          }.to_json
        )
        .to_return(status: 201, body: rcs_message_response.to_json)

      messages.send(
        channel: 'rcs',
        to: '+15551234567',
        text: 'Your order has shipped! Want live updates?',
        suggestions: suggestions,
        metadata: { 'orderId' => '4821' }
      )

      expect(stub).to have_been_requested
    end

    it 'sends a rich card with the chosen agent' do
      card = {
        title: 'Spring collection',
        description: 'New arrivals are in - take a look.',
        mediaUrl: 'https://example.com/spring.jpg',
        orientation: 'vertical',
        suggestions: [
          { action: { text: 'Shop now', postbackData: 'shop',
                      url: 'https://acme.example/spring' } }
        ]
      }

      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          body: {
            channel: 'rcs',
            to: '+15551234567',
            agentId: 'rca_abc123',
            card: card
          }.to_json
        )
        .to_return(status: 201, body: rcs_message_response(
          'text' => nil,
          'rcs' => { 'kind' => 'card', 'agentId' => 'rca_abc123', 'agentName' => 'Acme Coffee' }
        ).to_json)

      message = messages.send(
        channel: 'rcs',
        to: '+15551234567',
        agent_id: 'rca_abc123',
        card: card
      )

      expect(stub).to have_been_requested
      expect(message.rcs.kind).to eq('card')
      expect(message.text).to be_nil
    end

    it 'discloses an SMS fallback on the returned message' do
      stub_request(:post, "#{base_url}/messages")
        .to_return(status: 201, body: rcs_message_response(
          'channel' => 'sms',
          'fellBackTo' => 'sms',
          'message_format' => 'sms',
          'from' => '+15559876543',
          'rcs' => { 'requestedChannel' => 'rcs', 'agentId' => 'rca_abc123',
                     'suggestionsDropped' => true }
        ).to_json)

      message = messages.send(
        channel: 'rcs',
        to: '+15551234567',
        text: 'Your order has shipped!',
        suggestions: [{ reply: { text: 'Notify me', postbackData: 'notify' } }]
      )

      expect(message).to be_a(Sendly::RcsMessage)
      expect(message.channel).to eq('sms')
      expect(message.fell_back_to).to eq('sms')
      expect(message.fell_back?).to be true
      expect(message.rcs.requested_channel).to eq('rcs')
      expect(message.rcs.suggestions_dropped).to be true
    end

    it 'sends fallbackToSms: false when the fallback is opted out of' do
      stub = stub_request(:post, "#{base_url}/messages")
        .with(
          body: {
            channel: 'rcs',
            to: '+15551234567',
            text: 'RCS or nothing',
            fallbackToSms: false
          }.to_json
        )
        .to_return(status: 201, body: rcs_message_response.to_json)

      messages.send(
        channel: 'rcs',
        to: '+15551234567',
        text: 'RCS or nothing',
        fallback_to_sms: false
      )

      expect(stub).to have_been_requested
    end

    it 'raises ValidationError when neither text nor card is given' do
      expect {
        messages.send(channel: 'rcs', to: '+15551234567')
      }.to raise_error(Sendly::ValidationError, /Provide exactly one of 'text' or 'card'/)
    end

    it 'raises ValidationError when both text and card are given' do
      expect {
        messages.send(channel: 'rcs', to: '+15551234567', text: 'Hello!',
                      card: { title: 'Hello', description: 'A card' })
      }.to raise_error(Sendly::ValidationError, /Provide exactly one of 'text' or 'card'/)
    end

    it 'raises ValidationError when to is not E.164' do
      expect {
        messages.send(channel: 'rcs', to: 'ACME', text: 'Hello!')
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
