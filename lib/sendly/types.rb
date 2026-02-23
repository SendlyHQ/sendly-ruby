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

    # @return [String, nil] Telnyx message ID for tracking
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
        metadata: metadata
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

    # @return [Integer] Total number of messages
    attr_reader :total

    # @return [Integer] Current limit
    attr_reader :limit

    # @return [Integer] Current offset
    attr_reader :offset

    # @return [Boolean] Whether there are more pages
    attr_reader :has_more

    def initialize(response)
      @data = (response["data"] || []).map { |m| Message.new(m) }
      @total = response["count"] || @data.length
      @limit = response["limit"] || 20
      @offset = response["offset"] || 0
      @has_more = (@offset + @data.length) < @total
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
  class WebhookTestResult
    attr_reader :success, :status_code, :response_time_ms, :error

    def initialize(data)
      @success = data["success"]
      @status_code = data["status_code"] || data["statusCode"]
      @response_time_ms = data["response_time_ms"] || data["responseTimeMs"]
      @error = data["error"]
    end

    def success?
      success
    end
  end

  # Result of rotating webhook secret
  class WebhookSecretRotation
    attr_reader :webhook, :new_secret, :old_secret_expires_at, :message

    def initialize(data)
      @webhook = Webhook.new(data["webhook"])
      @new_secret = data["new_secret"] || data["newSecret"]
      @old_secret_expires_at = parse_time(data["old_secret_expires_at"] || data["oldSecretExpiresAt"])
      @message = data["message"]
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
    attr_reader :id, :email, :name, :created_at

    def initialize(data)
      @id = data["id"]
      @email = data["email"]
      @name = data["name"]
      @created_at = parse_time(data["created_at"] || data["createdAt"])
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

    # Transaction type constants
    TYPES = %w[purchase usage refund adjustment bonus].freeze

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
    attr_reader :id, :name, :type, :prefix, :last_four, :permissions,
                :created_at, :last_used_at, :expires_at, :is_revoked

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @type = data["type"]
      @prefix = data["prefix"]
      @last_four = data["last_four"] || data["lastFour"]
      @permissions = data["permissions"] || []
      @created_at = parse_time(data["created_at"] || data["createdAt"])
      @last_used_at = parse_time(data["last_used_at"] || data["lastUsedAt"])
      @expires_at = parse_time(data["expires_at"] || data["expiresAt"])
      @is_revoked = data["is_revoked"] || data["isRevoked"] || false
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
end
