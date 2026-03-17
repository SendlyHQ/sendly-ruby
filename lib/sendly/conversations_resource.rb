# frozen_string_literal: true

module Sendly
  class ConversationsResource
    def initialize(client)
      @client = client
    end

    def list(limit: 20, offset: 0, status: nil)
      params = {
        limit: [limit, 100].min,
        offset: offset
      }
      params[:status] = status if status

      response = @client.get("/conversations", params.compact)
      ConversationList.new(response)
    end

    def get(id, include_messages: false, message_limit: nil, message_offset: nil)
      raise ValidationError, "Conversation ID is required" if id.nil? || id.empty?

      params = {}
      params[:include_messages] = true if include_messages
      params[:message_limit] = message_limit if message_limit
      params[:message_offset] = message_offset if message_offset

      encoded_id = URI.encode_www_form_component(id)
      response = @client.get("/conversations/#{encoded_id}", params.compact)
      ConversationWithMessages.new(response)
    end

    def reply(id, text:, media_urls: nil, metadata: nil)
      raise ValidationError, "Conversation ID is required" if id.nil? || id.empty?
      raise ValidationError, "Message text is required" if text.nil? || text.empty?

      body = { text: text }
      body[:mediaUrls] = media_urls if media_urls
      body[:metadata] = metadata if metadata

      encoded_id = URI.encode_www_form_component(id)
      response = @client.post("/conversations/#{encoded_id}/messages", body)
      Message.new(response)
    end

    def update(id, metadata: nil, tags: nil)
      raise ValidationError, "Conversation ID is required" if id.nil? || id.empty?

      body = {}
      body[:metadata] = metadata unless metadata.nil?
      body[:tags] = tags unless tags.nil?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.patch("/conversations/#{encoded_id}", body)
      Conversation.new(response)
    end

    def close(id)
      raise ValidationError, "Conversation ID is required" if id.nil? || id.empty?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.post("/conversations/#{encoded_id}/close")
      Conversation.new(response)
    end

    def reopen(id)
      raise ValidationError, "Conversation ID is required" if id.nil? || id.empty?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.post("/conversations/#{encoded_id}/reopen")
      Conversation.new(response)
    end

    def mark_read(id)
      raise ValidationError, "Conversation ID is required" if id.nil? || id.empty?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.post("/conversations/#{encoded_id}/mark-read")
      Conversation.new(response)
    end

    def add_labels(id, label_ids:)
      raise ValidationError, "Conversation ID is required" if id.nil? || id.empty?
      raise ValidationError, "Label IDs are required" if label_ids.nil? || label_ids.empty?

      encoded_id = URI.encode_www_form_component(id)
      @client.post("/conversations/#{encoded_id}/labels", { labelIds: label_ids })
    end

    def remove_label(id, label_id:)
      raise ValidationError, "Conversation ID is required" if id.nil? || id.empty?
      raise ValidationError, "Label ID is required" if label_id.nil? || label_id.empty?

      encoded_id = URI.encode_www_form_component(id)
      encoded_label_id = URI.encode_www_form_component(label_id)
      @client.delete("/conversations/#{encoded_id}/labels/#{encoded_label_id}")
    end

    def each(status: nil, batch_size: 100, &block)
      return enum_for(:each, status: status, batch_size: batch_size) unless block_given?

      offset = 0
      loop do
        page = list(limit: batch_size, offset: offset, status: status)
        page.each(&block)

        break unless page.has_more

        offset += batch_size
      end
    end
  end
end
