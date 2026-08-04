# frozen_string_literal: true

module Sendly
  # An RCS agent registered for your workspace — the branded identity your
  # RCS messages come from. +status+ moves +"draft"+ → +"submitted"+ →
  # +"testing"+ (can send, but only to invited test devices) → +"approved"+
  # (can send to everyone); +"suspended"+ agents cannot send. +sendable+ is
  # true when the agent is fully provisioned and its status allows sending.
  class RcsAgent
    attr_reader :id, :name, :status, :use_case, :sendable, :created_at

    STATUSES = %w[draft submitted testing approved suspended].freeze

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @status = data["status"]
      @use_case = data["useCase"] || data["use_case"]
      @sendable = data["sendable"] || false
      @created_at = data["createdAt"] || data["created_at"]
    end

    def sendable?
      sendable
    end

    def approved?
      status == "approved"
    end

    def to_h
      {
        id: id, name: name, status: status, use_case: use_case,
        sendable: sendable, created_at: created_at
      }.compact
    end
  end

  # Whether a recipient's device and network can receive RCS. When
  # +capable+ is false, a text send to this recipient falls back to plain
  # SMS (unless the fallback is disabled) and a card send fails. +features+
  # lists the feature tags the device reports.
  class RcsCapability
    attr_reader :to, :agent_id, :capable, :features

    def initialize(data)
      @to = data["to"]
      @agent_id = data["agentId"] || data["agent_id"]
      @capable = data["capable"] || false
      @features = data["features"] || []
    end

    def capable?
      capable
    end

    def to_h
      { to: to, agent_id: agent_id, capable: capable, features: features }.compact
    end
  end

  # RCS-specific details on a sent message. On a native RCS delivery +kind+
  # is what was sent ("text" or "card") and +agent_name+ is the brand name
  # recipients see. On an SMS fallback +requested_channel+ is "rcs" and
  # +suggestions_dropped+ is true when suggested replies/actions were
  # dropped (they have no SMS form).
  class RcsMessageDetails
    attr_reader :kind, :agent_id, :agent_name, :requested_channel,
                :suggestions_dropped

    KINDS = %w[text card].freeze

    def initialize(data)
      @kind = data["kind"]
      @agent_id = data["agentId"] || data["agent_id"]
      @agent_name = data["agentName"] || data["agent_name"]
      @requested_channel = data["requestedChannel"] || data["requested_channel"]
      @suggestions_dropped = data["suggestionsDropped"] || data["suggestions_dropped"] || false
    end

    def to_h
      {
        kind: kind, agent_id: agent_id, agent_name: agent_name,
        requested_channel: requested_channel,
        suggestions_dropped: suggestions_dropped
      }.compact
    end
  end

  # A message sent through the RCS channel. +channel+ is "rcs" when it was
  # delivered as RCS, or "sms" when the recipient couldn't receive RCS and
  # the message fell back to plain SMS — check with {#fell_back?}. On a
  # fallback +fell_back_to+ is "sms" and +segments+/+credits_used+ are
  # billed as SMS; +rcs+ carries the channel-specific details either way.
  class RcsMessage
    attr_reader :id, :channel, :fell_back_to, :message_format, :to, :from,
                :text, :status, :segments, :credits_used, :rcs, :created_at,
                :metadata

    def initialize(data)
      @id = data["id"]
      @channel = data["channel"] || "rcs"
      @fell_back_to = data["fellBackTo"] || data["fell_back_to"]
      @message_format = data["message_format"] || data["messageFormat"] || @channel
      @to = data["to"]
      @from = data["from"]
      @text = data["text"]
      @status = data["status"]
      @segments = data["segments"] || 1
      @credits_used = data["creditsUsed"] || data["credits_used"] || 0
      @rcs = data["rcs"] ? RcsMessageDetails.new(data["rcs"]) : nil
      @created_at = data["createdAt"] || data["created_at"]
      @metadata = data["metadata"]
    end

    def fell_back?
      fell_back_to == "sms"
    end

    def delivered?
      status == "delivered"
    end

    def failed?
      status == "failed"
    end

    def to_h
      {
        id: id, channel: channel, fell_back_to: fell_back_to,
        message_format: message_format, to: to, from: from, text: text,
        status: status, segments: segments, credits_used: credits_used,
        rcs: rcs&.to_h, created_at: created_at, metadata: metadata
      }.compact
    end
  end

  # List the RCS agents registered for your workspace.
  class RcsAgentsResource
    def initialize(client)
      @client = client
    end

    # List your RCS agents, newest first. An empty list means no agent is
    # set up yet — contact support to register an RCS agent for your brand.
    #
    # @return [Hash] +{ agents: Array<RcsAgent> }+
    #
    # @example
    #   client.rcs.agents.list[:agents].each do |a|
    #     puts "#{a.name} — #{a.status}#{a.sendable? ? ' (sendable)' : ''}"
    #   end
    def list
      response = @client.get("/rcs/agents")
      agents = (response["agents"] || []).map { |a| RcsAgent.new(a) }
      { agents: agents }
    end
  end

  # RCS resource — discover your RCS agents and pre-flight recipient
  # capability.
  #
  # RCS is a first-class Sendly channel: send branded rich messages — text
  # with suggested replies and actions, or rich cards — via
  # +client.messages.send(channel: "rcs", ...)+. RCS agents are registered
  # by Sendly for your brand; contact support to set one up, then discover
  # it with {RcsAgentsResource#list}.
  #
  # Delivery is per-recipient: not every device or network supports RCS.
  # Text messages fall back to plain SMS automatically (billed as SMS)
  # unless you pass +fallback_to_sms: false+; rich cards have no SMS form
  # and only deliver to RCS-capable recipients. Use {#capability} to check
  # a recipient before sending.
  #
  # RCS sends and capability checks require a live API key
  # (+sk_live_v1_xxx+).
  #
  # @example Check capability, then send
  #   cap = client.rcs.capability(to: "+15551234567")
  #   if cap.capable?
  #     client.messages.send(
  #       channel: "rcs",
  #       to: "+15551234567",
  #       text: "Your order has shipped!"
  #     )
  #   end
  class RcsResource
    # @return [RcsAgentsResource] List registered agents
    attr_reader :agents

    def initialize(client)
      @client = client
      @agents = RcsAgentsResource.new(client)
    end

    # Check whether a recipient can receive RCS.
    #
    # Probes the recipient's device and network. When the recipient is not
    # capable, a text send falls back to plain SMS (unless the fallback is
    # disabled) and a card send fails with
    # +rcs_not_supported_for_recipient+.
    #
    # @param to [String] The recipient's number, in E.164 format
    # @param agent_id [String, nil] The agent to probe with. Optional when
    #   your workspace has exactly one sendable agent; required (the API
    #   responds 400 +rcs_agent_ambiguous+) when it has more.
    # @return [RcsCapability]
    #
    # @example
    #   cap = client.rcs.capability(to: "+15551234567")
    #   puts cap.capable?
    #   puts cap.features.inspect
    def capability(to:, agent_id: nil)
      raise ValidationError, "to is required" if to.nil? || to.to_s.empty?

      params = { to: to }
      params[:agentId] = agent_id if agent_id
      response = @client.get("/rcs/capability", params)
      RcsCapability.new(response)
    end
  end
end
