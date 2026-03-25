# frozen_string_literal: true

module Sendly
  class RulesResource
    def initialize(client)
      @client = client
    end

    def list
      response = @client.get("/rules")
      (response["data"] || []).map { |r| Rule.new(r) }
    end

    def create(name:, conditions:, actions:, priority: nil)
      body = { name: name, conditions: conditions, actions: actions }
      body[:priority] = priority if priority

      response = @client.post("/rules", body)
      Rule.new(response)
    end

    def update(id, name: nil, conditions: nil, actions: nil, priority: nil)
      raise ValidationError, "Rule ID is required" if id.nil? || id.empty?

      body = {}
      body[:name] = name if name
      body[:conditions] = conditions if conditions
      body[:actions] = actions if actions
      body[:priority] = priority if priority

      response = @client.patch("/rules/#{URI.encode_www_form_component(id)}", body)
      Rule.new(response)
    end

    def delete(id)
      raise ValidationError, "Rule ID is required" if id.nil? || id.empty?

      @client.delete("/rules/#{URI.encode_www_form_component(id)}")
    end
  end
end
