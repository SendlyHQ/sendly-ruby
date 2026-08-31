# frozen_string_literal: true

module Sendly
  class Template
    attr_reader :id, :name, :text, :variables, :is_preset, :preset_slug,
                :status, :version, :published_at, :created_at, :updated_at

    # @deprecated Templates are not scoped by locale. The API returns no
    #   locale field, so this is always nil. There is no replacement.
    attr_reader :locale

    # @deprecated The API has no concept of a default template. It returns no
    #   such field, so this is always false. There is no replacement.
    attr_reader :is_default

    STATUSES = %w[draft published].freeze

    # @deprecated Preset and custom are distinguished by {#is_preset} /
    #   {#preset?} now. For the values {#status} can hold, see {STATUSES}.
    TYPES = %w[preset custom].freeze

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @text = data["text"]
      @variables = data["variables"] || []
      @is_preset = data["is_preset"] || data["isPreset"] || false
      @preset_slug = data["preset_slug"] || data["presetSlug"]
      @status = data["status"]
      @version = data["version"]
      @published_at = parse_time(data["published_at"] || data["publishedAt"])
      @created_at = parse_time(data["created_at"] || data["createdAt"])
      @updated_at = parse_time(data["updated_at"] || data["updatedAt"])
      @locale = data["locale"]
      @is_default = data["isDefault"] || data["is_default"] || false
    end

    alias body text

    # @deprecated Use {#is_preset} or {#preset?}. Derived from {#is_preset}:
    #   "preset" for a preset template, "custom" for your own.
    # @return [String]
    def type
      is_preset ? "preset" : "custom"
    end

    # @deprecated Use {#status} or {#published?}. Derived from {#status}.
    # @return [Boolean]
    def is_published
      status == "published"
    end

    def preset?
      is_preset
    end

    def custom?
      !is_preset
    end

    def published?
      status == "published"
    end

    def to_h
      {
        id: id, name: name, text: text, variables: variables,
        is_preset: is_preset, preset_slug: preset_slug, status: status,
        version: version, published_at: published_at&.iso8601,
        created_at: created_at&.iso8601, updated_at: updated_at&.iso8601,
        body: body, type: type, locale: locale, is_default: is_default,
        is_published: is_published
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

  class TemplatesResource
    def initialize(client)
      @client = client
    end

    # List templates visible to the API key, presets included.
    #
    # @param limit [Integer, nil] Deprecated and unsupported. The list route
    #   returns every visible template in one response and does not paginate.
    #   Passing a value raises ArgumentError; slice the returned +:templates+
    #   array instead.
    # @param type [String, nil] Deprecated and unsupported. The list route does
    #   not filter. Passing a value raises ArgumentError; select over the
    #   returned +:templates+ with {Template#preset?} / {Template#custom?}
    #   instead.
    # @param locale [String, nil] Deprecated and unsupported. Templates are not
    #   scoped by locale. Passing a value raises ArgumentError; there is no
    #   replacement.
    # @raise [ArgumentError] if +limit+, +type+ or +locale+ is given
    # @return [Hash] +:templates+ (Array<Sendly::Template>) and +:pagination+,
    #   which is always nil because the route does not paginate
    def list(limit: nil, type: nil, locale: nil)
      unless limit.nil?
        raise ArgumentError,
              "limit is not supported: the templates list route returns every " \
              "visible template in one response and does not paginate. Slice " \
              "the returned :templates array instead."
      end

      unless type.nil?
        raise ArgumentError,
              "type is not supported: the templates list route does not filter. " \
              "Select over the returned :templates array with " \
              "Sendly::Template#preset? or #custom? instead."
      end

      reject_locale!(locale)

      response = @client.get("/templates")
      {
        templates: (response["templates"] || []).map { |t| Template.new(t) },
        pagination: response["pagination"]
      }
    end

    def get(id)
      response = @client.get("/templates/#{id}")
      Template.new(response)
    end

    # Create a template. New templates start as drafts; call {#publish} to
    # make one usable.
    #
    # @param name [String] Template name
    # @param text [String] Template text, with +{{variable}}+ placeholders
    # @param body [String, nil] Deprecated alias for +text+. Sent as +text+.
    #   Pass +text+.
    # @param locale [String, nil] Deprecated and unsupported. Templates are not
    #   scoped by locale. Passing a value raises ArgumentError; there is no
    #   replacement.
    # @param is_published [Boolean, nil] Deprecated. Templates are always
    #   created as drafts, so +false+ is accepted as a no-op and +true+ raises
    #   ArgumentError. Call {#publish} on the new template instead.
    # @raise [ArgumentError] if +locale+ is given, if +is_published+ is true, or
    #   if neither +text+ nor +body+ is given
    # @return [Sendly::Template]
    def create(name:, text: nil, body: nil, locale: nil, is_published: nil)
      reject_locale!(locale)

      if is_published
        raise ArgumentError,
              "is_published: true is not supported on create: templates are " \
              "always created as drafts. Publishing is a separate call - use " \
              "publish(id) on the returned template instead."
      end

      content = text || body
      raise ArgumentError, "text is required" if content.nil?

      response = @client.post("/templates", { name: name, text: content })
      Template.new(response)
    end

    # Update a draft template. Published templates cannot be edited; publish a
    # new template instead.
    #
    # @param id [String] Template ID
    # @param name [String, nil] New name
    # @param text [String, nil] New template text
    # @param body [String, nil] Deprecated alias for +text+. Sent as +text+.
    #   Pass +text+.
    # @param locale [String, nil] Deprecated and unsupported. Templates are not
    #   scoped by locale. Passing a value raises ArgumentError; there is no
    #   replacement.
    # @param is_published [Boolean, nil] Deprecated. An update never changes a
    #   template's status, and only drafts are editable, so +false+ is accepted
    #   as a no-op and +true+ raises ArgumentError. Call {#publish} instead.
    # @raise [ArgumentError] if +locale+ is given or +is_published+ is true
    # @return [Sendly::Template]
    def update(id, name: nil, text: nil, body: nil, locale: nil, is_published: nil)
      reject_locale!(locale)

      if is_published
        raise ArgumentError,
              "is_published: true is not supported on update: an update never " \
              "changes a template's status. Publishing is a separate call - " \
              "use publish(id) instead."
      end

      content = text || body

      request_body = {}
      request_body[:name] = name if name
      request_body[:text] = content if content

      response = @client.patch("/templates/#{id}", request_body)
      Template.new(response)
    end

    def delete(id)
      @client.delete("/templates/#{id}")
    end

    def publish(id)
      response = @client.post("/templates/#{id}/publish")
      Template.new(response)
    end

    # Unpublish a published template.
    #
    # @note Not available yet: the versioned API serves no unpublish route, so
    #   this call fails with a 404. To retire a published template today,
    #   {#create} and {#publish} a replacement, then {#delete} this one.
    def unpublish(id)
      response = @client.post("/templates/#{id}/unpublish")
      Template.new(response)
    end

    # Copy an existing template into a new draft.
    #
    # @note Not available yet: the versioned API serves no clone route, so
    #   this call fails with a 404. To copy a template today, read it with
    #   {#get} and pass its {Template#text} to {#create}.
    def clone(id, name: nil)
      body = {}
      body[:name] = name if name
      response = @client.post("/templates/#{id}/clone", body)
      Template.new(response)
    end

    def generate(description:, category: nil)
      body = { description: description }
      body[:category] = category if category
      response = @client.post("/templates/generate", body)
      GeneratedTemplate.new(response)
    end

    private

    def reject_locale!(locale)
      return if locale.nil?

      raise ArgumentError,
            "locale is not supported: templates are not scoped by locale and " \
            "the API stores no locale field. There is no replacement - keep " \
            "per-locale wording in separate templates."
    end
  end
end
