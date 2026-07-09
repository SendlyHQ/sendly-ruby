# frozen_string_literal: true

module Sendly
  # A newly minted branded short link, as returned by {LinksResource#create}.
  class ShortLink
    # @return [String] Short code (the segment after the domain, e.g. "Ab3xY7")
    attr_reader :code

    # @return [String] Full branded short URL to share (e.g. "https://sendly.live/l/Ab3xY7")
    attr_reader :short_url

    # @return [String] The destination the short link redirects to
    attr_reader :destination_url

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data)
      @raw = data
      @code = data["code"]
      @short_url = data["shortUrl"] || data["short_url"]
      @destination_url = data["destinationUrl"] || data["destination_url"]
    end

    def to_h
      {
        code: code, short_url: short_url, destination_url: destination_url
      }.compact
    end
  end

  # A short link with click analytics, as returned by {LinksResource#list}.
  class ShortLinkListItem
    attr_reader :code, :short_url, :destination_url, :brand_slug, :click_count,
                :disabled, :last_country, :last_clicked_at, :created_at, :spark

    def initialize(data)
      @code = data["code"]
      @short_url = data["shortUrl"] || data["short_url"]
      @destination_url = data["destinationUrl"] || data["destination_url"]
      @brand_slug = data["brandSlug"] || data["brand_slug"]
      @click_count = data["clickCount"] || data["click_count"] || 0
      @disabled = data["disabled"] || false
      @last_country = data["lastCountry"] || data["last_country"]
      @last_clicked_at = parse_time(data["lastClickedAt"] || data["last_clicked_at"])
      @created_at = parse_time(data["createdAt"] || data["created_at"])
      # 14-day daily click histogram, oldest first (today last)
      @spark = data["spark"] || []
    end

    # @return [Boolean] Whether the link is disabled (its redirect returns 404)
    def disabled?
      disabled
    end

    def to_h
      {
        code: code, short_url: short_url, destination_url: destination_url,
        brand_slug: brand_slug, click_count: click_count, disabled: disabled,
        last_country: last_country, last_clicked_at: last_clicked_at&.iso8601,
        created_at: created_at&.iso8601, spark: spark
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

  # A page of short links with their click analytics.
  class ShortLinkList
    include Enumerable

    # @return [Array<ShortLinkListItem>] The workspace's short links, newest first
    attr_reader :links

    # @return [Integer] Total number of short links in the workspace
    attr_reader :total

    def initialize(response)
      @links = (response["links"] || []).map { |l| ShortLinkListItem.new(l) }
      @total = response["total"] || @links.length
    end

    def each(&block)
      links.each(&block)
    end

    def count
      links.length
    end

    alias size count
    alias length count

    def empty?
      links.empty?
    end

    def first
      links.first
    end

    def last
      links.last
    end
  end

  # The code and new disabled state returned when a link's kill switch is toggled.
  class ShortLinkStatus
    # @return [String] Short code that was updated
    attr_reader :code

    # @return [Boolean] New disabled state
    attr_reader :disabled

    def initialize(data)
      @code = data["code"]
      @disabled = data["disabled"] || false
    end

    # @return [Boolean] Whether the link is now disabled
    def disabled?
      disabled
    end

    def to_h
      { code: code, disabled: disabled }
    end
  end

  # Links resource — branded URL shortening.
  #
  # Mint branded short links for a destination URL, list the links your
  # workspace has created (with click analytics), and enable or disable an
  # individual link (a per-link kill switch).
  #
  # Branded, owned-domain short links improve deliverability — carriers filter
  # public shorteners — and give you click data.
  #
  # NOTE: URL shortening is not yet generally available. It is gated behind the
  # +url_shortener+ rollout flag (currently founder-only); for API-key clients a
  # flag-off account reads as a 404 {Sendly::NotFoundError} (the feature is
  # absent) until the flag is on for your account.
  #
  # @example Shorten a URL
  #   link = client.links.create(url: "https://example.com/spring-sale?utm_source=sms")
  #   puts link.short_url # => "https://sendly.live/l/Ab3xY7"
  #
  # @example List your links with click counts
  #   result = client.links.list(limit: 20)
  #   result.each { |l| puts "#{l.short_url} -> #{l.destination_url} (#{l.click_count} clicks)" }
  #
  # @example Kill a link
  #   client.links.disable(link.code)
  class LinksResource
    def initialize(client)
      @client = client
    end

    # Mint a branded short link for a destination URL. Uses your workspace's
    # brand slug when one is configured.
    #
    # @param url [String] The destination URL to shorten (must be http/https)
    # @return [Sendly::ShortLink] The short link (code, short_url, destination_url)
    #
    # @raise [Sendly::ValidationError] If url is missing or not an http/https URL
    def create(url:)
      validate_url!(url)

      response = @client.post("/links", { url: url })
      ShortLink.new(response)
    end

    # List the short links your workspace has created, newest first, with click
    # counts and a 14-day daily click histogram.
    #
    # @param limit [Integer, nil] Maximum links to return (default 50, max 200)
    # @param offset [Integer, nil] Number of links to skip (default 0)
    # @return [Sendly::ShortLinkList] The links and a total count
    def list(limit: nil, offset: nil)
      params = {}
      params[:limit] = limit if limit
      params[:offset] = offset if offset

      response = @client.get("/links", params)
      ShortLinkList.new(response)
    end

    # Enable or disable a short link. A disabled link's redirect returns 404
    # until it is re-enabled.
    #
    # @param code [String] The short link code
    # @param disabled [Boolean] true to disable, false to re-enable
    # @return [Sendly::ShortLinkStatus] The link's code and new disabled state
    #
    # @raise [Sendly::NotFoundError] If no such link exists in your workspace
    def update(code, disabled:)
      raise ValidationError, "Link code is required" if code.nil? || code.to_s.empty?

      encoded_code = URI.encode_www_form_component(code)
      response = @client.patch("/links/#{encoded_code}", { disabled: disabled })
      ShortLinkStatus.new(response)
    end

    # Disable a short link (its redirect returns 404 until re-enabled).
    # Convenience wrapper over {#update}.
    #
    # @param code [String] The short link code
    # @return [Sendly::ShortLinkStatus]
    def disable(code)
      update(code, disabled: true)
    end

    # Re-enable a previously disabled short link. Convenience wrapper over
    # {#update}.
    #
    # @param code [String] The short link code
    # @return [Sendly::ShortLinkStatus]
    def enable(code)
      update(code, disabled: false)
    end

    private

    # Client-side guard mirroring the server's http/https-only check.
    def validate_url!(url)
      raise ValidationError, "url is required" if url.nil? || url.to_s.empty?

      return if url.is_a?(String) && (url.start_with?("http://") || url.start_with?("https://"))

      raise ValidationError, "url must be an http:// or https:// URL"
    end
  end
end
