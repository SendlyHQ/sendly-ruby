# frozen_string_literal: true

module Sendly
  class LabelsResource
    def initialize(client)
      @client = client
    end

    def create(name:, color: nil, description: nil)
      body = { name: name }
      body[:color] = color if color
      body[:description] = description if description

      response = @client.post("/labels", body)
      Label.new(response)
    end

    def list
      response = @client.get("/labels")
      (response["data"] || []).map { |l| Label.new(l) }
    end

    def delete(id)
      raise ValidationError, "Label ID is required" if id.nil? || id.empty?

      @client.delete("/labels/#{URI.encode_www_form_component(id)}")
    end
  end
end
