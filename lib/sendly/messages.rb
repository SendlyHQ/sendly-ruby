# frozen_string_literal: true

module Sendly
  # Messages resource for sending and managing SMS
  class Messages
    # @return [Sendly::Client] The API client
    attr_reader :client

    def initialize(client)
      @client = client
    end

    # Send an SMS message
    #
    # @param to [String] Recipient phone number in E.164 format
    # @param text [String] Message content (max 1600 characters)
    # @return [Sendly::Message] The sent message
    #
    # @raise [Sendly::ValidationError] If parameters are invalid
    # @raise [Sendly::InsufficientCreditsError] If account has no credits
    # @raise [Sendly::RateLimitError] If rate limit is exceeded
    #
    # @example
    #   message = client.messages.send(
    #     to: "+15551234567",
    #     text: "Hello from Sendly!"
    #   )
    #   puts message.id
    #   puts message.status
    def send(to:, text:)
      validate_phone!(to)
      validate_text!(text)

      response = client.post("/messages", { to: to, text: text })
      # API returns message directly at top level
      Message.new(response)
    end

    # List messages
    #
    # @param limit [Integer] Maximum messages to return (default: 20, max: 100)
    # @param offset [Integer] Number of messages to skip
    # @param status [String] Filter by status
    # @param to [String] Filter by recipient
    # @return [Sendly::MessageList] Paginated list of messages
    #
    # @example
    #   messages = client.messages.list(limit: 50)
    #   messages.each { |m| puts m.to }
    #
    # @example With filters
    #   messages = client.messages.list(
    #     status: "delivered",
    #     to: "+15551234567"
    #   )
    def list(limit: 20, offset: 0, status: nil, to: nil)
      params = {
        limit: [limit, 100].min,
        offset: offset
      }
      params[:status] = status if status
      params[:to] = to if to

      response = client.get("/messages", params.compact)
      MessageList.new(response)
    end

    # Get a message by ID
    #
    # @param id [String] Message ID
    # @return [Sendly::Message] The message
    #
    # @raise [Sendly::NotFoundError] If message is not found
    #
    # @example
    #   message = client.messages.get("msg_abc123")
    #   puts message.status
    def get(id)
      raise ValidationError, "Message ID is required" if id.nil? || id.empty?

      # URL encode the ID to prevent path injection
      encoded_id = URI.encode_www_form_component(id)
      response = client.get("/messages/#{encoded_id}")
      # API returns message directly at top level
      Message.new(response)
    end

    # Iterate over all messages with automatic pagination
    #
    # @param status [String] Filter by status
    # @param to [String] Filter by recipient
    # @param batch_size [Integer] Number of messages per request
    # @yield [Message] Each message
    # @return [Enumerator] If no block given
    #
    # @example
    #   client.messages.each do |message|
    #     puts "#{message.id}: #{message.to}"
    #   end
    def each(status: nil, to: nil, batch_size: 100, &block)
      return enum_for(:each, status: status, to: to, batch_size: batch_size) unless block_given?

      offset = 0
      loop do
        page = list(limit: batch_size, offset: offset, status: status, to: to)
        page.each(&block)

        break unless page.has_more

        offset += batch_size
      end
    end

    # Schedule an SMS message for future delivery
    #
    # @param to [String] Recipient phone number in E.164 format
    # @param text [String] Message content (max 1600 characters)
    # @param scheduled_at [String] ISO 8601 datetime for when to send
    # @param from [String] Sender ID or phone number (optional)
    # @return [Hash] The scheduled message
    #
    # @raise [Sendly::ValidationError] If parameters are invalid
    #
    # @example
    #   scheduled = client.messages.schedule(
    #     to: "+15551234567",
    #     text: "Reminder: Your appointment is tomorrow!",
    #     scheduled_at: "2025-01-20T10:00:00Z"
    #   )
    #   puts scheduled["id"]
    def schedule(to:, text:, scheduled_at:, from: nil)
      validate_phone!(to)
      validate_text!(text)
      raise ValidationError, "scheduled_at is required" if scheduled_at.nil? || scheduled_at.empty?

      body = { to: to, text: text, scheduledAt: scheduled_at }
      body[:from] = from if from

      client.post("/messages/schedule", body)
    end

    # List scheduled messages
    #
    # @param limit [Integer] Maximum messages to return (default: 20, max: 100)
    # @param offset [Integer] Number of messages to skip
    # @param status [String] Filter by status (scheduled, sent, cancelled, failed)
    # @return [Hash] Paginated list of scheduled messages
    #
    # @example
    #   scheduled = client.messages.list_scheduled(limit: 50)
    #   scheduled["data"].each { |m| puts m["scheduledAt"] }
    def list_scheduled(limit: 20, offset: 0, status: nil)
      params = {
        limit: [limit, 100].min,
        offset: offset
      }
      params[:status] = status if status

      client.get("/messages/scheduled", params.compact)
    end

    # Get a scheduled message by ID
    #
    # @param id [String] Scheduled message ID
    # @return [Hash] The scheduled message
    #
    # @raise [Sendly::NotFoundError] If scheduled message is not found
    #
    # @example
    #   scheduled = client.messages.get_scheduled("sched_abc123")
    #   puts scheduled["status"]
    def get_scheduled(id)
      raise ValidationError, "Scheduled message ID is required" if id.nil? || id.empty?

      encoded_id = URI.encode_www_form_component(id)
      client.get("/messages/scheduled/#{encoded_id}")
    end

    # Cancel a scheduled message
    #
    # @param id [String] Scheduled message ID
    # @return [Hash] The cancelled message with refund details
    #
    # @raise [Sendly::NotFoundError] If scheduled message is not found
    # @raise [Sendly::ValidationError] If message cannot be cancelled
    #
    # @example
    #   result = client.messages.cancel_scheduled("sched_abc123")
    #   puts "Refunded #{result['creditsRefunded']} credits"
    def cancel_scheduled(id)
      raise ValidationError, "Scheduled message ID is required" if id.nil? || id.empty?

      encoded_id = URI.encode_www_form_component(id)
      client.delete("/messages/scheduled/#{encoded_id}")
    end

    # Send multiple SMS messages in a batch
    #
    # @param messages [Array<Hash>] Array of messages with :to and :text keys
    # @param from [String] Sender ID or phone number (optional, applies to all)
    # @return [Hash] Batch response with batch_id and status
    #
    # @raise [Sendly::ValidationError] If parameters are invalid
    # @raise [Sendly::InsufficientCreditsError] If account has insufficient credits
    #
    # @example
    #   result = client.messages.send_batch(
    #     messages: [
    #       { to: "+15551234567", text: "Hello Alice!" },
    #       { to: "+15559876543", text: "Hello Bob!" }
    #     ]
    #   )
    #   puts "Batch #{result['batchId']}: #{result['queued']} queued"
    def send_batch(messages:, from: nil)
      raise ValidationError, "Messages array is required" if messages.nil? || messages.empty?

      messages.each_with_index do |msg, i|
        raise ValidationError, "Message at index #{i} missing 'to'" unless msg[:to] || msg["to"]
        raise ValidationError, "Message at index #{i} missing 'text'" unless msg[:text] || msg["text"]

        to = msg[:to] || msg["to"]
        text = msg[:text] || msg["text"]
        validate_phone!(to)
        validate_text!(text)
      end

      body = { messages: messages }
      body[:from] = from if from

      client.post("/messages/batch", body)
    end

    # Get batch status by ID
    #
    # @param batch_id [String] Batch ID
    # @return [Hash] Batch status and details
    #
    # @raise [Sendly::NotFoundError] If batch is not found
    #
    # @example
    #   batch = client.messages.get_batch("batch_abc123")
    #   puts "#{batch['sent']}/#{batch['total']} sent"
    def get_batch(batch_id)
      raise ValidationError, "Batch ID is required" if batch_id.nil? || batch_id.empty?

      encoded_id = URI.encode_www_form_component(batch_id)
      client.get("/messages/batch/#{encoded_id}")
    end

    # List batches
    #
    # @param limit [Integer] Maximum batches to return (default: 20, max: 100)
    # @param offset [Integer] Number of batches to skip
    # @param status [String] Filter by status (processing, completed, failed)
    # @return [Hash] Paginated list of batches
    #
    # @example
    #   batches = client.messages.list_batches(limit: 10)
    #   batches["data"].each { |b| puts "#{b['batchId']}: #{b['status']}" }
    def list_batches(limit: 20, offset: 0, status: nil)
      params = {
        limit: [limit, 100].min,
        offset: offset
      }
      params[:status] = status if status

      client.get("/messages/batches", params.compact)
    end

    private

    def validate_phone!(phone)
      return if phone.is_a?(String) && phone.match?(/^\+[1-9]\d{1,14}$/)

      raise ValidationError, "Invalid phone number format. Use E.164 format (e.g., +15551234567)"
    end

    def validate_text!(text)
      raise ValidationError, "Message text is required" if text.nil? || text.empty?
      raise ValidationError, "Message text exceeds maximum length (1600 characters)" if text.length > 1600
    end
  end
end
