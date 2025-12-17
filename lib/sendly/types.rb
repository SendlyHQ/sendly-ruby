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

    # @return [String, nil] Error message if failed
    attr_reader :error

    # @return [Integer] Number of SMS segments
    attr_reader :segments

    # @return [Integer] Credits used
    attr_reader :credits_used

    # @return [Boolean] Whether sent in sandbox mode
    attr_reader :is_sandbox

    # @return [Time, nil] Creation timestamp
    attr_reader :created_at

    # @return [Time, nil] Delivery timestamp
    attr_reader :delivered_at

    # Message status constants
    STATUSES = %w[queued sending sent delivered failed].freeze

    def initialize(data)
      @id = data["id"]
      @to = data["to"]
      @from = data["from"]
      @text = data["text"]
      @status = data["status"]
      @error = data["error"]
      @segments = data["segments"] || 1
      @credits_used = data["creditsUsed"] || 0
      @is_sandbox = data["isSandbox"] || false
      @created_at = parse_time(data["createdAt"])
      @delivered_at = parse_time(data["deliveredAt"])
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
        error: error,
        segments: segments,
        credits_used: credits_used,
        is_sandbox: is_sandbox,
        created_at: created_at&.iso8601,
        delivered_at: delivered_at&.iso8601
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
end
