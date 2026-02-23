# frozen_string_literal: true

module Sendly
  # Account resource for accessing account information, credits, and API keys
  class AccountResource
    # @param client [Sendly::Client] The API client
    def initialize(client)
      @client = client
    end

    # Get account information
    #
    # @return [Sendly::Account]
    def get
      response = @client.get("/account")
      Account.new(response)
    end

    # Get credit balance
    #
    # @return [Sendly::Credits]
    #
    # @example
    #   credits = client.account.credits
    #   puts "Available: #{credits.available_balance} credits"
    def credits
      response = @client.get("/credits")
      Credits.new(response)
    end

    # Get credit transaction history
    #
    # @param limit [Integer, nil] Maximum number of transactions to return
    # @param offset [Integer, nil] Number of transactions to skip
    # @return [Array<Sendly::CreditTransaction>]
    def transactions(limit: nil, offset: nil)
      params = {}
      params[:limit] = limit if limit
      params[:offset] = offset if offset

      response = @client.get("/credits/transactions", params)
      response.map { |data| CreditTransaction.new(data) }
    end

    # List API keys for the account
    #
    # @return [Array<Sendly::ApiKey>]
    def api_keys
      response = @client.get("/keys")
      response.map { |data| ApiKey.new(data) }
    end

    # Get a specific API key by ID
    #
    # @param key_id [String] API key ID
    # @return [Sendly::ApiKey]
    def api_key(key_id)
      response = @client.get("/keys/#{key_id}")
      ApiKey.new(response)
    end

    # Get usage statistics for an API key
    #
    # @param key_id [String] API key ID
    # @return [Hash] Usage statistics
    def api_key_usage(key_id)
      @client.get("/keys/#{key_id}/usage")
    end

    # Create a new API key
    #
    # @param name [String] Display name for the API key
    # @param expires_at [String, nil] Optional expiration date (ISO 8601)
    # @return [Hash] Contains 'apiKey' (metadata) and 'key' (full secret - only shown once!)
    #
    # @example
    #   result = client.account.create_api_key("Production")
    #   puts "Save this key: #{result['key']}"  # Only shown once!
    def create_api_key(name, expires_at: nil)
      raise ArgumentError, "API key name is required" if name.nil? || name.empty?

      body = { name: name }
      body[:expiresAt] = expires_at if expires_at

      @client.post("/account/keys", body)
    end

    # Revoke an API key
    #
    # @param key_id [String] API key ID to revoke
    # @return [void]
    def revoke_api_key(key_id)
      raise ArgumentError, "API key ID is required" if key_id.nil? || key_id.empty?

      @client.delete("/account/keys/#{key_id}")
    end

    def transfer_credits(target_organization_id:, amount:)
      raise ArgumentError, "Target organization ID is required" if target_organization_id.nil? || target_organization_id.empty?
      raise ArgumentError, "Amount must be a positive integer" if !amount.is_a?(Integer) || amount <= 0

      @client.post("/credits/transfer", {
        targetOrganizationId: target_organization_id,
        amount: amount
      })
    end
  end
end
