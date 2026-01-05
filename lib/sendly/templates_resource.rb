# frozen_string_literal: true

module Sendly
  class Template
    attr_reader :id, :name, :body, :type, :locale, :variables, :is_default,
                :is_published, :created_at, :updated_at

    TYPES = %w[preset custom].freeze

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @body = data["body"]
      @type = data["type"] || "custom"
      @locale = data["locale"]
      @variables = data["variables"] || []
      @is_default = data["isDefault"] || data["is_default"] || false
      @is_published = data["isPublished"] || data["is_published"] || false
      @created_at = parse_time(data["createdAt"] || data["created_at"])
      @updated_at = parse_time(data["updatedAt"] || data["updated_at"])
    end

    def preset?
      type == "preset"
    end

    def custom?
      type == "custom"
    end

    def published?
      is_published
    end

    def to_h
      {
        id: id, name: name, body: body, type: type, locale: locale,
        variables: variables, is_default: is_default, is_published: is_published,
        created_at: created_at&.iso8601, updated_at: updated_at&.iso8601
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

    def list(limit: nil, type: nil, locale: nil)
      params = {}
      params[:limit] = limit if limit
      params[:type] = type if type
      params[:locale] = locale if locale

      response = @client.get("/verify/templates", params)
      templates = (response["templates"] || []).map { |t| Template.new(t) }
      { templates: templates, pagination: response["pagination"] }
    end

    def get(id)
      response = @client.get("/verify/templates/#{id}")
      Template.new(response)
    end

    def create(name:, body:, locale: nil, is_published: nil)
      request_body = { name: name, body: body }
      request_body[:locale] = locale if locale
      request_body[:isPublished] = is_published unless is_published.nil?

      response = @client.post("/verify/templates", request_body)
      Template.new(response)
    end

    def update(id, name: nil, body: nil, locale: nil, is_published: nil)
      request_body = {}
      request_body[:name] = name if name
      request_body[:body] = body if body
      request_body[:locale] = locale if locale
      request_body[:isPublished] = is_published unless is_published.nil?

      response = @client.patch("/verify/templates/#{id}", request_body)
      Template.new(response)
    end

    def delete(id)
      @client.delete("/verify/templates/#{id}")
    end

    def publish(id)
      response = @client.post("/verify/templates/#{id}/publish")
      Template.new(response)
    end

    def unpublish(id)
      response = @client.post("/verify/templates/#{id}/unpublish")
      Template.new(response)
    end
  end
end
