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
  #       payload = request.raw_post
  #
  #       begin
  #         event = Sendly::Webhooks.parse_event(payload, signature, ENV['WEBHOOK_SECRET'])
  #
  #         case event.type
  #         when 'message.delivered'
  #           puts "Message delivered: #{event.data.message_id}"
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
    class << self
      # Verify webhook signature from Sendly.
      #
      # @param payload [String] Raw request body as string
      # @param signature [String] X-Sendly-Signature header value
      # @param secret [String] Your webhook secret from dashboard
      # @return [Boolean] True if signature is valid, false otherwise
      def verify_signature(payload, signature, secret)
        return false if payload.nil? || payload.empty?
        return false if signature.nil? || signature.empty?
        return false if secret.nil? || secret.empty?

        expected = 'sha256=' + OpenSSL::HMAC.hexdigest('SHA256', secret, payload)

        # Timing-safe comparison
        secure_compare(expected, signature)
      end

      # Parse and validate a webhook event.
      #
      # @param payload [String] Raw request body as string
      # @param signature [String] X-Sendly-Signature header value
      # @param secret [String] Your webhook secret from dashboard
      # @return [WebhookEvent] Parsed and validated event
      # @raise [WebhookSignatureError] If signature is invalid or payload is malformed
      def parse_event(payload, signature, secret)
        raise WebhookSignatureError, 'Invalid webhook signature' unless verify_signature(payload, signature, secret)

        data = JSON.parse(payload, symbolize_names: true)

        unless data[:id] && data[:type] && data[:data] && data[:created_at]
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
      # @return [String] The signature in the format "sha256=..."
      def generate_signature(payload, secret)
        'sha256=' + OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
      end

      private

      # Timing-safe string comparison
      def secure_compare(a, b)
        return false unless a.bytesize == b.bytesize

        l = a.unpack('C*')
        res = 0
        b.each_byte { |byte| res |= byte ^ l.shift }
        res.zero?
      end
    end
  end

  # Webhook signature verification error
  class WebhookSignatureError < Error
    def initialize(message = 'Invalid webhook signature')
      super(message, code: 'WEBHOOK_SIGNATURE_ERROR')
    end
  end

  # Webhook event from Sendly
  class WebhookEvent
    attr_reader :id, :type, :data, :created_at, :api_version

    def initialize(data)
      @id = data[:id]
      @type = data[:type]
      @data = WebhookMessageData.new(data[:data])
      @created_at = data[:created_at]
      @api_version = data[:api_version] || '2024-01-01'
    end

    def to_h
      {
        id: @id,
        type: @type,
        data: @data.to_h,
        created_at: @created_at,
        api_version: @api_version
      }
    end
  end

  # Webhook message data
  class WebhookMessageData
    attr_reader :message_id, :status, :to, :from, :error, :error_code,
                :delivered_at, :failed_at, :segments, :credits_used

    def initialize(data)
      @message_id = data[:message_id]
      @status = data[:status]
      @to = data[:to]
      @from = data[:from] || ''
      @error = data[:error]
      @error_code = data[:error_code]
      @delivered_at = data[:delivered_at]
      @failed_at = data[:failed_at]
      @segments = data[:segments] || 1
      @credits_used = data[:credits_used] || 0
    end

    def to_h
      {
        message_id: @message_id,
        status: @status,
        to: @to,
        from: @from,
        error: @error,
        error_code: @error_code,
        delivered_at: @delivered_at,
        failed_at: @failed_at,
        segments: @segments,
        credits_used: @credits_used
      }.compact
    end
  end
end
