# frozen_string_literal: true

module Sendly
  # Webhooks resource for managing webhook endpoints
  class WebhooksResource
    # @param client [Sendly::Client] The API client
    def initialize(client)
      @client = client
    end

    # Create a new webhook endpoint
    #
    # @param url [String] HTTPS endpoint URL
    # @param events [Array<String>] Event types to subscribe to
    # @param description [String, nil] Optional description
    # @param mode [String, nil] Event mode filter: "all", "test", or "live" (live requires verification)
    # @param metadata [Hash, nil] Custom metadata
    # @return [Sendly::WebhookCreatedResponse]
    #
    # @example
    #   webhook = client.webhooks.create(
    #     url: "https://example.com/webhooks",
    #     events: ["message.delivered", "message.failed"],
    #     mode: "all"
    #   )
    #   puts "Secret: #{webhook.secret}"  # Save this - only shown once!
    def create(url:, events:, description: nil, mode: nil, metadata: nil)
      raise ArgumentError, "Webhook URL must be HTTPS" unless url&.start_with?("https://")
      raise ArgumentError, "At least one event type is required" if events.nil? || events.empty?

      body = { url: url, events: events }
      body[:description] = description if description
      body[:mode] = mode if mode
      body[:metadata] = metadata if metadata

      response = @client.post("/webhooks", body)
      WebhookCreatedResponse.new(response)
    end

    # List all webhooks
    #
    # @return [Array<Sendly::Webhook>]
    def list
      response = @client.get("/webhooks")
      response.map { |data| Webhook.new(data) }
    end

    # Get a specific webhook by ID
    #
    # @param webhook_id [String] Webhook ID (whk_xxx)
    # @return [Sendly::Webhook]
    def get(webhook_id)
      validate_webhook_id!(webhook_id)
      response = @client.get("/webhooks/#{webhook_id}")
      Webhook.new(response)
    end

    # Update a webhook configuration
    #
    # @param webhook_id [String] Webhook ID
    # @param url [String, nil] New URL
    # @param events [Array<String>, nil] New event subscriptions
    # @param description [String, nil] New description
    # @param is_active [Boolean, nil] Enable/disable webhook
    # @param mode [String, nil] Event mode filter: "all", "test", or "live"
    # @param metadata [Hash, nil] Custom metadata
    # @return [Sendly::Webhook]
    def update(webhook_id, url: nil, events: nil, description: nil, is_active: nil, mode: nil, metadata: nil)
      validate_webhook_id!(webhook_id)
      raise ArgumentError, "Webhook URL must be HTTPS" if url && !url.start_with?("https://")

      body = {}
      body[:url] = url unless url.nil?
      body[:events] = events unless events.nil?
      body[:description] = description unless description.nil?
      body[:is_active] = is_active unless is_active.nil?
      body[:mode] = mode unless mode.nil?
      body[:metadata] = metadata unless metadata.nil?

      response = @client.patch("/webhooks/#{webhook_id}", body)
      Webhook.new(response)
    end

    # Delete a webhook
    #
    # @param webhook_id [String] Webhook ID
    # @return [void]
    def delete(webhook_id)
      validate_webhook_id!(webhook_id)
      @client.delete("/webhooks/#{webhook_id}")
      nil
    end

    # Test a webhook endpoint
    #
    # @param webhook_id [String] Webhook ID
    # @return [Sendly::WebhookTestResult]
    def test(webhook_id)
      validate_webhook_id!(webhook_id)
      response = @client.post("/webhooks/#{webhook_id}/test")
      WebhookTestResult.new(response)
    end

    # Rotate the webhook signing secret
    #
    # @param webhook_id [String] Webhook ID
    # @return [Sendly::WebhookSecretRotation]
    def rotate_secret(webhook_id)
      validate_webhook_id!(webhook_id)
      response = @client.post("/webhooks/#{webhook_id}/rotate-secret")
      WebhookSecretRotation.new(response)
    end

    # Get delivery history for a webhook
    #
    # @param webhook_id [String] Webhook ID
    # @return [Array<Sendly::WebhookDelivery>]
    def deliveries(webhook_id)
      validate_webhook_id!(webhook_id)
      response = @client.get("/webhooks/#{webhook_id}/deliveries")
      response.map { |data| WebhookDelivery.new(data) }
    end

    # Retry a failed delivery
    #
    # @param webhook_id [String] Webhook ID
    # @param delivery_id [String] Delivery ID
    # @return [void]
    def retry_delivery(webhook_id, delivery_id)
      validate_webhook_id!(webhook_id)
      validate_delivery_id!(delivery_id)
      @client.post("/webhooks/#{webhook_id}/deliveries/#{delivery_id}/retry")
      nil
    end

    # List available event types
    #
    # @return [Array<String>]
    def event_types
      response = @client.get("/webhooks/event-types")
      (response["events"] || []).map { |e| e["type"] }
    end

    private

    def validate_webhook_id!(webhook_id)
      raise ArgumentError, "Invalid webhook ID format" unless webhook_id&.start_with?("whk_")
    end

    def validate_delivery_id!(delivery_id)
      raise ArgumentError, "Invalid delivery ID format" unless delivery_id&.start_with?("del_")
    end
  end
end
