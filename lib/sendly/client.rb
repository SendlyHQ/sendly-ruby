# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "securerandom"

module Sendly
  # Main Sendly API client
  class Client
    # @return [String] API key
    attr_reader :api_key

    # @return [String] Base URL
    attr_reader :base_url

    # @return [Integer] Request timeout in seconds
    attr_reader :timeout

    # @return [Integer] Maximum retry attempts
    attr_reader :max_retries

    # Create a new Sendly client
    #
    # @param api_key [String] Your Sendly API key
    # @param base_url [String] API base URL (optional)
    # @param timeout [Integer] Request timeout in seconds (default: 30)
    # @param max_retries [Integer] Maximum retry attempts (default: 3)
    #
    # @example
    #   client = Sendly::Client.new("sk_live_v1_xxx")
    #   client = Sendly::Client.new("sk_live_v1_xxx", timeout: 60, max_retries: 5)
    def initialize(api_key:, base_url: nil, timeout: 30, max_retries: 3)
      @api_key = api_key
      @base_url = (base_url || Sendly.base_url).chomp("/")
      @timeout = timeout
      @max_retries = max_retries

      validate_api_key!
    end

    # Access the Messages resource
    #
    # @return [Sendly::Messages]
    def messages
      @messages ||= Messages.new(self)
    end

    # Access the Webhooks resource
    #
    # @return [Sendly::WebhooksResource]
    def webhooks
      @webhooks ||= WebhooksResource.new(self)
    end

    # Access the Account resource
    #
    # @return [Sendly::AccountResource]
    def account
      @account ||= AccountResource.new(self)
    end

    # Access the Verify resource
    #
    # @return [Sendly::VerifyResource]
    def verify
      @verify ||= VerifyResource.new(self)
    end

    # Access the Templates resource
    #
    # @return [Sendly::TemplatesResource]
    def templates
      @templates ||= TemplatesResource.new(self)
    end

    # Access the Media resource
    #
    # @return [Sendly::Media]
    def media
      @media ||= Media.new(self)
    end

    # Access the Campaigns resource
    #
    # @return [Sendly::CampaignsResource]
    def campaigns
      @campaigns ||= CampaignsResource.new(self)
    end

    # Access the Contacts resource
    #
    # @return [Sendly::ContactsResource]
    def contacts
      @contacts ||= ContactsResource.new(self)
    end

    # Make a GET request
    #
    # @param path [String] API path
    # @param params [Hash] Query parameters
    # @return [Hash] Response body
    def get(path, params = {})
      request(:get, path, params: params)
    end

    # Make a POST request
    #
    # @param path [String] API path
    # @param body [Hash] Request body
    # @return [Hash] Response body
    def post(path, body = {})
      request(:post, path, body: body)
    end

    # Make a PATCH request
    #
    # @param path [String] API path
    # @param body [Hash] Request body
    # @return [Hash] Response body
    def patch(path, body = {})
      request(:patch, path, body: body)
    end

    # Make a DELETE request
    #
    # @param path [String] API path
    # @return [Hash] Response body
    def delete(path)
      request(:delete, path)
    end

    # Make a multipart POST request for file uploads
    #
    # @param path [String] API path
    # @param file [String, IO] File path or IO object
    # @param content_type [String] MIME type of the file
    # @param filename [String] Name for the uploaded file
    # @return [Hash] Response body
    def post_multipart(path, file, content_type: "image/jpeg", filename: "upload.jpg")
      uri = build_uri(path, {})
      http = build_http(uri)

      boundary = "SendlyRuby#{SecureRandom.hex(16)}"

      file_data = file.is_a?(String) ? File.binread(file) : file.read

      body = []
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
      body << "Content-Type: #{content_type}\r\n\r\n"
      body << file_data
      body << "\r\n--#{boundary}--\r\n"

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{api_key}"
      req["Accept"] = "application/json"
      req["User-Agent"] = "sendly-ruby/#{VERSION}"
      req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      req.body = body.join

      attempt = 0
      begin
        response = http.request(req)
        handle_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise TimeoutError, "Request timed out after #{timeout} seconds"
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
        raise NetworkError, "Connection failed: #{e.message}"
      rescue RateLimitError => e
        attempt += 1
        if attempt <= max_retries && e.retry_after
          sleep(e.retry_after)
          retry
        end
        raise
      rescue ServerError => e
        attempt += 1
        if attempt <= max_retries
          sleep(2 ** attempt)
          retry
        end
        raise
      end
    end

    private

    def validate_api_key!
      raise AuthenticationError, "API key is required" if api_key.nil? || api_key.empty?

      unless api_key.match?(/^sk_(test|live)_v1_[a-zA-Z0-9_-]+$/)
        raise AuthenticationError, "Invalid API key format. Expected sk_test_v1_xxx or sk_live_v1_xxx"
      end
    end

    def request(method, path, params: {}, body: nil)
      uri = build_uri(path, params)
      http = build_http(uri)
      req = build_request(method, uri, body)

      attempt = 0
      begin
        response = http.request(req)
        handle_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise TimeoutError, "Request timed out after #{timeout} seconds"
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
        raise NetworkError, "Connection failed: #{e.message}"
      rescue RateLimitError => e
        attempt += 1
        if attempt <= max_retries && e.retry_after
          sleep(e.retry_after)
          retry
        end
        raise
      rescue ServerError => e
        attempt += 1
        if attempt <= max_retries
          sleep(2 ** attempt) # Exponential backoff
          retry
        end
        raise
      end
    end

    def build_uri(path, params)
      url = "#{base_url}#{path}"
      uri = URI.parse(url)

      if params.any?
        query = params.map { |k, v| "#{URI.encode_www_form_component(k)}=#{URI.encode_www_form_component(v)}" }.join("&")
        uri.query = query
      end

      uri
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = timeout
      http
    end

    def build_request(method, uri, body)
      req = case method
            when :get
              Net::HTTP::Get.new(uri)
            when :post
              Net::HTTP::Post.new(uri)
            when :patch
              Net::HTTP::Patch.new(uri)
            when :delete
              Net::HTTP::Delete.new(uri)
            else
              raise ArgumentError, "Unsupported HTTP method: #{method}"
            end

      req["Authorization"] = "Bearer #{api_key}"
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"
      req["User-Agent"] = "sendly-ruby/#{VERSION}"

      req.body = body.to_json if body

      req
    end

    def handle_response(response)
      body = parse_body(response.body)
      status = response.code.to_i

      return body if status >= 200 && status < 300

      raise ErrorFactory.from_response(status, body)
    end

    def parse_body(body)
      return {} if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      { "message" => body }
    end
  end
end
