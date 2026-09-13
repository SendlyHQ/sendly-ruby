# frozen_string_literal: true

module Sendly
  # One line of what was said on an agent-handled call. +speaker+ is
  # "caller" or "agent"; +at_ms+ is the offset from the start of the call.
  class CallTranscriptLine
    SPEAKERS = %w[caller agent].freeze

    attr_reader :speaker, :text, :at_ms

    def initialize(data)
      data ||= {}
      @speaker = data["speaker"]
      @text = data["text"]
      @at_ms = data["atMs"] || data["at_ms"]
    end

    def to_h
      { speaker: speaker, text: text, at_ms: at_ms }.compact
    end
  end

  # A phone call placed or received by one of your workspace's numbers.
  #
  # +kind+ is "pstn" for a phone call and "internal" for a browser-to-browser
  # call between teammates. +status+ is "ringing" or "active" while the call
  # is live and one of the terminal values ("completed", "no_answer", "busy",
  # "cancelled", "declined", "failed") once it has ended; "suspended" can
  # appear on an internal call whose media dropped and may recover.
  # +handled_by+ says whether an AI agent ("agent") or the team in the
  # dashboard ("dashboard") took the call. +billing+ is "metered" while a
  # phone call is charged per started minute, "settled" once it has ended,
  # and "unbilled" for calls that are never charged. +hangup_class+ says why
  # the call ended (see {HANGUP_CLASSES}); anything unrecognised arrives as
  # "ended". +metadata+ is the string map attached on create (+{}+ when
  # none). +transcript+ is only present on {CallsResource#get} for
  # agent-handled calls and is +nil+ otherwise.
  class Call
    STATUSES = %w[ringing active completed no_answer busy cancelled declined failed suspended].freeze
    LIVE_STATUSES = %w[ringing active].freeze
    DIRECTIONS = %w[inbound outbound].freeze
    KINDS = %w[pstn internal].freeze
    HANDLED_BY = %w[agent dashboard].freeze
    BILLING_STATES = %w[metered settled unbilled].freeze
    RECORDING_STATUSES = %w[recording ready failed].freeze
    HANGUP_CLASSES = %w[
      normal caller_hung_up callee_hung_up caller_left peer_left agent_ended
      agent_agent_hangup agent_caller_left
      ring_timeout callee_declined callee_busy caller_cancelled room_closed_unanswered
      agent_left_unanswered agent_caller_never_joined invalid_number destination_rejected
      max_duration credits_exhausted media_aborted peer_connection_lost room_closed agent_left
      setup_failed agent_dispatch_failed agent_api_unreachable agent_already_ended
      ended
    ].freeze
    ERROR_CODES = %w[
      voice_unavailable agents_unavailable voice_not_enabled outbound_calls_not_enabled
      agent_required agent_not_found agent_disabled invalid_metadata from_number_required
      no_voice_number number_not_found destination_not_supported e911_required lines_busy
      daily_call_limit call_not_found live_key_required voice_internal_error
      insufficient_credits invalid_number rate_limit_exceeded forbidden
    ].freeze

    attr_reader :id, :object, :kind, :direction, :status, :handled_by, :agent_id,
                :from, :to, :caller_name, :callee_name, :started_at, :answered_at,
                :ended_at, :duration_secs, :credits_charged, :billing, :hangup_class,
                :recording_status, :metadata, :transcript

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      data ||= {}
      @raw = data
      @id = data["id"]
      @object = data["object"] || "call"
      @kind = data["kind"]
      @direction = data["direction"]
      @status = data["status"]
      @handled_by = data["handledBy"] || data["handled_by"]
      @agent_id = data["agentId"] || data["agent_id"]
      @from = data["from"]
      @to = data["to"]
      @caller_name = data["callerName"] || data["caller_name"]
      @callee_name = data["calleeName"] || data["callee_name"]
      @started_at = data["startedAt"] || data["started_at"]
      @answered_at = data["answeredAt"] || data["answered_at"]
      @ended_at = data["endedAt"] || data["ended_at"]
      @duration_secs = data["durationSecs"] || data["duration_secs"] || 0
      @credits_charged = data["creditsCharged"] || data["credits_charged"] || 0
      @billing = data["billing"]
      @hangup_class = data["hangupClass"] || data["hangup_class"]
      @recording_status = data["recordingStatus"] || data["recording_status"]
      @metadata = data["metadata"] || {}
      lines = data["transcript"]
      @transcript = lines.is_a?(Array) ? lines.map { |l| CallTranscriptLine.new(l) } : nil
    end

    # @return [Boolean] Whether the call is still ringing or in progress
    def live?
      LIVE_STATUSES.include?(status)
    end

    # @return [Boolean] Whether the call has reached a terminal status
    def ended?
      !status.nil? && !live? && status != "suspended"
    end

    def answered?
      !answered_at.nil?
    end

    def agent_handled?
      handled_by == "agent"
    end

    def inbound?
      direction == "inbound"
    end

    def outbound?
      direction == "outbound"
    end

    def to_h
      {
        id: id, object: object, kind: kind, direction: direction, status: status,
        handled_by: handled_by, agent_id: agent_id, from: from, to: to,
        caller_name: caller_name, callee_name: callee_name, started_at: started_at,
        answered_at: answered_at, ended_at: ended_at, duration_secs: duration_secs,
        credits_charged: credits_charged, billing: billing, hangup_class: hangup_class,
        recording_status: recording_status, metadata: metadata,
        transcript: transcript&.map(&:to_h)
      }.compact
    end
  end

  # A page of calls, newest first, with the pagination the API returned.
  class CallList
    include Enumerable

    attr_reader :data, :total, :limit, :offset, :has_more

    def initialize(response)
      @data = (response["data"] || []).map { |c| Call.new(c) }
      pagination = response["pagination"] || {}
      @total = pagination["total"] || @data.length
      @limit = pagination["limit"] || 50
      @offset = pagination["offset"] || 0
      @has_more = pagination["hasMore"] || pagination["has_more"] || false
    end

    def has_more?
      has_more == true
    end

    def each(&block)
      data.each(&block)
    end

    def count
      data.length
    end

    alias size count
    alias length count

    def empty?
      data.empty?
    end

    def first
      data.first
    end

    def last
      data.last
    end
  end

  # The recording of a call. +status+ is "none" when there is no recording
  # (recording off, or the call was never answered), "recording" while the
  # call runs, "ready" once it can be fetched, or "failed". +url+ and
  # +expires_at+ are set only when {#ready?}: the URL is signed and valid for
  # five minutes. Recordings are Ogg/Opus (+content_type+ "audio/ogg");
  # agent-handled calls are recorded dual-channel, caller left and agent
  # right.
  class CallRecording
    STATUSES = %w[none recording ready failed].freeze

    attr_reader :call_id, :status, :url, :expires_at, :content_type

    def initialize(data)
      data ||= {}
      @call_id = data["callId"] || data["call_id"]
      @status = data["status"]
      @url = data["url"]
      @expires_at = data["expiresAt"] || data["expires_at"]
      @content_type = data["contentType"] || data["content_type"]
    end

    def ready?
      status == "ready"
    end

    def to_h
      {
        call_id: call_id, status: status, url: url, expires_at: expires_at,
        content_type: content_type
      }.compact
    end
  end

  # Calls resource: place phone calls handled by your AI agents, list and
  # inspect calls, end a call and fetch recordings.
  #
  # A call placed over the API is answered by one of the AI agents you
  # configure in the dashboard under Calls, then Agents; the +from+ number
  # must have voice switched on in the dashboard. Calls are charged per
  # started minute from your credit balance: 2 credits a minute outbound,
  # plus 8 a minute while an agent is on the call. Destinations are US and
  # Canadian numbers. Reads need the +calls:read+ scope, writes
  # +calls:write+ and a live API key (+sk_live_v1_xxx+).
  #
  # Voice is enabled workspace by workspace. Until it is on for yours,
  # every method here raises {Sendly::NotFoundError} (+voice_not_enabled+).
  #
  # Error codes map onto the usual classes: {Sendly::NotFoundError} for
  # +voice_not_enabled+, +outbound_calls_not_enabled+, +agent_not_found+,
  # +number_not_found+ and +call_not_found+; {Sendly::ValidationError} for
  # +invalid_number+, +destination_not_supported+, +agent_required+,
  # +invalid_metadata+ and +from_number_required+;
  # {Sendly::InsufficientCreditsError} for +insufficient_credits+;
  # {Sendly::RateLimitError} for +daily_call_limit+ and
  # +rate_limit_exceeded+; {Sendly::APIError} with the HTTP status for
  # +e911_required+ (428), +agent_disabled+ / +no_voice_number+ /
  # +lines_busy+ (409) and +live_key_required+ / +forbidden+ (403); and
  # {Sendly::ServerError} (not an +APIError+) for +voice_unavailable+ /
  # +agents_unavailable+ (503) and +voice_internal_error+ (500). The full
  # list is {Call::ERROR_CODES}.
  #
  # @example Place a call and wait for it to end
  #   call = client.calls.create(
  #     to: "+15555550123",
  #     agent_id: "3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b",
  #     context: "Confirm the 3pm appointment on Tuesday."
  #   )
  #   call = client.calls.get(call.id) while call.live? && sleep(2)
  #   puts call.hangup_class
  #   call.transcript.each { |line| puts "#{line.speaker}: #{line.text}" }
  class CallsResource
    def initialize(client)
      @client = client
    end

    # Place a phone call that one of your AI agents handles. Returns at once
    # with the call +ringing+; poll {#get} or subscribe to the +call.started+
    # and +call.completed+ webhooks to follow it. Requires the +calls:write+
    # scope and a live key.
    #
    # @param to [String] The number to call, in E.164 format (US or Canada)
    # @param agent_id [String] The AI agent that talks on the call
    # @param from [String, nil] A voice-enabled number in your workspace.
    #   Optional when the workspace has exactly one; required (the API
    #   responds 400 +from_number_required+) when it has more.
    # @param context [String, nil] Up to 2000 characters appended to the
    #   agent's instructions for this call only. Not echoed back.
    # @param metadata [Hash{String => String}, nil] Up to 20 string pairs
    #   (keys 1-40 characters of +A-Z a-z 0-9 _ . : -+, values up to 500
    #   characters). Stored, echoed on every read and in every +call.*+
    #   webhook.
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [Sendly::Call] The new call (+status+ "ringing", +handled_by+ "agent")
    # @raise [Sendly::ValidationError] If +to+ or +agent_id+ is missing, or
    #   HTTP 400 (+invalid_number+, +destination_not_supported+,
    #   +agent_required+, +invalid_metadata+, +from_number_required+)
    # @raise [Sendly::NotFoundError] HTTP 404 (+voice_not_enabled+,
    #   +outbound_calls_not_enabled+, +agent_not_found+, +number_not_found+)
    # @raise [Sendly::InsufficientCreditsError] HTTP 402 when the balance
    #   cannot cover one minute at the agent rate
    # @raise [Sendly::APIError] HTTP 428 +e911_required+ (register an
    #   emergency address for the number first), 409 +agent_disabled+ /
    #   +no_voice_number+ / +lines_busy+, 403 +live_key_required+
    # @raise [Sendly::RateLimitError] HTTP 429 +daily_call_limit+ / +rate_limit_exceeded+
    # @raise [Sendly::ServerError] HTTP 503 +voice_unavailable+ /
    #   +agents_unavailable+ (calling is not switched on for this deployment),
    #   HTTP 500 +voice_internal_error+
    #
    # @example
    #   call = client.calls.create(
    #     to: "+15555550123",
    #     agent_id: "3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b",
    #     from: "+15555550188",
    #     metadata: { "crmId" => "lead_8812" }
    #   )
    #   puts call.id
    def create(to:, agent_id:, from: nil, context: nil, metadata: nil, idempotency_key: nil)
      raise ValidationError, "to is required" if to.nil? || to.to_s.empty?
      raise ValidationError, "agent_id is required" if agent_id.nil? || agent_id.to_s.empty?

      body = { to: to, agentId: agent_id }
      body[:from] = from unless from.nil?
      body[:context] = context unless context.nil?
      body[:metadata] = metadata unless metadata.nil?

      response = @client.post("/calls", body, idempotency_key: idempotency_key)
      Call.new(response)
    end

    # List your workspace's calls, newest first. Live rows are reconciled
    # before they are returned, so a ring past its deadline reads as
    # +no_answer+. Requires the +calls:read+ scope.
    #
    # @param limit [Integer, nil] Calls per page (1-100, default 50)
    # @param offset [Integer, nil] Calls to skip (default 0)
    # @param status [String, nil] One of {Call::STATUSES}
    # @param direction [String, nil] "inbound" or "outbound"
    # @param kind [String, nil] "pstn" or "internal"
    # @param agent_id [String, nil] Only calls handled by this agent
    # @param to [String, nil] Exact E.164 match on the called number
    # @param from [String, nil] Exact E.164 match on the calling number
    # @return [Sendly::CallList] The page and its pagination
    # @raise [Sendly::ValidationError] HTTP 400 +invalid_request+ for a value
    #   outside the vocabularies above
    #
    # @example
    #   page = client.calls.list(status: "completed", direction: "outbound", limit: 20)
    #   page.each { |c| puts "#{c.to} #{c.duration_secs}s #{c.credits_charged} credits" }
    #   puts page.has_more?
    def list(limit: nil, offset: nil, status: nil, direction: nil, kind: nil,
             agent_id: nil, to: nil, from: nil)
      params = {}
      params[:limit] = limit unless limit.nil?
      params[:offset] = offset unless offset.nil?
      params[:status] = status unless status.nil?
      params[:direction] = direction unless direction.nil?
      params[:kind] = kind unless kind.nil?
      params[:agentId] = agent_id unless agent_id.nil?
      params[:to] = to unless to.nil?
      params[:from] = from unless from.nil?

      response = @client.get("/calls", params)
      CallList.new(response)
    end

    # Fetch one call. Agent-handled calls include their +transcript+; a live
    # call is reconciled first. Requires the +calls:read+ scope.
    #
    # @param id [String] Call identifier
    # @return [Sendly::Call]
    # @raise [Sendly::NotFoundError] HTTP 404 +call_not_found+ when the call
    #   is not in your workspace
    #
    # @example
    #   call = client.calls.get("6f1c2d3e-4a5b-4c6d-8e9f-0a1b2c3d4e5f")
    #   call.transcript&.each { |line| puts "#{line.speaker}: #{line.text}" }
    def get(id)
      encoded_id = encode_id!(id)
      response = @client.get("/calls/#{encoded_id}")
      Call.new(response)
    end

    # End a call. A ringing call becomes +cancelled+ (+hangup_class+
    # "caller_cancelled") and the callee stops ringing; an active call
    # becomes +completed+ ("normal"). Hanging up a call that has already
    # ended returns it unchanged. Requires the +calls:write+ scope and a
    # live key.
    #
    # @param id [String] Call identifier
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [Sendly::Call] The call after the hangup
    # @raise [Sendly::NotFoundError] HTTP 404 +call_not_found+
    #
    # @example
    #   call = client.calls.hangup(call.id)
    #   puts call.status # "cancelled" or "completed"
    def hangup(id, idempotency_key: nil)
      encoded_id = encode_id!(id)
      response = @client.post("/calls/#{encoded_id}/hangup", {}, idempotency_key: idempotency_key)
      Call.new(response)
    end

    # Fetch the recording of a call. +url+ is a signed link valid for five
    # minutes and is only set once the recording is +ready?+; fetch again
    # for a fresh link. Requires the +calls:read+ scope.
    #
    # @param id [String] Call identifier
    # @return [Sendly::CallRecording]
    # @raise [Sendly::NotFoundError] HTTP 404 +call_not_found+
    #
    # @example
    #   rec = client.calls.recording(call.id)
    #   if rec.ready?
    #     File.binwrite("#{call.id}.ogg", Net::HTTP.get(URI(rec.url)))
    #   end
    def recording(id)
      encoded_id = encode_id!(id)
      response = @client.get("/calls/#{encoded_id}/recording")
      CallRecording.new(response)
    end

    private

    def encode_id!(id)
      raise ValidationError, "Call ID is required" if id.nil? || id.to_s.empty?

      URI.encode_www_form_component(id)
    end
  end
end
