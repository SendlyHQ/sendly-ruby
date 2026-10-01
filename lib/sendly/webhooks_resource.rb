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
    # @raise [ArgumentError] If +url+ is not an https:// URL or +events+ is
    #   empty; no request is sent
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
      response = @client.get("/webhooks/#{URI.encode_www_form_component(webhook_id)}")
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
    # @raise [ArgumentError] If +webhook_id+ does not start with +whk_+ or
    #   +url+ is not an https:// URL; no request is sent
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

      response = @client.patch("/webhooks/#{URI.encode_www_form_component(webhook_id)}", body)
      Webhook.new(response)
    end

    # Delete a webhook
    #
    # @param webhook_id [String] Webhook ID
    # @return [void]
    def delete(webhook_id)
      validate_webhook_id!(webhook_id)
      @client.delete("/webhooks/#{URI.encode_www_form_component(webhook_id)}")
      nil
    end

    # Test a webhook endpoint
    #
    # @param webhook_id [String] Webhook ID
    # @return [Sendly::WebhookTestResult] The delivered test, with its status code and timing
    # @raise [Sendly::ValidationError] If the test delivery fails; the message
    #   is the API's, e.g. "Test webhook failed: ..."
    def test(webhook_id)
      validate_webhook_id!(webhook_id)
      response = @client.post("/webhooks/#{URI.encode_www_form_component(webhook_id)}/test")
      WebhookTestResult.new(response)
    end

    # Reset the circuit breaker for a webhook
    #
    # @param webhook_id [String] Webhook ID
    # @return [Hash] Reset confirmation with updated webhook
    def reset_circuit(webhook_id)
      validate_webhook_id!(webhook_id)
      @client.post("/webhooks/#{URI.encode_www_form_component(webhook_id)}/reset-circuit")
    end

    # Replay failed or cancelled webhook deliveries from the audit log.
    #
    # Use after a customer endpoint has recovered from an outage to re-fire
    # deliveries we recorded but couldn't deliver. Each replay creates a new
    # delivery row preserving the original event_id so customers can dedupe.
    # Rejects with HTTP 409 if the circuit is currently open — call
    # {#reset_circuit} first.
    #
    # @param webhook_id [String] Webhook ID
    # @param since [String, nil] ISO-8601, default now − 24h
    # @param until_ [String, nil] ISO-8601, default now
    # @param event_types [Array<String>, nil] Filter by event type
    # @param statuses [Array<String>, nil] Default ["failed", "cancelled"]
    # @param limit [Integer, nil] Max deliveries to requeue (default 1000, max 10000)
    # @return [Hash] Counts of requeued deliveries plus delivery IDs
    def redeliver(webhook_id, since: nil, until_: nil, event_types: nil, statuses: nil, limit: nil)
      validate_webhook_id!(webhook_id)
      body = {}
      body[:since] = since unless since.nil?
      body[:until] = until_ unless until_.nil?
      body[:event_types] = event_types unless event_types.nil?
      body[:statuses] = statuses unless statuses.nil?
      body[:limit] = limit unless limit.nil?
      @client.post("/webhooks/#{URI.encode_www_form_component(webhook_id)}/redeliver", body)
    end

    # Backfill missed webhook events from the underlying message log.
    #
    # Use when a circuit-breaker outage left events with no audit row (the
    # case {#redeliver} cannot recover). Synthesized message events carry the
    # same event id the original dispatch used, so dedupe on event.id. Do not
    # dedupe on event.data.object.id: a message's sent and delivered events
    # share it.
    # Rejects with HTTP 409 if the circuit is currently open — call
    # {#reset_circuit} first.
    #
    # @param webhook_id [String] Webhook ID
    # @param since [String, nil] ISO-8601, default now − 24h
    # @param until_ [String, nil] ISO-8601, default now
    # @param event_types [Array<String>, nil] Filter by event type
    # @param limit [Integer, nil] Max events to synthesize (default 1000, max 10000)
    # @return [Hash] Counts grouped by event type plus delivery IDs
    def backfill(webhook_id, since: nil, until_: nil, event_types: nil, limit: nil)
      validate_webhook_id!(webhook_id)
      body = {}
      body[:since] = since unless since.nil?
      body[:until] = until_ unless until_.nil?
      body[:event_types] = event_types unless event_types.nil?
      body[:limit] = limit unless limit.nil?
      @client.post("/webhooks/#{URI.encode_www_form_component(webhook_id)}/backfill", body)
    end

    # Rotate the webhook signing secret
    #
    # Deliveries are signed with the new secret as soon as this returns, and
    # the old secret is not kept, so have your endpoint accept both secrets
    # while you deploy the new one. The new secret is shown only once, on
    # {Sendly::WebhookSecretRotation#new_secret}.
    #
    # @param webhook_id [String] Webhook ID
    # @return [Sendly::WebhookSecretRotation]
    def rotate_secret(webhook_id)
      validate_webhook_id!(webhook_id)
      response = @client.post("/webhooks/#{URI.encode_www_form_component(webhook_id)}/rotate-secret")
      WebhookSecretRotation.new(response)
    end

    # Get delivery history for a webhook, newest first
    #
    # @param webhook_id [String] Webhook ID
    # @param limit [Integer, nil] Maximum deliveries to return (the API defaults to 50, max 100)
    # @param offset [Integer, nil] Number of deliveries to skip
    # @param status [String, nil] Only deliveries with this status
    #   (see {Sendly::WebhookDelivery::STATUSES})
    # @return [Array<Sendly::WebhookDelivery>]
    def deliveries(webhook_id, limit: nil, offset: nil, status: nil)
      validate_webhook_id!(webhook_id)
      params = {}
      params[:limit] = limit unless limit.nil?
      params[:offset] = offset unless offset.nil?
      params[:status] = status unless status.nil?

      response = @client.get("/webhooks/#{URI.encode_www_form_component(webhook_id)}/deliveries", params)
      items = response.is_a?(Hash) ? response["deliveries"] : response
      (items || []).map { |data| WebhookDelivery.new(data) }
    end

    # Retry a failed delivery
    #
    # @param webhook_id [String] Webhook ID
    # @param delivery_id [String] Delivery ID
    # @return [void]
    def retry_delivery(webhook_id, delivery_id)
      validate_webhook_id!(webhook_id)
      validate_delivery_id!(delivery_id)
      @client.post("/webhooks/#{URI.encode_www_form_component(webhook_id)}/deliveries/#{URI.encode_www_form_component(delivery_id)}/retry")
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
