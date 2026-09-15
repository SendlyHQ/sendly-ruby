# frozen_string_literal: true

module Sendly
  # A street address registered for emergency calls. +unit+ is +nil+ when
  # there is none, +state+ is the two-letter state or province code and
  # +country+ is "US" or "CA".
  class EmergencyAddress
    attr_reader :street, :unit, :city, :state, :zip, :country

    def initialize(data)
      data ||= {}
      @street = data["street"]
      @unit = data["unit"]
      @city = data["city"]
      @state = data["state"]
      @zip = data["zip"]
      @country = data["country"]
    end

    def to_h
      { street: street, unit: unit, city: city, state: state, zip: zip, country: country }.compact
    end
  end

  # A number's emergency address registration. +status+ is "provisioning"
  # while the registration is being switched on, "active" once it is in
  # place, and otherwise the failure status as recorded. +address+ is +nil+
  # when no address is on file.
  class VoiceNumberEmergencyAddress
    attr_reader :status, :address

    def initialize(data)
      data ||= {}
      @status = data["status"]
      @address = data["address"] ? EmergencyAddress.new(data["address"]) : nil
    end

    def active?
      status == "active"
    end

    def to_h
      { status: status, address: address&.to_h }.compact
    end
  end

  # Credits charged per started minute on a number. +inbound+ is an inbound
  # call the team answers in the dashboard, +outbound+ an outbound call (an
  # agent on the call adds its own per-minute charge) and +agent+ an inbound
  # call an AI agent answers, agent included.
  class VoiceNumberRates
    attr_reader :inbound, :outbound, :agent

    def initialize(data)
      data ||= {}
      @inbound = data["inbound"]
      @outbound = data["outbound"]
      @agent = data["agent"]
    end

    def to_h
      { inbound: inbound, outbound: outbound, agent: agent }.compact
    end
  end

  # A number in your workspace with its voice settings.
  #
  # +voice_mode+ is one of {VOICE_MODES} and reports how inbound calls are
  # answered: "none" when calls are not answered (always so when voice is off),
  # "ring_dashboard" when calls ring the team in the dashboard, and "agent"
  # when an AI agent answers. +agent_id+ is the agent that answers in
  # "agent" mode; in the other modes it is whichever agent was last stored,
  # or +nil+. +emergency_address+ is +nil+ until one is registered.
  # +phone_number_type+ (for example "local") and +country_code+ can be
  # +nil+.
  class VoiceNumber
    VOICE_MODES = %w[none ring_dashboard agent].freeze

    attr_reader :id, :object, :phone_number, :phone_number_type, :country_code,
                :is_default, :voice_enabled, :voice_mode, :agent_id,
                :emergency_address, :rate_per_minute

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      data ||= {}
      @raw = data
      @id = data["id"]
      @object = data["object"] || "voice_number"
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @phone_number_type = data["phoneNumberType"] || data["phone_number_type"]
      @country_code = data["countryCode"] || data["country_code"]
      @is_default = data.key?("isDefault") ? data["isDefault"] : data["is_default"]
      @voice_enabled = data.key?("voiceEnabled") ? data["voiceEnabled"] : data["voice_enabled"]
      @voice_mode = data["voiceMode"] || data["voice_mode"]
      @agent_id = data["agentId"] || data["agent_id"]
      address = data["emergencyAddress"] || data["emergency_address"]
      @emergency_address = address ? VoiceNumberEmergencyAddress.new(address) : nil
      rates = data["ratePerMinute"] || data["rate_per_minute"]
      @rate_per_minute = rates ? VoiceNumberRates.new(rates) : nil
    end

    # @return [Boolean] Whether this is the workspace's default sending number
    def default?
      is_default == true
    end

    # @return [Boolean] Whether the number takes and places phone calls
    def voice_enabled?
      voice_enabled == true
    end

    def to_h
      {
        id: id, object: object, phone_number: phone_number,
        phone_number_type: phone_number_type, country_code: country_code,
        is_default: is_default, voice_enabled: voice_enabled, voice_mode: voice_mode,
        agent_id: agent_id, emergency_address: emergency_address&.to_h,
        rate_per_minute: rate_per_minute&.to_h
      }.compact
    end
  end

  # What an agent may do on a call.
  #
  # +send_sms+ is true when the agent may text the caller; it confirms the
  # number back to them before sending. +transfer_to+ is an E.164 number
  # for callers who need a person, or +nil+. Agents cannot transfer calls
  # yet and never dial or read out this number: while it is set, a caller
  # who asks for a person is told their message will be passed on, and the
  # agent takes their name and number.
  class VoiceAgentTools
    attr_reader :send_sms, :transfer_to

    def initialize(data)
      data ||= {}
      @send_sms = data.key?("sendSms") ? data["sendSms"] : data["send_sms"]
      @transfer_to = data["transferTo"] || data["transfer_to"]
    end

    def send_sms?
      send_sms == true
    end

    def to_h
      { send_sms: send_sms, transfer_to: transfer_to }.compact
    end
  end

  # An AI agent that answers and places phone calls.
  #
  # +voice+ is a voice id from {VoiceVoicesResource#list} and +voice_label+
  # its readable name. +greeting+ and +instructions+ are +""+ when unset.
  # +can_send_sms+ is true when the agent holds its own scoped sending key,
  # which +tools.send_sms+ needs to actually send. +calls_handled+ and
  # +avg_duration_secs+ are the agent's call stats. Timestamps are ISO 8601
  # strings.
  class VoiceAgent
    attr_reader :id, :object, :name, :enabled, :voice, :voice_label, :language,
                :greeting, :instructions, :tools, :can_send_sms, :calls_handled,
                :avg_duration_secs, :created_at, :updated_at

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      data ||= {}
      @raw = data
      @id = data["id"]
      @object = data["object"] || "voice_agent"
      @name = data["name"]
      @enabled = data["enabled"]
      @voice = data["voice"]
      @voice_label = data["voiceLabel"] || data["voice_label"]
      @language = data["language"]
      @greeting = data["greeting"]
      @instructions = data["instructions"]
      @tools = VoiceAgentTools.new(data["tools"])
      @can_send_sms = data.key?("canSendSms") ? data["canSendSms"] : data["can_send_sms"]
      @calls_handled = data["callsHandled"] || data["calls_handled"] || 0
      @avg_duration_secs = data["avgDurationSecs"] || data["avg_duration_secs"] || 0
      @created_at = data["createdAt"] || data["created_at"]
      @updated_at = data["updatedAt"] || data["updated_at"]
    end

    # @return [Boolean] Whether the agent is switched on. A switched-off agent
    #   can't be pointed at a number or put on a call.
    def enabled?
      enabled == true
    end

    # @return [Boolean] Whether the agent holds its scoped sending key
    def can_send_sms?
      can_send_sms == true
    end

    def to_h
      {
        id: id, object: object, name: name, enabled: enabled, voice: voice,
        voice_label: voice_label, language: language, greeting: greeting,
        instructions: instructions, tools: tools.to_h, can_send_sms: can_send_sms,
        calls_handled: calls_handled, avg_duration_secs: avg_duration_secs,
        created_at: created_at, updated_at: updated_at
      }.compact
    end
  end

  # A voice an agent can speak with. Pass +id+ as +voice:+ when creating or
  # updating an agent; +language+ is the language it speaks, e.g. "en".
  class Voice
    attr_reader :id, :label, :language

    def initialize(data)
      data ||= {}
      @id = data["id"]
      @label = data["label"]
      @language = data["language"]
    end

    def to_h
      { id: id, label: label, language: language }.compact
    end
  end

  # The confirmation {VoiceAgentsResource#delete} returns.
  class DeletedVoiceAgent
    attr_reader :id, :object, :deleted

    def initialize(data)
      data ||= {}
      @id = data["id"]
      @object = data["object"] || "voice_agent"
      @deleted = data["deleted"] == true
    end

    def deleted?
      deleted
    end

    def to_h
      { id: id, object: object, deleted: deleted }
    end
  end

  # The +data+ array a voice list method returns, as an Enumerable of
  # model objects.
  class VoiceDataList
    include Enumerable

    attr_reader :data

    def initialize(response, model)
      @data = ((response || {})["data"] || []).map { |item| model.new(item) }
    end

    def each(&block)
      data.each(&block)
    end

    def size
      data.length
    end

    alias length size

    def empty?
      data.empty?
    end

    def last
      data.last
    end
  end

  # The workspace's active numbers with their voice settings, as {VoiceNumber}s.
  class VoiceNumberList < VoiceDataList
    def initialize(response)
      super(response, VoiceNumber)
    end
  end

  # The workspace's AI agents, as {VoiceAgent}s.
  class VoiceAgentList < VoiceDataList
    def initialize(response)
      super(response, VoiceAgent)
    end
  end

  # The voices an agent can speak with, as {Voice}s.
  class VoiceList < VoiceDataList
    def initialize(response)
      super(response, Voice)
    end
  end

  # Shapes voice input before it leaves the process.
  #
  # @api private
  module VoiceInput
    OMIT = Object.new.freeze
    TOOL_KEYS = { "send_sms" => "sendSms", "transfer_to" => "transferTo" }.freeze

    module_function

    def require_text!(value, message)
      raise ValidationError, message if value.nil? || value.to_s.strip.empty?
    end

    def number_path(number)
      require_text!(number, "number is required")
      "/voice/numbers/#{URI.encode_www_form_component(number)}"
    end

    def agent_path(id)
      require_text!(id, "Agent ID is required")
      "/voice/agents/#{URI.encode_www_form_component(id)}"
    end

    def tools_body(tools)
      return tools unless tools.is_a?(Hash)

      tools.each_with_object({}) { |(key, value), out| out[TOOL_KEYS.fetch(key.to_s, key.to_s)] = value }
    end

    def agent_body(name:, enabled:, voice:, language:, greeting:, instructions:, tools:)
      body = {}
      body[:name] = name unless name.nil?
      body[:enabled] = enabled unless enabled.nil?
      body[:voice] = voice unless voice.nil?
      body[:language] = language unless language.nil?
      body[:greeting] = greeting unless greeting.nil?
      body[:instructions] = instructions unless instructions.nil?
      body[:tools] = tools_body(tools) unless tools.nil?
      body
    end
  end

  # Voice settings for the numbers in your workspace: switch voice on for a
  # number, choose how it answers, and register its emergency address.
  # Reached as +client.voice.numbers+.
  class VoiceNumbersResource
    def initialize(client)
      @client = client
    end

    # List the workspace's active numbers with their voice settings, in the
    # same order as the dashboard. Requires the +calls:read+ scope.
    #
    # @return [Sendly::VoiceNumberList]
    #
    # @example
    #   client.voice.numbers.list.each do |n|
    #     puts "#{n.phone_number} #{n.voice_mode} #{n.emergency_address&.status || 'no emergency address'}"
    #   end
    def list
      response = @client.get("/voice/numbers")
      VoiceNumberList.new(response)
    end

    # Fetch one number's voice settings. Requires the +calls:read+ scope.
    #
    # @param number [String] The number's id or its E.164 phone number
    # @return [Sendly::VoiceNumber]
    # @raise [Sendly::ValidationError] If +number+ is blank
    # @raise [Sendly::NotFoundError] HTTP 404 +number_not_found+ when the
    #   number is not active in your workspace
    #
    # @example
    #   number = client.voice.numbers.get("+15555550188")
    #   puts number.voice_mode
    #   puts number.rate_per_minute.agent
    def get(number)
      response = @client.get(VoiceInput.number_path(number))
      VoiceNumber.new(response)
    end

    # Change how a number answers phone calls. Requires the +calls:write+
    # scope and a live key; in a team workspace, also a role that can change
    # settings.
    #
    # This changes what happens when real people call the number. Turning
    # voice on connects the number for calls before the change is saved and
    # answers in "ring_dashboard" mode unless +voice_mode+ is "agent".
    # A mode alone is enough: +voice_mode: "ring_dashboard"+ or +"agent"+
    # switches voice on, and +voice_mode: "none"+ switches it off.
    # +voice_enabled: false+ wins over any mode, and +voice_enabled: true+
    # with "none" answers in "ring_dashboard" mode.
    #
    # @param number [String] The number's id or its E.164 phone number
    # @param voice_enabled [Boolean, nil] Switch voice on or off
    # @param voice_mode [String, nil] One of {VoiceNumber::VOICE_MODES}
    # @param agent_id [String, nil] The agent that answers in "agent" mode.
    #   Needed (here or already stored) for "agent" mode, and the agent must
    #   be switched on. Pass +nil+ to clear the stored agent; leave it out to
    #   keep it.
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [Sendly::VoiceNumber] The number after the change
    # @raise [Sendly::ValidationError] If +number+ is blank, or HTTP 400
    #   +invalid_request+ (a wrongly typed field), +invalid_voice_mode+ or
    #   +agent_required+ ("agent" mode with no agent)
    # @raise [Sendly::NotFoundError] HTTP 404 +number_not_found+ / +agent_not_found+
    # @raise [Sendly::APIError] HTTP 409 +agent_disabled+ (the agent is
    #   switched off), 403 +forbidden+ / +live_key_required+
    # @raise [Sendly::ServerError] HTTP 502 +voice_attach_failed+ (voice could
    #   not be switched on; try again) or 503 +voice_unavailable+, after the
    #   client's automatic retries. Either can follow a mode alone on a number
    #   whose voice is off.
    #
    # @example Have an agent answer
    #   client.voice.numbers.update(
    #     "+15555550188",
    #     voice_enabled: true,
    #     voice_mode: "agent",
    #     agent_id: "3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b"
    #   )
    #
    # @example Ring the team in the dashboard instead
    #   client.voice.numbers.update("+15555550188", voice_mode: "ring_dashboard")
    def update(number, voice_enabled: nil, voice_mode: nil, agent_id: VoiceInput::OMIT, idempotency_key: nil)
      path = VoiceInput.number_path(number)
      body = {}
      body[:voiceEnabled] = voice_enabled unless voice_enabled.nil?
      body[:voiceMode] = voice_mode unless voice_mode.nil?
      body[:agentId] = agent_id unless VoiceInput::OMIT.equal?(agent_id)

      response = @client.patch(path, body, idempotency_key: idempotency_key)
      VoiceNumber.new(response)
    end

    # Register the street address emergency services are sent to when
    # someone calls them from this number. Requires the +calls:write+ scope
    # and a live key; in a team workspace, also a role that can change
    # settings.
    #
    # A US or Canadian number needs one before it can place calls. The first
    # registration adds $1.50 a month to the number; registering again
    # replaces the address without adding the charge a second time.
    #
    # @param number [String] The number's id or its E.164 phone number
    # @param street [String] Street address
    # @param city [String] City
    # @param state [String] Two-letter state or province code, e.g. "TX"
    # @param zip [String] Five-digit ZIP (or ZIP+4) in the US, a postal code
    #   like "A1A 1A1" in Canada
    # @param unit [String, nil] Apartment, suite or floor
    # @param country [String, nil] "US" or "CA" (the API defaults to "US")
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [Sendly::VoiceNumber] The number with its +emergency_address+
    # @raise [Sendly::ValidationError] If +number+, +street+, +city+, +state+
    #   or +zip+ is blank; HTTP 400 +invalid_request+ (a field that is not a
    #   string, such as +zip: 78701+), +invalid_address+ (a malformed field)
    #   or +e911_not_applicable+ (a number outside the US and Canada); or HTTP
    #   422 +invalid_address+ when the address could not be validated, with a
    #   corrected address (or +nil+) in +e.response_body["suggested"]+
    # @raise [Sendly::NotFoundError] HTTP 404 +number_not_found+
    # @raise [Sendly::ServerError] HTTP 502 +carrier_refused+ when the
    #   registration was refused, raised after the client has already retried
    #   the 5xx on its own. When the message says the number couldn't be
    #   found for emergency registration, retrying won't help: contact
    #   support. When it says the address couldn't be registered or emergency
    #   calling couldn't be switched on, try again later.
    #
    # @example
    #   number = client.voice.numbers.register_emergency_address(
    #     "+15555550188",
    #     street: "500 Example Ave",
    #     unit: "Suite 2",
    #     city: "Austin",
    #     state: "TX",
    #     zip: "78701"
    #   )
    #   puts number.emergency_address.status
    def register_emergency_address(number, street:, city:, state:, zip:, unit: nil, country: nil,
                                   idempotency_key: nil)
      path = "#{VoiceInput.number_path(number)}/emergency-address"
      VoiceInput.require_text!(street, "street is required")
      VoiceInput.require_text!(city, "city is required")
      VoiceInput.require_text!(state, "state is required")
      VoiceInput.require_text!(zip, "zip is required")

      body = { street: street }
      body[:unit] = unit unless unit.nil?
      body[:city] = city
      body[:state] = state
      body[:zip] = zip
      body[:country] = country unless country.nil?

      response = @client.post(path, body, idempotency_key: idempotency_key)
      VoiceNumber.new(response)
    end
  end

  # The AI agents that answer and place your phone calls. Reached as
  # +client.voice.agents+.
  class VoiceAgentsResource
    def initialize(client)
      @client = client
    end

    # List the workspace's AI agents with their call stats. Requires the
    # +calls:read+ scope.
    #
    # @return [Sendly::VoiceAgentList]
    #
    # @example
    #   client.voice.agents.list.each do |agent|
    #     puts "#{agent.name} (#{agent.voice_label}) #{agent.calls_handled} calls"
    #   end
    def list
      response = @client.get("/voice/agents")
      VoiceAgentList.new(response)
    end

    # Create an AI agent. Requires the +calls:write+ scope and a live key; in
    # a team workspace, also a role that can manage API keys.
    #
    # The agent answers real callers on any number pointed at it and talks on
    # the calls you place with it. Each agent gets its own scoped sending key
    # so it can text callers; {VoiceAgent#can_send_sms?} says whether it has
    # one. A workspace can have up to 20 agents.
    #
    # @param name [String] 1-80 characters
    # @param enabled [Boolean, nil] Whether the agent is switched on (the API
    #   defaults to +true+)
    # @param voice [String, nil] A voice id from {VoiceVoicesResource#list};
    #   an unknown id falls back to the default voice
    # @param language [String, nil] Language tag, up to 16 characters (the
    #   API defaults to "en-US")
    # @param greeting [String, nil] What the agent says when it picks up, up
    #   to 500 characters
    # @param instructions [String, nil] Business instructions the agent
    #   follows, up to 4000 characters
    # @param tools [Hash, nil] +send_sms:+ and +transfer_to:+ (see
    #   {VoiceAgentTools}); camelCase keys are accepted too. +send_sms+
    #   defaults to +true+ and +transfer_to+ to +nil+.
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [Sendly::VoiceAgent] The new agent
    # @raise [Sendly::ValidationError] If +name+ is blank, or HTTP 400
    #   +invalid_request+ naming the field the API rejected
    # @raise [Sendly::APIError] HTTP 409 +agent_limit+ when the workspace
    #   already has 20 agents, 403 +forbidden+ / +live_key_required+
    #
    # @example
    #   agent = client.voice.agents.create(
    #     name: "Front desk",
    #     voice: "ashley",
    #     greeting: "Thanks for calling Acme, how can I help?",
    #     instructions: "Answer questions about opening hours and take a message for anything else.",
    #     tools: { send_sms: true }
    #   )
    #   puts agent.id
    def create(name:, enabled: nil, voice: nil, language: nil, greeting: nil, instructions: nil,
               tools: nil, idempotency_key: nil)
      VoiceInput.require_text!(name, "name is required")

      body = VoiceInput.agent_body(
        name: name, enabled: enabled, voice: voice, language: language,
        greeting: greeting, instructions: instructions, tools: tools
      )
      response = @client.post("/voice/agents", body, idempotency_key: idempotency_key)
      VoiceAgent.new(response)
    end

    # Fetch one agent. Requires the +calls:read+ scope.
    #
    # @param id [String] Agent identifier
    # @return [Sendly::VoiceAgent]
    # @raise [Sendly::ValidationError] If +id+ is blank
    # @raise [Sendly::NotFoundError] HTTP 404 +agent_not_found+ when the
    #   agent is not in your workspace
    #
    # @example
    #   agent = client.voice.agents.get("3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b")
    #   puts agent.greeting
    def get(id)
      response = @client.get(VoiceInput.agent_path(id))
      VoiceAgent.new(response)
    end

    # Update an agent. Requires the +calls:write+ scope and a live key; in a
    # team workspace, also a role that can manage API keys. Pass only what
    # changes; +tools+ keys you leave out keep their current values.
    #
    # @param id [String] Agent identifier
    # @param name [String, nil] 1-80 characters
    # @param enabled [Boolean, nil] Switch the agent on or off
    # @param voice [String, nil] A voice id from {VoiceVoicesResource#list};
    #   an unknown id falls back to the default voice
    # @param language [String, nil] Language tag, up to 16 characters; +""+
    #   resets it to "en-US"
    # @param greeting [String, nil] Up to 500 characters; +""+ clears it
    # @param instructions [String, nil] Up to 4000 characters; +""+ clears it
    # @param tools [Hash, nil] Tool settings to change (+send_sms:+,
    #   +transfer_to:+); +transfer_to: nil+ clears the number
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [Sendly::VoiceAgent] The agent after the change
    # @raise [Sendly::ValidationError] If +id+ is blank, or HTTP 400
    #   +invalid_request+ naming the field the API rejected
    # @raise [Sendly::NotFoundError] HTTP 404 +agent_not_found+
    #
    # @example
    #   client.voice.agents.update(
    #     "3c4d5e6f-7081-4293-a4b5-c6d7e8f90a1b",
    #     greeting: "Thanks for calling Acme. How can I help today?",
    #     tools: { send_sms: false }
    #   )
    def update(id, name: nil, enabled: nil, voice: nil, language: nil, greeting: nil, instructions: nil,
               tools: nil, idempotency_key: nil)
      path = VoiceInput.agent_path(id)
      body = VoiceInput.agent_body(
        name: name, enabled: enabled, voice: voice, language: language,
        greeting: greeting, instructions: instructions, tools: tools
      )

      response = @client.patch(path, body, idempotency_key: idempotency_key)
      VoiceAgent.new(response)
    end

    # Delete an agent and revoke its sending key. Requires the +calls:write+
    # scope and a live key; in a team workspace, also a role that can manage
    # API keys.
    #
    # An agent that answers a number can't be deleted: the API responds 409
    # +agent_in_use+ and +e.response_body["numbers"]+ lists those numbers.
    # Point them at another agent or back to the team first with
    # {VoiceNumbersResource#update}.
    #
    # @param id [String] Agent identifier
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [Sendly::DeletedVoiceAgent]
    # @raise [Sendly::ValidationError] If +id+ is blank
    # @raise [Sendly::NotFoundError] HTTP 404 +agent_not_found+
    # @raise [Sendly::APIError] HTTP 409 +agent_in_use+
    #
    # @example
    #   begin
    #     client.voice.agents.delete(agent.id)
    #   rescue Sendly::APIError => e
    #     raise unless e.response_body&.dig("error") == "agent_in_use"
    #
    #     e.response_body["numbers"].each do |number|
    #       client.voice.numbers.update(number, voice_mode: "ring_dashboard")
    #     end
    #     client.voice.agents.delete(agent.id)
    #   end
    def delete(id, idempotency_key: nil)
      response = @client.delete(VoiceInput.agent_path(id), idempotency_key: idempotency_key)
      DeletedVoiceAgent.new(response)
    end
  end

  # The voices an agent can speak with. Reached as +client.voice.voices+.
  class VoiceVoicesResource
    def initialize(client)
      @client = client
    end

    # List the voices an agent can speak with. Requires the +calls:read+
    # scope.
    #
    # @return [Sendly::VoiceList]
    #
    # @example
    #   client.voice.voices.list.each { |v| puts "#{v.id}: #{v.label}" }
    def list
      response = @client.get("/voice/voices")
      VoiceList.new(response)
    end
  end

  # Voice resource: configure everything a phone call depends on, from code.
  # {#numbers} switches voice on for a number, chooses how it answers and
  # registers its emergency address; {#agents} manages the AI agents that
  # talk on calls; {#voices} lists the voices those agents can use.
  #
  # Reads need the +calls:read+ scope; writes need +calls:write+ and a live
  # API key (+sk_live_v1_xxx+). In a team workspace, number and emergency
  # address changes also need a role that can change settings, and agent
  # changes a role that can manage API keys (each agent holds its own scoped
  # sending key); otherwise the API responds 403 +forbidden+.
  #
  # Voice is enabled workspace by workspace. Until it is on for yours,
  # every method here raises {Sendly::NotFoundError} (+voice_not_enabled+).
  #
  # Error codes map onto the usual classes: {Sendly::NotFoundError} for
  # +voice_not_enabled+, +number_not_found+ and +agent_not_found+;
  # {Sendly::ValidationError} for +invalid_request+, +invalid_voice_mode+,
  # +agent_required+, +invalid_address+ (400 and 422) and
  # +e911_not_applicable+; {Sendly::APIError} with the HTTP status for
  # +agent_disabled+ / +agent_limit+ / +agent_in_use+ (409) and +forbidden+
  # / +live_key_required+ / +insufficient_permissions+ (403); and
  # {Sendly::ServerError} (not an +APIError+) for +voice_attach_failed+ /
  # +carrier_refused+ (502), +voice_unavailable+ (503) and
  # +voice_internal_error+ (500). Every API error keeps the parsed body on
  # {Sendly::Error#response_body}. The full list is {Call::ERROR_CODES}.
  #
  # @example Have a new agent answer a number
  #   agent = client.voice.agents.create(name: "Front desk", greeting: "Thanks for calling Acme, how can I help?")
  #   client.voice.numbers.register_emergency_address(
  #     "+15555550188", street: "500 Example Ave", city: "Austin", state: "TX", zip: "78701"
  #   )
  #   client.voice.numbers.update("+15555550188", voice_enabled: true, voice_mode: "agent", agent_id: agent.id)
  class VoiceResource
    # @return [VoiceNumbersResource] Voice settings and emergency addresses for your numbers
    attr_reader :numbers

    # @return [VoiceAgentsResource] The AI agents that talk on calls
    attr_reader :agents

    # @return [VoiceVoicesResource] The voices agents can speak with
    attr_reader :voices

    def initialize(client)
      @client = client
      @numbers = VoiceNumbersResource.new(client)
      @agents = VoiceAgentsResource.new(client)
      @voices = VoiceVoicesResource.new(client)
    end
  end
end
