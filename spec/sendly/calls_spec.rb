# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Calls' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:calls) { client.calls }

  let(:auto_key_pattern) do
    /\Asendly-ruby-retry-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  end

  let(:call_id) { '6f1c2d3e-4a5b-4c6d-8e9f-0a1b2c3d4e5f' }
  let(:agent_id) { '3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b' }

  let(:call_body) do
    {
      'id' => call_id, 'object' => 'call', 'kind' => 'pstn', 'direction' => 'outbound',
      'status' => 'ringing', 'handledBy' => 'agent', 'agentId' => agent_id,
      'from' => '+15555550188', 'to' => '+15555550123',
      'callerName' => 'Front Desk', 'calleeName' => '+15555550123',
      'startedAt' => '2026-09-12T14:03:11.000Z', 'answeredAt' => nil, 'endedAt' => nil,
      'durationSecs' => 0, 'creditsCharged' => 0, 'billing' => 'metered',
      'hangupClass' => nil, 'recordingStatus' => nil,
      'metadata' => { 'crmId' => 'lead_8812' }
    }
  end

  let(:completed_body) do
    call_body.merge(
      'status' => 'completed', 'answeredAt' => '2026-09-12T14:03:19.000Z',
      'endedAt' => '2026-09-12T14:05:02.000Z', 'durationSecs' => 103,
      'creditsCharged' => 20, 'billing' => 'settled', 'hangupClass' => 'agent_agent_hangup',
      'recordingStatus' => 'ready'
    )
  end

  def json(status, body)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  it 'exposes a memoised calls resource on the client' do
    expect(calls).to be_a(Sendly::CallsResource)
    expect(client.calls).to equal(calls)
  end

  it 'publishes the status, hangup class and error code vocabularies' do
    expect(Sendly::Call::STATUSES).to include('ringing', 'active', 'completed', 'no_answer', 'busy')
    expect(Sendly::Call::HANGUP_CLASSES).to include('normal', 'ring_timeout', 'credits_exhausted',
                                                    'setup_failed', 'ended')
    expect(Sendly::Call::ERROR_CODES).to include('voice_unavailable', 'agents_unavailable')
    expect(Sendly::Call::ERROR_CODES).to include('voice_not_enabled', 'agent_required', 'e911_required',
                                                 'lines_busy', 'call_not_found', 'live_key_required')
    expect(Sendly::CallRecording::STATUSES).to eq(%w[none recording ready failed])
  end

  describe 'create' do
    it 'POSTs /calls with agentId, from, context and metadata and maps the 201' do
      stub = stub_request(:post, "#{base_url}/calls")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}", 'Content-Type' => 'application/json' },
          body: {
            to: '+15555550123', agentId: agent_id, from: '+15555550188',
            context: 'Confirm the 3pm appointment on Tuesday.',
            metadata: { crmId: 'lead_8812' }
          }.to_json
        )
        .to_return(json(201, call_body))

      call = calls.create(
        to: '+15555550123', agent_id: agent_id, from: '+15555550188',
        context: 'Confirm the 3pm appointment on Tuesday.',
        metadata: { 'crmId' => 'lead_8812' }
      )

      expect(stub).to have_been_requested
      expect(call).to be_a(Sendly::Call)
      expect(call.id).to eq(call_id)
      expect(call.object).to eq('call')
      expect(call.kind).to eq('pstn')
      expect(call.direction).to eq('outbound')
      expect(call.status).to eq('ringing')
      expect(call.handled_by).to eq('agent')
      expect(call.agent_id).to eq(agent_id)
      expect(call.from).to eq('+15555550188')
      expect(call.to).to eq('+15555550123')
      expect(call.caller_name).to eq('Front Desk')
      expect(call.callee_name).to eq('+15555550123')
      expect(call.started_at).to eq('2026-09-12T14:03:11.000Z')
      expect(call.answered_at).to be_nil
      expect(call.ended_at).to be_nil
      expect(call.duration_secs).to eq(0)
      expect(call.credits_charged).to eq(0)
      expect(call.billing).to eq('metered')
      expect(call.hangup_class).to be_nil
      expect(call.recording_status).to be_nil
      expect(call.metadata).to eq('crmId' => 'lead_8812')
      expect(call.transcript).to be_nil
      expect(call.live?).to be true
      expect(call.ended?).to be false
      expect(call.agent_handled?).to be true
      expect(call.outbound?).to be true
      expect(call.to_h[:metadata]).to eq('crmId' => 'lead_8812')
      expect(call.to_h).not_to have_key(:transcript)
    end

    it 'sends only to and agentId when the optional fields are omitted' do
      stub = stub_request(:post, "#{base_url}/calls")
        .with(body: { to: '+15555550123', agentId: agent_id }.to_json)
        .to_return(json(201, call_body))

      calls.create(to: '+15555550123', agent_id: agent_id)

      expect(stub).to have_been_requested
    end

    it 'attaches an auto-generated Idempotency-Key and sends a caller key verbatim' do
      keys = []
      stub_request(:post, "#{base_url}/calls")
        .with { |req| keys << req.headers['Idempotency-Key'] }
        .to_return(json(201, call_body), json(201, call_body))

      calls.create(to: '+15555550123', agent_id: agent_id)
      calls.create(to: '+15555550123', agent_id: agent_id, idempotency_key: 'lead-8812-call-1')

      expect(keys[0]).to match(auto_key_pattern)
      expect(keys[1]).to eq('lead-8812-call-1')
    end

    it 'raises ValidationError before any request when to or agent_id is missing' do
      expect { calls.create(to: '', agent_id: agent_id) }
        .to raise_error(Sendly::ValidationError, 'to is required')
      expect { calls.create(to: '+15555550123', agent_id: nil) }
        .to raise_error(Sendly::ValidationError, 'agent_id is required')
      expect(a_request(:post, "#{base_url}/calls")).not_to have_been_made
    end

    it 'raises InsufficientCreditsError on 402 insufficient_credits with the API message' do
      stub_request(:post, "#{base_url}/calls")
        .to_return(json(402, 'error' => 'insufficient_credits',
                             'message' => 'Calls cost 10 credits a minute. Current balance: 4.',
                             'creditsNeeded' => 10, 'currentBalance' => 4))

      expect { calls.create(to: '+15555550123', agent_id: agent_id) }
        .to raise_error(Sendly::InsufficientCreditsError, /Current balance: 4/) { |e|
          expect(e.status_code).to eq(402)
        }
    end

    it 'raises APIError with status 428 on e911_required' do
      stub_request(:post, "#{base_url}/calls")
        .to_return(json(428, 'error' => 'e911_required',
                             'message' => 'Register an emergency address for this number before placing calls.'))

      expect { calls.create(to: '+15555550123', agent_id: agent_id) }
        .to raise_error(Sendly::APIError, /emergency address/) { |e|
          expect(e.status_code).to eq(428)
        }
    end

    it 'raises ServerError, not APIError, on 503 voice_unavailable' do
      stub_request(:post, "#{base_url}/calls")
        .to_return(json(503, 'error' => 'voice_unavailable',
                             'message' => "Outbound calling isn't available right now."))

      expect { calls.create(to: '+15555550123', agent_id: agent_id) }
        .to raise_error(Sendly::ServerError, /isn't available/) { |e|
          expect(e.status_code).to eq(503)
          expect(e).not_to be_a(Sendly::APIError)
        }
    end

    it 'raises ValidationError on 400 agent_required' do
      stub_request(:post, "#{base_url}/calls")
        .to_return(json(400, 'error' => 'agent_required',
                             'message' => 'Calls placed over the API are answered by an AI agent. Pass agentId.'))

      expect { calls.create(to: '+15555550123', agent_id: agent_id) }
        .to raise_error(Sendly::ValidationError, /Pass agentId/)
    end

    it 'raises NotFoundError while voice is not enabled for the workspace' do
      stub_request(:post, "#{base_url}/calls")
        .to_return(json(404, 'error' => 'voice_not_enabled',
                             'message' => 'Voice is not enabled for your account.'))

      expect { calls.create(to: '+15555550123', agent_id: agent_id) }
        .to raise_error(Sendly::NotFoundError, /not enabled/)
    end
  end

  describe 'list' do
    it 'GETs /calls with camelCase query keys and maps the page' do
      stub = stub_request(:get, "#{base_url}/calls")
        .with(query: {
          'limit' => '2', 'offset' => '4', 'status' => 'completed', 'direction' => 'outbound',
          'kind' => 'pstn', 'agentId' => agent_id, 'to' => '+15555550123', 'from' => '+15555550188'
        })
        .to_return(json(200, 'data' => [completed_body, completed_body.merge('id' => 'other')],
                             'pagination' => { 'total' => 132, 'limit' => 2, 'offset' => 4,
                                               'hasMore' => true }))

      page = calls.list(limit: 2, offset: 4, status: 'completed', direction: 'outbound', kind: 'pstn',
                        agent_id: agent_id, to: '+15555550123', from: '+15555550188')

      expect(stub).to have_been_requested
      expect(page).to be_a(Sendly::CallList)
      expect(page.count).to eq(2)
      expect(page.first).to be_a(Sendly::Call)
      expect(page.first.id).to eq(call_id)
      expect(page.last.id).to eq('other')
      expect(page.total).to eq(132)
      expect(page.limit).to eq(2)
      expect(page.offset).to eq(4)
      expect(page.has_more).to be true
      expect(page.has_more?).to be true
      expect(page.map(&:status)).to eq(%w[completed completed])
    end

    it 'sends no query when nothing is filtered and reads an empty page' do
      stub = stub_request(:get, "#{base_url}/calls")
        .to_return(json(200, 'data' => [], 'pagination' => { 'total' => 0, 'limit' => 50, 'offset' => 0,
                                                             'hasMore' => false }))

      page = calls.list

      expect(stub).to have_been_requested
      expect(page).to be_empty
      expect(page.total).to eq(0)
      expect(page.has_more?).to be false
    end
  end

  describe 'get' do
    it 'GETs /calls/:id and maps the transcript on an agent-handled call' do
      stub_request_with_auth(:get, "/calls/#{call_id}", response_body: completed_body.merge(
        'transcript' => [
          { 'speaker' => 'agent', 'text' => 'Hi Jordan, this is Front Desk.', 'atMs' => 800 },
          { 'speaker' => 'caller', 'text' => 'Yes, 3pm works.', 'atMs' => 4200 }
        ]
      ))

      call = calls.get(call_id)

      expect(call.status).to eq('completed')
      expect(call.ended?).to be true
      expect(call.answered?).to be true
      expect(call.duration_secs).to eq(103)
      expect(call.credits_charged).to eq(20)
      expect(call.billing).to eq('settled')
      expect(call.hangup_class).to eq('agent_agent_hangup')
      expect(call.recording_status).to eq('ready')
      expect(call.transcript.length).to eq(2)
      expect(call.transcript.first).to be_a(Sendly::CallTranscriptLine)
      expect(call.transcript.first.speaker).to eq('agent')
      expect(call.transcript.first.at_ms).to eq(800)
      expect(call.transcript.last.text).to eq('Yes, 3pm works.')
      expect(call.to_h[:transcript]).to eq([
        { speaker: 'agent', text: 'Hi Jordan, this is Front Desk.', at_ms: 800 },
        { speaker: 'caller', text: 'Yes, 3pm works.', at_ms: 4200 }
      ])
    end

    it 'leaves transcript nil on a dashboard-handled call' do
      stub_request_with_auth(:get, "/calls/#{call_id}", response_body: completed_body.merge(
        'handledBy' => 'dashboard', 'agentId' => nil, 'direction' => 'inbound'
      ))

      call = calls.get(call_id)

      expect(call.handled_by).to eq('dashboard')
      expect(call.agent_handled?).to be false
      expect(call.inbound?).to be true
      expect(call.transcript).to be_nil
    end

    it 'reads the snake_case twin the webhooks carry' do
      stub_request_with_auth(:get, "/calls/#{call_id}", response_body: {
        'id' => call_id, 'handled_by' => 'agent', 'agent_id' => agent_id, 'caller_name' => 'Front Desk',
        'started_at' => '2026-09-12T14:03:11.000Z', 'duration_secs' => 9, 'credits_charged' => 10,
        'hangup_class' => 'normal', 'recording_status' => 'ready', 'billing' => 'settled', 'status' => 'completed'
      })

      call = calls.get(call_id)

      expect(call.handled_by).to eq('agent')
      expect(call.agent_id).to eq(agent_id)
      expect(call.caller_name).to eq('Front Desk')
      expect(call.duration_secs).to eq(9)
      expect(call.hangup_class).to eq('normal')
      expect(call.metadata).to eq({})
    end

    it 'percent-encodes the id and raises ValidationError when it is blank' do
      stub = stub_request_with_auth(:get, '/calls/call%2Fwith+space', response_body: completed_body)

      calls.get('call/with space')

      expect(stub).to have_been_requested
      expect { calls.get('') }.to raise_error(Sendly::ValidationError, 'Call ID is required')
      expect { calls.get(nil) }.to raise_error(Sendly::ValidationError, 'Call ID is required')
    end

    it 'raises NotFoundError on 404 call_not_found' do
      stub_request(:get, "#{base_url}/calls/#{call_id}")
        .to_return(json(404, 'error' => 'call_not_found',
                             'message' => 'No call with that id is in this workspace.'))

      expect { calls.get(call_id) }.to raise_error(Sendly::NotFoundError, /No call with that id/)
    end
  end

  describe 'hangup' do
    it 'POSTs /calls/:id/hangup with an empty body and an auto Idempotency-Key' do
      keys = []
      stub = stub_request(:post, "#{base_url}/calls/#{call_id}/hangup")
        .with(body: '{}') { |req| keys << req.headers['Idempotency-Key'] }
        .to_return(json(200, call_body.merge('status' => 'cancelled', 'hangupClass' => 'caller_cancelled',
                                             'billing' => 'settled')))

      call = calls.hangup(call_id)

      expect(stub).to have_been_requested
      expect(keys[0]).to match(auto_key_pattern)
      expect(call.status).to eq('cancelled')
      expect(call.hangup_class).to eq('caller_cancelled')
      expect(call.live?).to be false
    end

    it 'sends a caller key verbatim and maps an active call ending normally' do
      stub = stub_request(:post, "#{base_url}/calls/#{call_id}/hangup")
        .with(headers: { 'Idempotency-Key' => 'hangup-1' })
        .to_return(json(200, completed_body.merge('hangupClass' => 'normal')))

      call = calls.hangup(call_id, idempotency_key: 'hangup-1')

      expect(stub).to have_been_requested
      expect(call.status).to eq('completed')
      expect(call.hangup_class).to eq('normal')
    end

    it 'raises NotFoundError on 404 call_not_found' do
      stub_request(:post, "#{base_url}/calls/#{call_id}/hangup")
        .to_return(json(404, 'error' => 'call_not_found',
                             'message' => 'No call with that id is in this workspace.'))

      expect { calls.hangup(call_id) }.to raise_error(Sendly::NotFoundError)
    end
  end

  describe 'recording' do
    it 'GETs /calls/:id/recording and maps a ready recording' do
      stub_request_with_auth(:get, "/calls/#{call_id}/recording", response_body: {
        'callId' => call_id, 'status' => 'ready',
        'url' => 'https://sendly.live/recordings/signed-example',
        'expiresAt' => '2026-09-12T14:10:00.000Z', 'contentType' => 'audio/ogg'
      })

      rec = calls.recording(call_id)

      expect(rec).to be_a(Sendly::CallRecording)
      expect(rec.call_id).to eq(call_id)
      expect(rec.status).to eq('ready')
      expect(rec.ready?).to be true
      expect(rec.url).to eq('https://sendly.live/recordings/signed-example')
      expect(rec.expires_at).to eq('2026-09-12T14:10:00.000Z')
      expect(rec.content_type).to eq('audio/ogg')
      expect(rec.to_h[:url]).to eq('https://sendly.live/recordings/signed-example')
    end

    it 'leaves url, expires_at and content_type nil when there is no recording' do
      stub_request_with_auth(:get, "/calls/#{call_id}/recording", response_body: {
        'callId' => call_id, 'status' => 'none', 'url' => nil, 'expiresAt' => nil, 'contentType' => nil
      })

      rec = calls.recording(call_id)

      expect(rec.status).to eq('none')
      expect(rec.ready?).to be false
      expect(rec.url).to be_nil
      expect(rec.expires_at).to be_nil
      expect(rec.content_type).to be_nil
      expect(rec.to_h).to eq(call_id: call_id, status: 'none')
    end

    it 'raises NotFoundError on 404 call_not_found' do
      stub_request(:get, "#{base_url}/calls/#{call_id}/recording")
        .to_return(json(404, 'error' => 'call_not_found',
                             'message' => 'No call with that id is in this workspace.'))

      expect { calls.recording(call_id) }.to raise_error(Sendly::NotFoundError)
    end
  end
end
