# frozen_string_literal: true

require "json"
require "time"

require_relative "sendly/version"
require_relative "sendly/errors"
require_relative "sendly/types"
require_relative "sendly/client"
require_relative "sendly/messages"
require_relative "sendly/webhooks"
require_relative "sendly/webhooks_resource"
require_relative "sendly/account_resource"
require_relative "sendly/verify"
require_relative "sendly/templates_resource"
require_relative "sendly/campaigns_resource"
require_relative "sendly/contacts_resource"

# Sendly Ruby SDK
#
# Official Ruby client for the Sendly SMS API.
#
# @example Basic usage
#   client = Sendly::Client.new("sk_live_v1_xxx")
#   message = client.messages.send(to: "+15551234567", text: "Hello!")
#
module Sendly
  class << self
    # @return [String, nil] Default API key
    attr_accessor :api_key

    # @return [String] Default base URL
    attr_accessor :base_url

    # Configure the SDK with default options
    #
    # @yield [self] Yields self for configuration
    # @return [void]
    #
    # @example
    #   Sendly.configure do |config|
    #     config.api_key = "sk_live_v1_xxx"
    #   end
    def configure
      yield self
    end

    # Create a client with the default API key
    #
    # @return [Sendly::Client]
    def client
      @client ||= Client.new(api_key: api_key)
    end

    # Send a message using the default client
    #
    # @param to [String] Recipient phone number
    # @param text [String] Message content
    # @return [Sendly::Message]
    def send_message(to:, text:)
      client.messages.send(to: to, text: text)
    end
  end

  self.base_url = "https://sendly.live/api/v1"
end
