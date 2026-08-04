# frozen_string_literal: true

module Sendly
  # Messages resource for sending and managing SMS
  class Messages
    # @return [Sendly::Client] The API client
    attr_reader :client

    def initialize(client)
      @client = client
    end

    # Send an SMS, WhatsApp, or RCS message
    #
    # Pass +channel: "whatsapp"+ to send on WhatsApp. WhatsApp sends require
    # a live API key and a +from+ number with an active WhatsApp connection
    # (see +client.whatsapp.signup+). Provide exactly one of +text+
    # (free-form, max 4096 bytes), +media_urls+ (a single attachment;
    # optional +text+ becomes its caption, max 1024 bytes), or +template+
    # (an approved template). Free-form text and media only deliver inside
    # an open 24-hour customer-service window — outside it the API responds
    # 422 +whatsapp_window_closed+; send a template instead (check with
    # +client.whatsapp.window+).
    #
    # Pass +channel: "rcs"+ to send on RCS. RCS sends require a live API key
    # and a sendable RCS agent on your workspace (see +client.rcs.agents+).
    # Provide exactly one of +text+ (free-form, optionally with
    # +suggestions+ — suggested replies and URL actions) or +card+ (a rich
    # card). +agent_id+ picks the sending agent when your workspace has more
    # than one. Recipients that can't receive RCS get +text+ delivered as
    # plain SMS (billed as SMS) unless +fallback_to_sms+ is false — the
    # returned {Sendly::RcsMessage} discloses which channel delivered.
    #
    # @param to [String] Recipient phone number in E.164 format
    # @param text [String] Message content (max 1600 characters for SMS);
    #   for WhatsApp, optional free-form text or the media caption
    # @param from [String] Sender ID or phone number (optional for SMS);
    #   required for WhatsApp — must be a WhatsApp-connected number
    # @param message_type [String] Message type: "marketing" (default) or "transactional" (SMS only)
    # @param metadata [Hash] Custom JSON metadata to attach to the message (max 4KB)
    # @param media_urls [Array<String>] Media URLs to attach (WhatsApp accepts exactly one)
    # @param channel [String] Message channel: omit (or "sms") for SMS,
    #   "whatsapp" for WhatsApp, "rcs" for RCS
    # @param template [Hash] WhatsApp only: approved template to send, with
    #   :name, :language, and optional :variables ({ "1" => "Acme" }) and
    #   :buttons ([{ index: 0, variables: { "1" => "4821" } }]). Works
    #   regardless of the 24-hour window.
    # @param agent_id [String] RCS only: the agent to send from. Optional
    #   when your workspace has exactly one sendable agent; required (the
    #   API responds 400 +rcs_agent_ambiguous+) when it has more.
    # @param card [Hash] RCS only: a rich card, with :title, :description,
    #   and optional :mediaUrl (a public JPEG, PNG, or GIF), :orientation
    #   ("vertical" or "horizontal"), and :suggestions. Passed through
    #   verbatim, so use the camelCase keys shown. Cards have no SMS form
    #   and only deliver to RCS-capable recipients.
    # @param suggestions [Array<Hash>] RCS only, alongside +text+: suggested
    #   replies and actions, each either
    #   { reply: { text: ..., postbackData: ... } } or
    #   { action: { text: ..., postbackData: ..., url: ... } }. Passed
    #   through verbatim, so use the camelCase keys shown. Suggestions have
    #   no SMS form and are dropped on a fallback.
    # @param fallback_to_sms [Boolean] RCS only: deliver +text+ as plain SMS
    #   when the recipient can't receive RCS (default true). Pass false to
    #   fail with 422 +rcs_not_supported_for_recipient+ instead.
    # @return [Sendly::Message, Sendly::WhatsAppMessage, Sendly::RcsMessage] The sent message
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
    #
    # @example Transactional message (bypasses quiet hours)
    #   message = client.messages.send(
    #     to: "+15551234567",
    #     text: "Your verification code is 123456",
    #     message_type: "transactional"
    #   )
    #
    # @example WhatsApp free-form reply inside an open 24h window
    #   message = client.messages.send(
    #     channel: "whatsapp",
    #     to: "+15551234567",
    #     from: "+15559876543",
    #     text: "Your table is ready!"
    #   )
    #
    # @example WhatsApp template send — works regardless of the window
    #   message = client.messages.send(
    #     channel: "whatsapp",
    #     to: "+15551234567",
    #     from: "+15559876543",
    #     template: {
    #       name: "order_shipped",
    #       language: "en_US",
    #       variables: { "1" => "Acme Inc", "2" => "#4821" }
    #     }
    #   )
    #   puts message.whatsapp.kind   # "template"
    #   puts message.credits_used    # priced by country + category
    #
    # @example RCS text with suggested replies and actions
    #   message = client.messages.send(
    #     channel: "rcs",
    #     to: "+15551234567",
    #     text: "Your order has shipped! Want live updates?",
    #     suggestions: [
    #       { reply: { text: "Yes, notify me", postbackData: "notify_yes" } },
    #       { action: { text: "Track order", postbackData: "track",
    #                   url: "https://acme.example/orders/4821" } }
    #     ]
    #   )
    #   puts message.channel      # "rcs", or "sms" when it fell back
    #   puts message.fell_back?   # true when delivered as plain SMS
    #
    # @example RCS rich card (RCS-capable recipients only)
    #   client.messages.send(
    #     channel: "rcs",
    #     to: "+15551234567",
    #     card: {
    #       title: "Spring collection",
    #       description: "New arrivals are in - take a look.",
    #       mediaUrl: "https://example.com/spring.jpg",
    #       orientation: "vertical"
    #     }
    #   )
    def send(to:, text: nil, from: nil, message_type: nil, metadata: nil, media_urls: nil,
             channel: nil, template: nil, agent_id: nil, card: nil, suggestions: nil,
             fallback_to_sms: nil)
      validate_phone!(to)

      if channel.to_s == "rcs"
        has_text = !(text.nil? || text.to_s.empty?)
        has_card = !card.nil?
        raise ValidationError, "Provide exactly one of 'text' or 'card'" if has_text == has_card

        body = { channel: "rcs", to: to }
        body[:agentId] = agent_id if agent_id
        body[:text] = text if has_text
        body[:card] = card if has_card
        body[:suggestions] = suggestions if suggestions
        body[:fallbackToSms] = fallback_to_sms unless fallback_to_sms.nil?
        body[:metadata] = metadata if metadata

        response = client.post("/messages", body)
        return RcsMessage.new(response)
      end

      if channel.to_s == "whatsapp"
        validate_phone!(from)
        has_media = media_urls.is_a?(Array) && !media_urls.empty?
        if (text.nil? || text.empty?) && !has_media && template.nil?
          raise ValidationError, "Provide 'text', 'media_urls', or 'template'"
        end

        body = { channel: "whatsapp", to: to, from: from }
        body[:text] = text unless text.nil?
        body[:mediaUrls] = media_urls if has_media
        body[:template] = template if template
        body[:metadata] = metadata if metadata

        response = client.post("/messages", body)
        return WhatsAppMessage.new(response)
      end

      validate_text!(text)

      body = { to: to, text: text }
      body[:from] = from if from
      body[:messageType] = message_type if message_type
      body[:metadata] = metadata if metadata
      body[:mediaUrls] = media_urls if media_urls

      response = client.post("/messages", body)
      # API returns message directly at top level
      Message.new(response)
    end

    # Send a group MMS to 2-8 recipients (US/Canada only)
    #
    # Creates a multi-party MMS conversation: every recipient sees the others,
    # and replies fan out to all participants. Group messaging is an A2P 10DLC
    # capability — the sending number must be an MMS-enabled, 10DLC-registered
    # number you own. Omit +from+ to use your workspace's default sender.
    # Requires the +group_mms+ feature (and +enable_mms+ when sending media).
    #
    # @param to [Array<String>] 2-8 recipient phone numbers in E.164 format (US/CA only)
    # @param text [String] Message content (required unless media_urls is provided)
    # @param from [String] Sender ID or phone number (optional)
    # @param media_urls [Array<String>] Media URLs to attach (required unless text is provided)
    # @param message_type [String] Message type: "transactional" (default) or "marketing"
    # @return [Sendly::GroupMessage] The sent group message, including a group_message_id
    #
    # @raise [Sendly::ValidationError] If fewer than 2 / more than 8 recipients, or no body
    # @raise [Sendly::InsufficientCreditsError] If credit balance is too low (billed per recipient)
    #
    # @example
    #   group = client.messages.send_group(
    #     to: ["+14155551234", "+14155555678"],
    #     text: "Hey team - quick sync at noon?"
    #   )
    #   puts group.id
    #   puts group.group_message_id
    def send_group(to:, text: nil, from: nil, media_urls: nil, message_type: nil)
      unless to.is_a?(Array) && to.length >= 2
        raise ValidationError, "Group messaging requires at least 2 recipients in 'to'"
      end
      raise ValidationError, "Group messaging supports at most 8 recipients" if to.length > 8

      to.each { |recipient| validate_phone!(recipient) }

      has_media = media_urls.is_a?(Array) && !media_urls.empty?
      raise ValidationError, "Provide 'text' or 'media_urls'" if (text.nil? || text.empty?) && !has_media

      body = { to: to }
      body[:text] = text if text && !text.empty?
      body[:from] = from if from
      body[:mediaUrls] = media_urls if has_media
      body[:messageType] = message_type if message_type

      response = client.post("/messages/group", body)
      GroupMessage.new(response)
    end

    # AI-enhance a draft message for clarity, compliance, and send-readiness
    #
    # Rewrites the supplied text into a single, polished SMS segment (<=160
    # chars) and returns a short explanation of what changed. Pass +message_type+
    # to steer the rewrite (e.g. "marketing" vs "transactional"); with no +text+
    # it generates a suitable message for that type instead. At least one of
    # +text+ or +message_type+ is required. Requires the +ai_classification+
    # feature. When AI enhancement is unavailable, the response falls back to the
    # original text with an empty explanation.
    #
    # @param text [String] Draft message text to rewrite (optional if message_type given)
    # @param message_type [String] Message-type hint, e.g. "marketing" or "transactional"
    # @return [Sendly::EnhancedMessage] The enhanced text, an explanation, and the model used
    #
    # @raise [Sendly::ValidationError] If neither text nor message_type is provided
    # @raise [Sendly::NotFoundError] If AI enhancement is not enabled for the account
    #
    # @example
    #   result = client.messages.enhance(
    #     text: "hey come check out our sale this weekend",
    #     message_type: "marketing"
    #   )
    #   puts result.enhanced     # polished, <=160-char rewrite
    #   puts result.explanation  # what changed and why
    def enhance(text: nil, message_type: nil)
      if (text.nil? || text.to_s.empty?) && (message_type.nil? || message_type.to_s.empty?)
        raise ValidationError, "Provide 'text' or 'message_type'"
      end

      body = {}
      body[:text] = text unless text.nil?
      body[:messageType] = message_type if message_type

      response = client.post("/ai/enhance", body)
      EnhancedMessage.new(response)
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
    # @param message_type [String] Message type: "marketing" (default) or "transactional"
    # @param metadata [Hash] Custom JSON metadata to attach to the message (max 4KB)
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
    def schedule(to:, text:, scheduled_at:, from: nil, message_type: nil, metadata: nil)
      validate_phone!(to)
      validate_text!(text)
      raise ValidationError, "scheduled_at is required" if scheduled_at.nil? || scheduled_at.empty?

      body = { to: to, text: text, scheduledAt: scheduled_at }
      body[:from] = from if from
      body[:messageType] = message_type if message_type
      body[:metadata] = metadata if metadata

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
    # @param message_type [String] Message type: "marketing" (default) or "transactional"
    # @param metadata [Hash] Shared metadata for all messages (max 4KB). Each message can also have its own metadata hash which takes priority.
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
    def send_batch(messages:, from: nil, message_type: nil, metadata: nil)
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
      body[:messageType] = message_type if message_type
      body[:metadata] = metadata if metadata

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

    # Preview a batch without sending (dry run)
    #
    # @param messages [Array<Hash>] Array of messages with :to and :text keys
    # @param from [String] Sender ID or phone number (optional, applies to all)
    # @param message_type [String] Message type: "marketing" (default) or "transactional"
    # @return [Hash] Preview showing what would happen if batch was sent
    #
    # @raise [Sendly::ValidationError] If parameters are invalid
    #
    # @example
    #   preview = client.messages.preview_batch(
    #     messages: [
    #       { to: "+15551234567", text: "Hello Alice!" },
    #       { to: "+15559876543", text: "Hello Bob!" }
    #     ]
    #   )
    #   puts "Can send: #{preview['canSend']}"
    #   puts "Credits needed: #{preview['creditsNeeded']}"
    def preview_batch(messages:, from: nil, message_type: nil)
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
      body[:messageType] = message_type if message_type

      client.post("/messages/batch/preview", body)
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
