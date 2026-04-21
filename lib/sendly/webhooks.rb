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
  #           puts "Message delivered: #{event.data.id}"
  #         when 'message.failed'
  #           puts "Message failed: #{event.data.error}"
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
    EVENT_MESSAGE_QUEUED                = "message.queued"
    EVENT_MESSAGE_SENT                  = "message.sent"
    EVENT_MESSAGE_DELIVERED             = "message.delivered"
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
    EVENT_CONTACT_AUTO_FLAGGED          = "contact.auto_flagged"
    EVENT_CONTACT_MARKED_VALID          = "contact.marked_valid"
    EVENT_CONTACTS_LOOKUP_COMPLETED     = "contacts.lookup_completed"
    EVENT_CONTACTS_BULK_MARKED_VALID    = "contacts.bulk_marked_valid"

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

  class WebhookEvent
    attr_reader :id, :type, :data, :created, :api_version, :livemode

    def initialize(data)
      @id = data[:id]
      @type = data[:type]
      obj = data[:data][:object] || data[:data]
      @data = WebhookMessageData.new(obj)
      @created = data[:created] || data[:created_at] || 0
      @api_version = data[:api_version] || '2024-01'
      @livemode = data[:livemode] || false
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
  end

  class WebhookMessageData
    attr_reader :id, :status, :to, :from, :direction, :organization_id,
                :text, :error, :error_code, :delivered_at, :failed_at,
                :created_at, :segments, :credits_used, :message_format, :media_urls,
                :retry_count, :metadata, :batch_id

    def initialize(data)
      @id = data[:id] || data[:message_id] || ''
      @status = data[:status]
      @to = data[:to]
      @from = data[:from] || ''
      @direction = data[:direction] || 'outbound'
      @organization_id = data[:organization_id]
      @text = data[:text]
      @error = data[:error]
      @error_code = data[:error_code]
      @delivered_at = data[:delivered_at]
      @failed_at = data[:failed_at]
      @created_at = data[:created_at]
      @segments = data[:segments] || 1
      @credits_used = data[:credits_used] || 0
      @message_format = data[:message_format]
      @media_urls = data[:media_urls]
      @retry_count = data[:retry_count]
      @metadata = data[:metadata]
      @batch_id = data[:batch_id]
    end

    def message_id
      @id
    end

    def to_h
      {
        id: @id,
        status: @status,
        to: @to,
        from: @from,
        direction: @direction,
        error: @error,
        error_code: @error_code,
        delivered_at: @delivered_at,
        failed_at: @failed_at,
        segments: @segments,
        credits_used: @credits_used,
        batch_id: @batch_id
      }.compact
    end
  end

  class WebhookVerificationData
    attr_reader :id, :organization_id, :phone, :status, :delivery_status,
                :attempts, :max_attempts, :expires_at, :verified_at,
                :created_at, :app_name, :template_id, :profile_id, :metadata

    def initialize(data = {})
      @id = data["id"]
      @organization_id = data["organization_id"]
      @phone = data["phone"]
      @status = data["status"]
      @delivery_status = data["delivery_status"] || "queued"
      @attempts = data["attempts"] || 0
      @max_attempts = data["max_attempts"] || 3
      @expires_at = data["expires_at"]
      @verified_at = data["verified_at"]
      @created_at = data["created_at"]
      @app_name = data["app_name"]
      @template_id = data["template_id"]
      @profile_id = data["profile_id"]
      @metadata = data["metadata"]
    end
  end
end
