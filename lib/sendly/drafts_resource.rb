# frozen_string_literal: true

module Sendly
  class DraftsResource
    def initialize(client)
      @client = client
    end

    def create(conversation_id:, text:, media_urls: nil, metadata: nil, source: nil)
      body = { conversationId: conversation_id, text: text }
      body[:mediaUrls] = media_urls if media_urls
      body[:metadata] = metadata if metadata
      body[:source] = source if source

      response = @client.post("/drafts", body)
      Draft.new(response)
    end

    def list(conversation_id: nil, status: nil, limit: nil, offset: nil)
      params = {}
      params[:conversation_id] = conversation_id if conversation_id
      params[:status] = status if status
      params[:limit] = limit if limit
      params[:offset] = offset if offset

      response = @client.get("/drafts", params.compact)
      DraftList.new(response)
    end

    def get(id)
      raise ValidationError, "Draft ID is required" if id.nil? || id.empty?

      response = @client.get("/drafts/#{URI.encode_www_form_component(id)}")
      Draft.new(response)
    end

    def update(id, text: nil, media_urls: nil, metadata: nil)
      raise ValidationError, "Draft ID is required" if id.nil? || id.empty?

      body = {}
      body[:text] = text if text
      body[:mediaUrls] = media_urls if media_urls
      body[:metadata] = metadata unless metadata.nil?

      response = @client.patch("/drafts/#{URI.encode_www_form_component(id)}", body)
      Draft.new(response)
    end

    def approve(id)
      raise ValidationError, "Draft ID is required" if id.nil? || id.empty?

      response = @client.post("/drafts/#{URI.encode_www_form_component(id)}/approve")
      Draft.new(response)
    end

    def reject(id, reason: nil)
      raise ValidationError, "Draft ID is required" if id.nil? || id.empty?

      body = {}
      body[:reason] = reason if reason

      response = @client.post("/drafts/#{URI.encode_www_form_component(id)}/reject", body)
      Draft.new(response)
    end
  end
end
