# frozen_string_literal: true

require 'openssl'
require 'json'

module Sendly
  # Webhook utilities for verifying and parsing Sendly webhook events.
  #
  # @example In a Rails controller
  #   class WebhooksController < ApplicationController
  #     skip_before_action :verify_authenticity_token
  #
  #     def handle
  #       signature = request.headers['X-Sendly-Signature']
  #       timestamp = request.headers['X-Sendly-Timestamp']
  #       payload = request.raw_post
  #
  #       begin
  #         event = Sendly::Webhooks.parse_event(payload, signature, ENV['WEBHOOK_SECRET'], timestamp: timestamp)
  #
  #         case event.type
  #         when 'message.delivered'
  #           puts "Message delivered: #{event.message.id}"
  #         when 'message.failed'
  #           puts "Message failed: #{event.message.error}"
  #         when 'rcs_agent.live'
  #           # A lifecycle payload is not message-shaped. event.message is nil
  #           # for it; read data.object through event.data or event.raw_object.
  #           puts "RCS agent live: #{event.data[:agent_id]}"
  #         end
  #
  #         head :ok
  #       rescue Sendly::WebhookSignatureError
  #         head :unauthorized
  #       end
  #     end
  #   end
  module Webhooks
    SIGNATURE_TOLERANCE_SECONDS = 300

    # Webhook event type string constants. Use these when subscribing
    # instead of string literals so you catch typos at load time.
    # Deprecated: the API has never emitted this and rejects it when you
    # subscribe. It will be removed in the next major version.
    EVENT_MESSAGE_QUEUED                = "message.queued"

    EVENT_MESSAGE_SENT                  = "message.sent"
    EVENT_MESSAGE_DELIVERED             = "message.delivered"
    EVENT_MESSAGE_READ                  = "message.read"
    EVENT_MESSAGE_FAILED                = "message.failed"
    EVENT_MESSAGE_BOUNCED               = "message.bounced"
    EVENT_MESSAGE_RETRYING              = "message.retrying"
    EVENT_MESSAGE_RECEIVED              = "message.received"
    EVENT_MESSAGE_OPT_OUT               = "message.opt_out"
    EVENT_MESSAGE_OPT_IN                = "message.opt_in"
    EVENT_VERIFICATION_CREATED          = "verification.created"
    EVENT_VERIFICATION_DELIVERED        = "verification.delivered"
    EVENT_VERIFICATION_VERIFIED         = "verification.verified"
    EVENT_VERIFICATION_EXPIRED          = "verification.expired"
    EVENT_VERIFICATION_FAILED           = "verification.failed"
    EVENT_VERIFICATION_RESENT           = "verification.resent"
    EVENT_VERIFICATION_DELIVERY_FAILED  = "verification.delivery_failed"
    EVENT_CONVERSATION_CREATED          = "conversation.created"
    EVENT_CONVERSATION_UPDATED          = "conversation.updated"
    EVENT_DRAFT_CREATED                 = "draft.created"
    EVENT_DRAFT_APPROVED                = "draft.approved"
    EVENT_DRAFT_REJECTED                = "draft.rejected"
    EVENT_CONTACT_AUTO_FLAGGED          = "contact.auto_flagged"
    EVENT_CONTACT_MARKED_VALID          = "contact.marked_valid"
    EVENT_CONTACTS_LOOKUP_COMPLETED     = "contacts.lookup_completed"
    EVENT_CONTACTS_BULK_MARKED_VALID    = "contacts.bulk_marked_valid"
    EVENT_BRAND_VERIFIED                = "brand.verified"
    EVENT_BRAND_FAILED                  = "brand.failed"
    EVENT_CAMPAIGN_APPROVED             = "campaign.approved"
    EVENT_CAMPAIGN_REJECTED             = "campaign.rejected"
    EVENT_CAMPAIGN_SUSPENDED            = "campaign.suspended"
    EVENT_ASSIGNMENT_CONFIRMED          = "assignment.confirmed"
    EVENT_ASSIGNMENT_FAILED             = "assignment.failed"
    EVENT_RCS_BRAND_VERIFIED            = "rcs_brand.verified"
    EVENT_RCS_BRAND_FAILED              = "rcs_brand.failed"
    EVENT_RCS_AGENT_TESTING             = "rcs_agent.testing"
    EVENT_RCS_AGENT_LIVE                = "rcs_agent.live"
    EVENT_RCS_AGENT_REJECTED            = "rcs_agent.rejected"
    EVENT_RCS_AGENT_ACTION_REQUIRED     = "rcs_agent.action_required"
    EVENT_PORT_COMPLETED                = "port.completed"
    EVENT_PORT_OUT_REQUESTED            = "port_out.requested"
    EVENT_PORT_OUT_COMPLETED            = "port_out.completed"
    EVENT_PORT_OUT_REJECTED             = "port_out.rejected"
    EVENT_PORT_OUT_CANCELLED            = "port_out.cancelled"
    EVENT_NUMBER_ACTIVATED              = "number.activated"
    EVENT_NUMBER_FAILED                 = "number.failed"
    EVENT_NUMBER_REQUIREMENTS_REQUIRED  = "number.requirements_required"
    EVENT_NUMBER_RELEASED               = "number.released"
    EVENT_WHATSAPP_ACCOUNT_CONNECTED    = "whatsapp_account.connected"
    EVENT_WHATSAPP_ACCOUNT_FAILED       = "whatsapp_account.failed"
    EVENT_WHATSAPP_TEMPLATE_APPROVED    = "whatsapp_template.approved"
    EVENT_WHATSAPP_TEMPLATE_REJECTED    = "whatsapp_template.rejected"
    EVENT_WHATSAPP_TEMPLATE_PAUSED      = "whatsapp_template.paused"
    EVENT_CALL_STARTED                  = "call.started"
    EVENT_CALL_COMPLETED                = "call.completed"
    EVENT_CALL_RECORDING_READY          = "call.recording.ready"

    # Source of a list-health event. Frozen enum — new values will be
    # added in minor SDK versions, never removed.
    module ListHealthEventSource
      SEND_FAILURE    = "send_failure"
      CARRIER_LOOKUP  = "carrier_lookup"
      USER_ACTION     = "user_action"
      BULK_MARK_VALID = "bulk_mark_valid"

      ALL = [SEND_FAILURE, CARRIER_LOOKUP, USER_ACTION, BULK_MARK_VALID].freeze
    end

    class << self
      # Verify webhook signature from Sendly.
      #
      # @param payload [String] Raw request body as string
      # @param signature [String] X-Sendly-Signature header value
      # @param secret [String] Your webhook secret from dashboard
      # @param timestamp [String, nil] X-Sendly-Timestamp header value (recommended)
      # @return [Boolean] True if signature is valid, false otherwise
      def verify_signature(payload, signature, secret, timestamp: nil)
        return false if payload.nil? || payload.empty?
        return false if signature.nil? || signature.empty?
        return false if secret.nil? || secret.empty?

        if timestamp
          signed_payload = "#{timestamp}.#{payload}"
          return false if (Time.now.to_i - timestamp.to_i).abs > SIGNATURE_TOLERANCE_SECONDS
        else
          signed_payload = payload
        end

        expected = 'sha256=' + OpenSSL::HMAC.hexdigest('SHA256', secret, signed_payload)

        secure_compare(expected, signature)
      end

      # Parse and validate a webhook event.
      #
      # @param payload [String] Raw request body as string
      # @param signature [String] X-Sendly-Signature header value
      # @param secret [String] Your webhook secret from dashboard
      # @param timestamp [String, nil] X-Sendly-Timestamp header value (recommended)
      # @return [WebhookEvent] Parsed and validated event
      # @raise [WebhookSignatureError] If signature is invalid or payload is malformed
      def parse_event(payload, signature, secret, timestamp: nil)
        unless verify_signature(payload, signature, secret, timestamp: timestamp)
          raise WebhookSignatureError, 'Invalid webhook signature'
        end

        data = JSON.parse(payload, symbolize_names: true)

        unless data[:id] && data[:type] && data[:data]
          raise WebhookSignatureError, 'Invalid event structure'
        end

        WebhookEvent.new(data)
      rescue JSON::ParserError => e
        raise WebhookSignatureError, "Failed to parse webhook payload: #{e.message}"
      end

      # Generate a webhook signature for testing purposes.
      #
      # @param payload [String] The payload to sign
      # @param secret [String] The secret to use for signing
      # @param timestamp [String, nil] Optional timestamp to include in signature
      # @return [String] The signature in the format "sha256=..."
      def generate_signature(payload, secret, timestamp: nil)
        signed_payload = timestamp ? "#{timestamp}.#{payload}" : payload
        'sha256=' + OpenSSL::HMAC.hexdigest('SHA256', secret, signed_payload)
      end

      private

      def secure_compare(a, b)
        return false unless a.bytesize == b.bytesize

        l = a.unpack('C*')
        res = 0
        b.each_byte { |byte| res |= byte ^ l.shift }
        res.zero?
      end
    end
  end

  class WebhookSignatureError < Error
    def initialize(message = 'Invalid webhook signature')
      super(message, code: 'WEBHOOK_SIGNATURE_ERROR')
    end
  end

  # A hash-like view of a webhook event's +data.object+.
  #
  # Every key the payload carried is reachable — by +[]+ with a String or a
  # Symbol, by {#to_h}, or as a reader method of the same name — and nothing
  # else is. A key the payload did not carry is absent rather than filled in
  # with a plausible-looking default, and a key that arrived as JSON +null+
  # stays +nil+.
  #
  # @example An rcs_agent.live payload
  #   event.data[:agent_id]    # => "bb22cc33-dd44-4e55-9f66-001122334455"
  #   event.data.stage         # => "live"
  #   event.data.key?(:from)   # => false — an RCS agent event has no from
  class WebhookObject
    include Enumerable

    # Names that must keep Ruby's meaning even if a payload carries them as a
    # key. Overriding these on an instance breaks object identity, equality or
    # dispatch, so a reader is never defined for them — reach those keys with
    # +[]+, +fetch+ or +to_h+, which always read the payload.
    RESERVED = %i[
      __send__ __id__ object_id class singleton_class method methods
      instance_variable_get instance_variable_set instance_variables
      respond_to? equal? is_a? kind_of? instance_of? nil? tap raw
    ].freeze

    # @return [Hash] +data.object+ exactly as it arrived
    attr_reader :raw

    # @param raw [Hash] the parsed +data.object+
    def initialize(raw = {})
      @raw = raw.is_a?(Hash) ? raw : {}
      define_payload_readers
    end

    # @param key [String, Symbol]
    # @return [Object, nil] nil when the payload did not carry the key
    def [](key)
      resolved = resolve_key(key)
      resolved.nil? ? nil : @raw[resolved]
    end

    # @param key [String, Symbol]
    # @return [Object] the value, the default, or the block's result
    # @raise [KeyError] if the key is absent and no default was given
    def fetch(key, *default, &block)
      resolved = resolve_key(key)
      return @raw[resolved] unless resolved.nil?
      return default.first unless default.empty?
      return block.call(key) if block

      raise KeyError, "key not found: #{key.inspect}"
    end

    def dig(key, *rest)
      value = self[key]
      return value if rest.empty? || value.nil?

      value.dig(*rest)
    end

    # @return [Boolean] whether the payload carried this key at all. Use it to
    #   tell "absent" from "arrived as null".
    def key?(key)
      !resolve_key(key).nil?
    end
    alias has_key? key?

    def keys
      @raw.keys
    end

    def values
      @raw.values
    end

    def each(&block)
      @raw.each(&block)
    end

    def empty?
      @raw.empty?
    end

    def size
      @raw.size
    end
    alias length size

    # @return [Hash] a copy of +data.object+. Absent keys stay absent and
    #   nulls stay nil; nothing is added.
    def to_h
      @raw.dup
    end

    def ==(other)
      case other
      when WebhookObject then @raw == other.raw
      when Hash then @raw == other
      else false
      end
    end

    def inspect
      "#<#{self.class.name} #{@raw.inspect}>"
    end

    # @return [Array<Symbol>] payload keys that cannot be read as a method
    #   because doing so would override Ruby's own semantics. Read them with
    #   +[]+ instead.
    def reserved_keys
      @raw.keys.map { |k| k.to_sym rescue nil }.compact & RESERVED
    end

    private

    # Payload keys win over inherited methods.
    #
    # Reader access used to go through method_missing, which only fires when
    # nothing else answers — so any key colliding with an Object or Enumerable
    # method was silently shadowed. `contacts.bulk_marked_valid` really carries
    # `count`, so `event.data.count` returned the NUMBER OF KEYS instead of the
    # value, and respond_to?(:count) was true, giving the caller no signal.
    # Defining a singleton reader per key makes the payload authoritative.
    def define_payload_readers
      singleton = singleton_class
      @raw.each_key do |key|
        name = begin
          key.to_sym
        rescue StandardError
          next
        end
        next if RESERVED.include?(name)
        next unless name.to_s.match?(/\A[A-Za-z_][A-Za-z0-9_]*[?!]?\z/)

        singleton.define_method(name) { @raw[key] }
      end
    end

    def resolve_key(key)
      return key if @raw.key?(key)

      case key
      when Symbol then @raw.key?(key.to_s) ? key.to_s : nil
      when String then @raw.key?(key.to_sym) ? key.to_sym : nil
      end
    end

    def method_missing(name, *args, &block)
      key = args.empty? && block.nil? ? resolve_key(name) : nil
      return @raw[key] unless key.nil?

      carries = @raw.empty? ? 'no fields' : @raw.keys.map(&:to_s).join(', ')
      raise NoMethodError.new(
        "undefined method '#{name}' for #{self.class.name}: " \
        "this event's data.object carries #{carries}",
        name
      )
    end

    def respond_to_missing?(name, include_private = false)
      !resolve_key(name).nil? || super
    end
  end

  # The message view of +data.object+, built only for +message.*+ events.
  #
  # Readers return exactly what the payload carried. An absent field is +nil+:
  # this class does not invent +segments+, +credits_used+, +direction+, +to+
  # or +from+.
  class WebhookMessageData < WebhookObject
    attr_reader :id, :status, :to, :from, :direction, :organization_id,
                :text, :error, :error_code, :delivered_at, :failed_at,
                :created_at, :segments, :credits_used, :message_format,
                :media_urls, :retry_count, :metadata, :batch_id

    def initialize(data = {})
      super
      # Both spellings name the same message: the current payload shape uses
      # `id`, the pre-`data.object` shape used `message_id`.
      @id = self[:id] || self[:message_id]
      @status = self[:status]
      @to = self[:to]
      @from = self[:from]
      @direction = self[:direction]
      @organization_id = self[:organization_id]
      @text = self[:text]
      @error = self[:error]
      @error_code = self[:error_code]
      @delivered_at = self[:delivered_at]
      @failed_at = self[:failed_at]
      @created_at = self[:created_at]
      @segments = self[:segments]
      @credits_used = self[:credits_used]
      @message_format = self[:message_format]
      @media_urls = self[:media_urls]
      @retry_count = self[:retry_count]
      @metadata = self[:metadata]
      @batch_id = self[:batch_id]
    end

    # Backwards-compatible alias for {#id}.
    def message_id
      @id
    end
  end

  # The verification view of +data.object+, built only for +verification.*+
  # events. Readers carry what the payload held and nothing more.
  class WebhookVerificationData < WebhookObject
    attr_reader :id, :organization_id, :phone, :status, :delivery_status,
                :attempts, :max_attempts, :expires_at, :verified_at,
                :created_at, :app_name, :template_id, :profile_id, :metadata

    def initialize(data = {})
      super
      @id = self[:id]
      @organization_id = self[:organization_id]
      @phone = self[:phone]
      @status = self[:status]
      @delivery_status = self[:delivery_status]
      @attempts = self[:attempts]
      @max_attempts = self[:max_attempts]
      @expires_at = self[:expires_at]
      @verified_at = self[:verified_at]
      @created_at = self[:created_at]
      @app_name = self[:app_name]
      @template_id = self[:template_id]
      @profile_id = self[:profile_id]
      @metadata = self[:metadata]
    end
  end

  # A parsed webhook event.
  #
  # {#raw_object} is +data.object+ exactly as it arrived, for every event type.
  # {#data} adds a typed view on top of it where one applies: a
  # {WebhookMessageData} for +message.*+, a {WebhookVerificationData} for
  # +verification.*+, and a plain {WebhookObject} for everything else —
  # +rcs_*+, +whatsapp_*+, +call.*+, +brand.*+, +campaign.*+, +assignment.*+,
  # +number.*+, +port*+, +contact*+, +conversation.*+ and +draft.*+, whose
  # payloads are not message-shaped.
  #
  # @example Handling a lifecycle event
  #   case event.type
  #   when Sendly::Webhooks::EVENT_MESSAGE_DELIVERED
  #     puts event.message.id
  #   when Sendly::Webhooks::EVENT_RCS_AGENT_LIVE
  #     puts event.data[:agent_id]
  #   end
  class WebhookEvent
    MESSAGE_EVENT_PREFIX = 'message.'

    # message.opt_in and message.opt_out share the message.* prefix but carry
    # an opt-out record ({phone_number, keyword, from_number, timestamp}), not
    # a message. Treating them as messages produced a message view with every
    # field nil, which is the invented-value problem this class removes.
    NON_MESSAGE_MESSAGE_EVENTS = ['message.opt_in', 'message.opt_out'].freeze
    VERIFICATION_EVENT_PREFIX = 'verification.'

    # @return [String] event id, for idempotency
    attr_reader :id

    # @return [String] event type, verbatim — including one this SDK predates
    attr_reader :type

    # @return [Hash] +data.object+ exactly as it arrived, for every event type
    attr_reader :raw_object

    # @return [WebhookObject] hash-like view of +data.object+. A
    #   {WebhookMessageData} for +message.*+ events and a
    #   {WebhookVerificationData} for +verification.*+ events; a plain
    #   {WebhookObject} otherwise.
    attr_reader :data

    # @return [WebhookMessageData, nil] the message view, or nil when this
    #   event is not a message. Lifecycle events return nil rather than a
    #   message struct full of invented values.
    attr_reader :message

    # @return [WebhookVerificationData, nil] the verification view, or nil
    #   when this event is not a +verification.*+ event
    attr_reader :verification

    attr_reader :created, :api_version, :livemode

    def initialize(payload)
      env = payload.is_a?(WebhookObject) ? payload : WebhookObject.new(payload)

      @id = env[:id]
      @type = env[:type]
      @raw_object = extract_object(env[:data])
      @created = env[:created] || env[:created_at] || 0
      @api_version = env[:api_version] || '2024-01'
      @livemode = env[:livemode] || false

      @message = message? ? WebhookMessageData.new(@raw_object) : nil
      @verification = verification? ? WebhookVerificationData.new(@raw_object) : nil
      @data = @message || @verification || WebhookObject.new(@raw_object)
    end

    # @return [Hash] alias for {#raw_object}
    def object
      @raw_object
    end

    # Read +data.object+ as a type of your choosing — the supported way to
    # handle a lifecycle payload with a typed object.
    #
    # A Struct or Data class is filled from the members it declares, and the
    # rest of the payload is ignored, so a field added to the event later
    # cannot break the call. Any other class is handed +raw_object+ itself.
    #
    # @example
    #   AgentLive = Struct.new(:agent_id, :name, :stage)
    #   agent = event.object_as(AgentLive)   # => #<struct AgentLive ...>
    #
    # @param klass [Class] a Struct or Data class, or anything whose
    #   initializer takes a Hash
    # @return [Object]
    def object_as(klass)
      return klass.new(@raw_object) unless klass.respond_to?(:members)

      values = klass.members.map { |member| @data[member] }
      begin
        klass.new(*values)
      rescue ArgumentError
        klass.new(**klass.members.zip(values).to_h)
      end
    end

    # @return [Boolean] whether this event carries a message
    def message?
      @type.to_s.start_with?(MESSAGE_EVENT_PREFIX) &&
        !NON_MESSAGE_MESSAGE_EVENTS.include?(@type.to_s)
    end

    # @return [Boolean] whether this event carries a verification
    def verification?
      @type.to_s.start_with?(VERIFICATION_EVENT_PREFIX)
    end

    def created_at
      @created
    end

    def to_h
      {
        id: @id,
        type: @type,
        data: @data.to_h,
        created: @created,
        api_version: @api_version,
        livemode: @livemode
      }
    end

    private

    def extract_object(data)
      return {} unless data.is_a?(Hash)

      object = data.key?(:object) ? data[:object] : data['object']
      object.is_a?(Hash) ? object : data
    end
  end
end
