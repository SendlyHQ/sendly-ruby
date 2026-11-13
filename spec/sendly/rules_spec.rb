# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::RulesResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }

  def rule(enabled)
    {
      'id' => 'rule_abc123', 'name' => 'Urgent', 'conditions' => {}, 'actions' => {}, 'priority' => 0,
      'enabled' => enabled, 'createdAt' => '2026-11-01T10:00:00.000Z', 'updatedAt' => '2026-11-13T10:00:00.000Z'
    }
  end

  describe '#update' do
    it 'sends enabled false and reads it back' do
      stub = stub_request_with_auth(:patch, '/rules/rule_abc123', response_body: rule(false))
             .with(body: { enabled: false }.to_json)

      updated = client.rules.update('rule_abc123', enabled: false)

      expect(stub).to have_been_requested
      expect(updated.enabled).to be false
    end

    it 'leaves enabled out when it is not given' do
      stub = stub_request_with_auth(:patch, '/rules/rule_abc123', response_body: rule(true))
             .with(body: { name: 'Urgent' }.to_json)

      client.rules.update('rule_abc123', name: 'Urgent')

      expect(stub).to have_been_requested
    end
  end
end
