# frozen_string_literal: true

module Sendly
  # Represents an SMS message
  class Message
    # @return [String] Unique message identifier
    attr_reader :id

    # @return [String] Recipient phone number
    attr_reader :to

    # @return [String, nil] Sender ID or phone number
    attr_reader :from

    # @return [String] Message content
    attr_reader :text

    # @return [String] Delivery status
    attr_reader :status

    # @return [String] Message direction (outbound or inbound)
    attr_reader :direction

    # @return [String, nil] Error message if failed
    attr_reader :error

    # @return [Integer] Number of SMS segments
    attr_reader :segments

    # @return [Integer] Credits used
    attr_reader :credits_used

    # @return [Boolean] Whether sent in sandbox mode
    attr_reader :is_sandbox

    # @return [String, nil] How the message was sent (number_pool, alphanumeric, sandbox)
    attr_reader :sender_type

    # @return [String, nil] Carrier message ID for tracking
    attr_reader :telnyx_message_id

    # @return [String, nil] Warning message
    attr_reader :warning

    # @return [String, nil] Note about sender behavior
    attr_reader :sender_note

    # @return [Time, nil] Creation timestamp
    attr_reader :created_at

    # @return [Time, nil] Delivery timestamp
    attr_reader :delivered_at

    # @return [String, nil] Error code if delivery failed
    attr_reader :error_code

    # @return [Integer] Number of delivery retry attempts
    attr_reader :retry_count

    # @return [Hash, nil] Custom metadata attached to the message
    attr_reader :metadata

    # @return [Hash, nil] AI classification metadata for inbound messages
    attr_reader :ai_metadata

    # @return [Array<String>] Media attached to the message; empty when there is none
    attr_reader :media_urls

    # @return [String] "sms", "mms", "rcs" or "whatsapp"; "sms" when the response does not say
    attr_reader :message_format

    # Message status constants (sending removed - doesn't exist in database)
    STATUSES = %w[queued sent delivered failed bounced retrying].freeze

    # Sender type constants
    SENDER_TYPES = %w[number_pool alphanumeric sandbox].freeze

    def initialize(data)
      @id = data["id"]
      @to = data["to"]
      @from = data["from"]
      @text = data["text"]
      @status = data["status"]
      @direction = data["direction"] || "outbound"
      @error = data["error"]
      @segments = data["segments"] || 1
      @credits_used = data["creditsUsed"] || 0
      @is_sandbox = data["isSandbox"] || false
      @sender_type = data["senderType"]
      @telnyx_message_id = data["telnyxMessageId"]
      @warning = data["warning"]
      @sender_note = data["senderNote"]
      @created_at = parse_time(data["createdAt"])
      @delivered_at = parse_time(data["deliveredAt"])
      @error_code = data["errorCode"]
      @retry_count = data["retryCount"] || 0
      @metadata = data["metadata"]
      @ai_metadata = data["aiMetadata"]
      @media_urls = data["mediaUrls"] || data["media_urls"] || []
      @message_format = data["messageFormat"] || data["message_format"] || "sms"
    end

    # Check if message was delivered
    # @return [Boolean]
    def delivered?
      status == "delivered"
    end

    # Check if message failed
    # @return [Boolean]
    def failed?
      status == "failed"
    end

    # Check if message is pending
    # @return [Boolean]
    def pending?
      %w[queued sending sent].include?(status)
    end

    # Convert to hash
    # @return [Hash]
    def to_h
      {
        id: id,
        to: to,
        from: from,
        text: text,
        status: status,
        direction: direction,
        error: error,
        segments: segments,
        credits_used: credits_used,
        is_sandbox: is_sandbox,
        sender_type: sender_type,
        telnyx_message_id: telnyx_message_id,
        warning: warning,
        sender_note: sender_note,
        created_at: created_at&.iso8601,
        delivered_at: delivered_at&.iso8601,
        error_code: error_code,
        retry_count: retry_count,
        metadata: metadata,
        ai_metadata: ai_metadata,
        media_urls: media_urls,
        message_format: message_format
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?

      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # Represents a paginated list of messages
  class MessageList
    include Enumerable

    # @return [Array<Message>] Messages in this page
    attr_reader :data

    # @return [Integer] Total number of messages that match the query, across all pages
    attr_reader :total

    # @return [Integer] Current limit
    attr_reader :limit

    # @return [Integer] Current offset
    attr_reader :offset

    # @return [Boolean] Whether there are more pages
    attr_reader :has_more

    def initialize(response)
      pagination = response["pagination"] || {}
      @data = (response["data"] || []).map { |m| Message.new(m) }
      @total = pagination["total"] || response["total"] || response["count"] || @data.length
      @limit = pagination["limit"] || response["limit"] || 20
      @offset = pagination["offset"] || response["offset"] || 0
      @has_more = if pagination.key?("hasMore")
                    pagination["hasMore"]
                  else
                    (@offset + @data.length) < @total
                  end
    end

    # Iterate over messages
    def each(&block)
      data.each(&block)
    end

    # Get message count
    # @return [Integer]
    def count
      data.length
    end

    alias size count
    alias length count

    # Check if empty
    # @return [Boolean]
    def empty?
      data.empty?
    end

    # Get first message
    # @return [Message, nil]
    def first
      data.first
    end

    # Get last message
    # @return [Message, nil]
    def last
      data.last
    end
  end

  # Represents the result of sending a group MMS to 2-8 recipients.
  #
  # Unlike {Message}, +to+ is an array of recipients and the response carries a
  # +group_message_id+ identifying the shared conversation. The raw parsed
  # response is preserved on +#raw+ so callers can read any field the server
  # adds.
  class GroupMessage
    # @return [String] Message id — matches the id in delivery webhooks
    attr_reader :id

    # @return [String] Delivery status ("sent" on a live send, "delivered" when simulated)
    attr_reader :status

    # @return [Array<String>] The recipients the group message was sent to
    attr_reader :to

    # @return [String, nil] Identifier for the group conversation (present on live sends)
    attr_reader :group_message_id

    # @return [Boolean] True when the send was simulated and nothing reached the carrier
    attr_reader :simulated

    # @return [String, nil] Human-readable note, present on simulated sends
    attr_reader :message

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      @raw = data
      @id = data["id"]
      @status = data["status"]
      @to = data["to"] || []
      @group_message_id = data["group_message_id"] || data["groupMessageId"]
      @simulated = data["simulated"] || false
      @message = data["message"]
    end

    # @return [Boolean] Whether the send was simulated
    def simulated?
      simulated
    end

    def to_h
      {
        id: id, status: status, to: to,
        group_message_id: group_message_id,
        simulated: simulated, message: message
      }.compact
    end
  end

  # Represents the result of an AI message enhancement.
  class EnhancedMessage
    # @return [String] The rewritten message, capped at 160 characters (one SMS
    #   segment). Falls back to the original text when AI is unavailable.
    attr_reader :enhanced

    # @return [String] Short explanation of what changed (empty on the fallback path)
    attr_reader :explanation

    # @return [String, nil] The model that produced the enhancement, when available
    attr_reader :model

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      @raw = data
      @enhanced = data["enhanced"]
      @explanation = data["explanation"] || ""
      @model = data["model"]
    end

    def to_h
      { enhanced: enhanced, explanation: explanation, model: model }.compact
    end
  end

  # ============================================================================
  # Media
  # ============================================================================

  class MediaFile
    attr_reader :id, :url, :content_type, :size_bytes

    def initialize(data)
      @id = data["id"]
      @url = data["url"]
      @content_type = data["contentType"]
      @size_bytes = data["sizeBytes"]
    end

    def to_h
      {
        id: id,
        url: url,
        content_type: content_type,
        size_bytes: size_bytes
      }.compact
    end
  end

  # ============================================================================
  # Webhooks
  # ============================================================================

  # Represents a configured webhook endpoint
  class Webhook
    attr_reader :id, :url, :events, :description, :mode, :is_active, :failure_count,
                :last_failure_at, :circuit_state, :circuit_opened_at, :api_version,
                :metadata, :created_at, :updated_at, :total_deliveries,
                :successful_deliveries, :success_rate, :last_delivery_at

    # Circuit state constants
    CIRCUIT_STATES = %w[closed open half_open].freeze

    # Webhook mode constants
    MODES = %w[all test live].freeze

    def initialize(data)
      @id = data["id"]
      @url = data["url"]
      @events = data["events"] || []
      @description = data["description"]
      @mode = data["mode"] || "all"
      # Handle both snake_case API response and camelCase
      @is_active = data["is_active"] || data["isActive"] || false
      @failure_count = data["failure_count"] || data["failureCount"] || 0
      @last_failure_at = parse_time(data["last_failure_at"] || data["lastFailureAt"])
      @circuit_state = data["circuit_state"] || data["circuitState"] || "closed"
      @circuit_opened_at = parse_time(data["circuit_opened_at"] || data["circuitOpenedAt"])
      @api_version = data["api_version"] || data["apiVersion"] || "2024-01"
      @metadata = data["metadata"] || {}
      @created_at = parse_time(data["created_at"] || data["createdAt"])
      @updated_at = parse_time(data["updated_at"] || data["updatedAt"])
      @total_deliveries = data["total_deliveries"] || data["totalDeliveries"] || 0
      @successful_deliveries = data["successful_deliveries"] || data["successfulDeliveries"] || 0
      @success_rate = data["success_rate"] || data["successRate"] || 0
      @last_delivery_at = parse_time(data["last_delivery_at"] || data["lastDeliveryAt"])
    end

    def active?
      is_active
    end

    def circuit_open?
      circuit_state == "open"
    end

    def to_h
      {
        id: id, url: url, events: events, description: description,
        is_active: is_active, failure_count: failure_count,
        circuit_state: circuit_state, api_version: api_version,
        metadata: metadata, total_deliveries: total_deliveries,
        successful_deliveries: successful_deliveries, success_rate: success_rate
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # Webhook with secret (returned on creation)
  class WebhookCreatedResponse < Webhook
    attr_reader :secret

    def initialize(data)
      super(data)
      @secret = data["secret"]
    end
  end

  # Represents a webhook delivery attempt
  class WebhookDelivery
    attr_reader :id, :webhook_id, :event_id, :event_type, :attempt_number,
                :max_attempts, :status, :response_status_code, :response_time_ms,
                :error_message, :error_code, :next_retry_at, :created_at, :delivered_at

    # Delivery status constants
    STATUSES = %w[pending delivered failed cancelled].freeze

    def initialize(data)
      @id = data["id"]
      @webhook_id = data["webhook_id"] || data["webhookId"]
      @event_id = data["event_id"] || data["eventId"]
      @event_type = data["event_type"] || data["eventType"]
      @attempt_number = data["attempt_number"] || data["attemptNumber"] || 1
      @max_attempts = data["max_attempts"] || data["maxAttempts"] || 6
      @status = data["status"]
      @response_status_code = data["response_status_code"] || data["responseStatusCode"]
      @response_time_ms = data["response_time_ms"] || data["responseTimeMs"]
      @error_message = data["error_message"] || data["errorMessage"]
      @error_code = data["error_code"] || data["errorCode"]
      @next_retry_at = parse_time(data["next_retry_at"] || data["nextRetryAt"])
      @created_at = parse_time(data["created_at"] || data["createdAt"])
      @delivered_at = parse_time(data["delivered_at"] || data["deliveredAt"])
    end

    def delivered?
      status == "delivered"
    end

    def failed?
      status == "failed"
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # Result of testing a webhook
  #
  # Only a delivered test comes back as a result: when the test delivery
  # fails, {Sendly::WebhooksResource#test} raises {Sendly::ValidationError}
  # with the API's message.
  class WebhookTestResult
    attr_reader :success, :status_code, :response_time_ms, :error

    # @return [String, nil] The API's summary of the test delivery
    attr_reader :message

    # @return [String, nil] ID of the test delivery
    attr_reader :delivery_id

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      delivery = data["delivery"] || {}
      @raw = data
      @success = data["success"]
      @status_code = data["status_code"] || data["statusCode"] || delivery["status_code"]
      @response_time_ms = data["response_time_ms"] || data["responseTimeMs"] || delivery["response_time"]
      @error = data["error"] || delivery["error"]
      @message = data["message"]
      @delivery_id = delivery["id"] || delivery["delivery_id"]
    end

    def success?
      success
    end
  end

  # Result of rotating webhook secret
  #
  # The API signs deliveries with the new secret from the moment the rotation
  # returns and does not keep the old one, so {#new_secret} is the only secret
  # that verifies deliveries from then on.
  class WebhookSecretRotation
    # @return [Sendly::Webhook, nil] Always +nil+: the rotation response does not include the webhook
    attr_reader :webhook

    # @return [String] The new signing secret. It is shown only once.
    attr_reader :new_secret

    # @return [Time, nil] Always +nil+: the API does not keep the old secret, so it has no expiry
    attr_reader :old_secret_expires_at

    # @return [String, nil] Confirmation message
    attr_reader :message

    # @return [String, nil] The webhook's ID
    attr_reader :id

    # @return [Integer, nil] The webhook's secret version as the API reports it
    attr_reader :new_secret_version

    # @return [Integer, nil] The grace period the API reports (24). The old
    #   secret is not kept, so it does not verify deliveries during it.
    attr_reader :grace_period_hours

    # @return [Time, nil] When the secret was rotated
    attr_reader :rotated_at

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      @raw = data
      @webhook = data["webhook"] ? Webhook.new(data["webhook"]) : nil
      @new_secret = data["new_secret"] || data["newSecret"] || data["secret"]
      @old_secret_expires_at = parse_time(data["old_secret_expires_at"] || data["oldSecretExpiresAt"])
      @message = data["message"]
      @id = data["id"]
      @new_secret_version = data["new_secret_version"] || data["newSecretVersion"]
      @grace_period_hours = data["grace_period_hours"] || data["gracePeriodHours"]
      @rotated_at = parse_time(data["rotated_at"] || data["rotatedAt"])
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # ============================================================================
  # Account & Credits
  # ============================================================================

  # Represents account information
  class Account
    # @return [String, nil] The user's ID
    attr_reader :id

    # @return [String, nil] The user's email address
    attr_reader :email

    # @return [String, nil] The name of the workspace the API key belongs to,
    #   or +nil+ when the key is not bound to a workspace
    attr_reader :name

    # @return [Time, nil] When the user signed up
    attr_reader :created_at

    # @return [Hash, nil] The workspace the API key belongs to
    #   (+"id"+, +"name"+, +"isPersonal"+), or +nil+
    attr_reader :organization

    # @return [String, nil] The workspace's ID, the +organization_id+ in webhook payloads
    attr_reader :organization_id

    # @return [Hash, nil] Credit balances (+"balance"+, +"reservedBalance"+)
    attr_reader :credits

    # @return [Hash, nil] Business verification (+"status"+, +"type"+, +"region"+,
    #   +"submittedAt"+, +"updatedAt"+), or +nil+ when there is none
    attr_reader :verification

    # @return [Hash, nil] The API key making the call (+"id"+, +"name"+, +"type"+,
    #   +"scopes"+, +"createdAt"+, +"lastUsedAt"+)
    attr_reader :api_key

    # @return [Hash, nil] Sending limits (+"messagesPerMinute"+, +"messagesPerDay"+)
    attr_reader :limits

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      user = data["user"] || {}
      @raw = data
      @organization = data["organization"]
      @organization_id = @organization && @organization["id"]
      @id = user["id"] || data["id"]
      @email = user["email"] || data["email"]
      @name = (@organization && @organization["name"]) || data["name"]
      @created_at = parse_time(user["createdAt"] || user["created_at"] || data["created_at"] || data["createdAt"])
      @credits = data["credits"]
      @verification = data["verification"]
      @api_key = data["apiKey"] || data["api_key"]
      @limits = data["limits"]
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # Represents credit balance information
  class Credits
    attr_reader :balance, :reserved_balance, :available_balance

    def initialize(data)
      @balance = data["balance"] || 0
      @reserved_balance = data["reserved_balance"] || data["reservedBalance"] || 0
      @available_balance = data["available_balance"] || data["availableBalance"] || 0
    end
  end

  # Represents a credit transaction
  class CreditTransaction
    attr_reader :id, :type, :amount, :balance_after, :description, :message_id, :created_at

    # Transaction type constants. Auto-recharges are recorded as +purchase+;
    # +adjustment+ is never recorded.
    TYPES = %w[purchase usage refund adjustment bonus transfer admin_grant admin_seed].freeze

    def initialize(data)
      @id = data["id"]
      @type = data["type"]
      @amount = data["amount"] || 0
      @balance_after = data["balance_after"] || data["balanceAfter"] || 0
      @description = data["description"]
      @message_id = data["message_id"] || data["messageId"]
      @created_at = parse_time(data["created_at"] || data["createdAt"])
    end

    def credit?
      amount > 0
    end

    def debit?
      amount < 0
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # Represents an API key
  class ApiKey
    attr_reader :id, :name, :type, :prefix, :permissions,
                :created_at, :last_used_at, :expires_at, :is_revoked

    # @return [nil] Always +nil+: no API response carries the last four characters
    attr_reader :last_four

    # @return [Array<String>] The key's scopes (the same list as {#permissions})
    attr_reader :scopes

    # @return [Boolean, nil] Whether the key is active, or +nil+ when the response does not say
    attr_reader :is_active

    # @return [Time, nil] When the key was revoked
    attr_reader :revoked_at

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @type = data["type"]
      @prefix = data["prefix"]
      @last_four = data["last_four"] || data["lastFour"]
      @permissions = data["permissions"] || data["scopes"] || []
      @scopes = data["scopes"] || data["permissions"] || []
      @created_at = parse_time(data["created_at"] || data["createdAt"])
      @last_used_at = parse_time(data["last_used_at"] || data["lastUsedAt"])
      @expires_at = parse_time(data["expires_at"] || data["expiresAt"])
      @revoked_at = parse_time(data["revoked_at"] || data["revokedAt"])
      @is_active = data.key?("isActive") ? data["isActive"] : data["is_active"]
      @is_revoked = if data.key?("isRevoked") || data.key?("is_revoked")
                      data["isRevoked"] || data["is_revoked"] || false
                    elsif !@is_active.nil?
                      !@is_active
                    else
                      !@revoked_at.nil?
                    end
    end

    def test?
      type == "test"
    end

    def live?
      type == "live"
    end

    def revoked?
      is_revoked
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # ============================================================================
  # Conversations
  # ============================================================================

  class Conversation
    attr_reader :id, :phone_number, :status, :unread_count, :message_count,
                :last_message_text, :last_message_at, :last_message_direction,
                :metadata, :tags, :contact_id, :created_at, :updated_at

    STATUSES = %w[active closed].freeze

    def initialize(data)
      @id = data["id"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @status = data["status"]
      @unread_count = data["unreadCount"] || data["unread_count"] || 0
      @message_count = data["messageCount"] || data["message_count"] || 0
      @last_message_text = data["lastMessageText"] || data["last_message_text"]
      @last_message_at = parse_time(data["lastMessageAt"] || data["last_message_at"])
      @last_message_direction = data["lastMessageDirection"] || data["last_message_direction"]
      @metadata = data["metadata"] || {}
      @tags = data["tags"] || []
      @contact_id = data["contactId"] || data["contact_id"]
      @created_at = parse_time(data["createdAt"] || data["created_at"])
      @updated_at = parse_time(data["updatedAt"] || data["updated_at"])
    end

    def active?
      status == "active"
    end

    def closed?
      status == "closed"
    end

    def to_h
      {
        id: id, phone_number: phone_number, status: status,
        unread_count: unread_count, message_count: message_count,
        last_message_text: last_message_text,
        last_message_at: last_message_at&.iso8601,
        last_message_direction: last_message_direction,
        metadata: metadata, tags: tags, contact_id: contact_id,
        created_at: created_at&.iso8601, updated_at: updated_at&.iso8601
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  class ConversationList
    include Enumerable

    attr_reader :data, :total, :limit, :offset, :has_more

    def initialize(response)
      @data = (response["data"] || []).map { |c| Conversation.new(c) }
      pagination = response["pagination"] || {}
      @total = pagination["total"] || @data.length
      @limit = pagination["limit"] || 20
      @offset = pagination["offset"] || 0
      @has_more = pagination["hasMore"] || pagination["has_more"] || false
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

  # ============================================================================
  # Suggested Replies
  # ============================================================================

  class SuggestedReply
    # @return [String] Suggested reply text
    attr_reader :text

    # @return [String] Tone of the suggestion (professional, friendly, concise)
    attr_reader :tone

    TONES = %w[professional friendly concise].freeze

    def initialize(data)
      @text = data["text"]
      @tone = data["tone"]
    end

    def to_h
      { text: text, tone: tone }.compact
    end
  end

  class SuggestRepliesResponse
    include Enumerable

    # @return [Array<SuggestedReply>] AI-generated reply suggestions
    attr_reader :suggestions

    # @return [String, nil] ID of the inbound message the suggestions are based on
    attr_reader :based_on_message_id

    # @return [String, nil] Model that generated the suggestions
    attr_reader :model

    def initialize(data)
      @suggestions = (data["suggestions"] || []).map { |s| SuggestedReply.new(s) }
      @based_on_message_id = data["basedOnMessageId"] || data["based_on_message_id"]
      @model = data["model"]
    end

    def each(&block)
      suggestions.each(&block)
    end

    def count
      suggestions.length
    end

    alias size count
    alias length count

    def empty?
      suggestions.empty?
    end

    def first
      suggestions.first
    end

    def to_h
      {
        suggestions: suggestions.map(&:to_h),
        based_on_message_id: based_on_message_id,
        model: model
      }.compact
    end
  end

  # ============================================================================
  # Labels
  # ============================================================================

  class Label
    attr_reader :id, :name, :color, :description, :created_at

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @color = data["color"]
      @description = data["description"]
      @created_at = parse_time(data["createdAt"] || data["created_at"])
    end

    def to_h
      {
        id: id, name: name, color: color, description: description,
        created_at: created_at&.iso8601
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # ============================================================================
  # Drafts
  # ============================================================================

  class Draft
    attr_reader :id, :conversation_id, :text, :media_urls, :metadata, :status,
                :source, :created_by, :reviewed_by, :reviewed_at,
                :rejection_reason, :message_id, :created_at, :updated_at

    STATUSES = %w[pending approved rejected sent failed].freeze

    def initialize(data)
      @id = data["id"]
      @conversation_id = data["conversationId"] || data["conversation_id"]
      @text = data["text"]
      @media_urls = data["mediaUrls"] || data["media_urls"] || []
      @metadata = data["metadata"] || {}
      @status = data["status"]
      @source = data["source"]
      @created_by = data["createdBy"] || data["created_by"]
      @reviewed_by = data["reviewedBy"] || data["reviewed_by"]
      @reviewed_at = parse_time(data["reviewedAt"] || data["reviewed_at"])
      @rejection_reason = data["rejectionReason"] || data["rejection_reason"]
      @message_id = data["messageId"] || data["message_id"]
      @created_at = parse_time(data["createdAt"] || data["created_at"])
      @updated_at = parse_time(data["updatedAt"] || data["updated_at"])
    end

    def pending?
      status == "pending"
    end

    def approved?
      status == "approved"
    end

    def rejected?
      status == "rejected"
    end

    def to_h
      {
        id: id, conversation_id: conversation_id, text: text,
        media_urls: media_urls, metadata: metadata, status: status,
        source: source, created_by: created_by, reviewed_by: reviewed_by,
        reviewed_at: reviewed_at&.iso8601, rejection_reason: rejection_reason,
        message_id: message_id, created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  class DraftList
    include Enumerable

    attr_reader :data, :total, :limit, :offset, :has_more

    # @param response [Hash] The parsed list response
    # @param limit [Integer, nil] The page size the API used, when the response does not say
    # @param offset [Integer, nil] The offset the API used, when the response does not say
    def initialize(response, limit = nil, offset = nil)
      @data = (response["data"] || []).map { |d| Draft.new(d) }
      pagination = response["pagination"] || {}
      @total = pagination["total"] || @data.length
      @limit = pagination["limit"] || limit || 20
      @offset = pagination["offset"] || offset || 0
      @has_more = if pagination.key?("hasMore") || pagination.key?("has_more")
                    pagination["hasMore"] || pagination["has_more"] || false
                  else
                    (@offset + @data.length) < @total
                  end
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

  class ConversationWithMessages < Conversation
    attr_reader :messages

    def initialize(data)
      super(data)
      if data["messages"]
        msgs = data["messages"]
        @messages = {
          data: (msgs["data"] || []).map { |m| Message.new(m) },
          pagination: {
            total: msgs.dig("pagination", "total") || 0,
            limit: msgs.dig("pagination", "limit") || 20,
            offset: msgs.dig("pagination", "offset") || 0,
            has_more: msgs.dig("pagination", "hasMore") || msgs.dig("pagination", "has_more") || false
          }
        }
      end
    end
  end

  # ============================================================================
  # Conversation Context
  # ============================================================================

  class ConversationContext
    attr_reader :context, :conversation, :token_estimate, :business

    def initialize(data)
      @context = data["context"]
      @conversation = {
        id: data.dig("conversation", "id"),
        phone_number: data.dig("conversation", "phoneNumber") || data.dig("conversation", "phone_number"),
        status: data.dig("conversation", "status"),
        message_count: data.dig("conversation", "messageCount") || data.dig("conversation", "message_count") || 0,
        unread_count: data.dig("conversation", "unreadCount") || data.dig("conversation", "unread_count") || 0
      }
      @token_estimate = data["tokenEstimate"] || data["token_estimate"] || 0
      if data["business"]
        @business = {
          name: data.dig("business", "name"),
          use_case: data.dig("business", "useCase") || data.dig("business", "use_case")
        }
      end
    end

    def to_h
      result = {
        context: context,
        conversation: conversation,
        token_estimate: token_estimate
      }
      result[:business] = business if business
      result
    end
  end

  # ============================================================================
  # Rules
  # ============================================================================

  class Rule
    attr_reader :id, :name, :conditions, :actions, :priority, :created_at, :updated_at

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @conditions = data["conditions"] || {}
      @actions = data["actions"] || {}
      @priority = data["priority"]
      @created_at = parse_time(data["createdAt"] || data["created_at"])
      @updated_at = parse_time(data["updatedAt"] || data["updated_at"])
    end

    def to_h
      {
        id: id, name: name, conditions: conditions, actions: actions,
        priority: priority, created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # ============================================================================
  # Generated Template
  # ============================================================================

  class GeneratedTemplate
    attr_reader :name, :text, :variables, :category

    def initialize(data)
      @name = data["name"]
      @text = data["text"]
      @variables = data["variables"] || []
      @category = data["category"]
    end

    def to_h
      {
        name: name, text: text, variables: variables, category: category
      }.compact
    end
  end
end
