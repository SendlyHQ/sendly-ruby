# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::EnterpriseWorkspacesSubResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:workspaces) { client.enterprise.workspaces }

  def json_ok(body, status: 200)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  describe '#inherit_verification' do
    it 'asks for a new number when purchase_new_number is true' do
      stub = stub_request(:post, "#{base_url}/enterprise/workspaces/ws_t/verification/inherit")
             .with(body: { sourceWorkspaceId: 'ws_src', purchaseNewNumber: true }.to_json)
             .to_return(json_ok({ 'verificationId' => 'ver_1', 'status' => 'pending', 'type' => 'toll_free',
                                  'tollFreeNumber' => '+18885550100', 'inheritedFrom' => 'ws_src',
                                  'newNumber' => true }, status: 201))

      result = workspaces.inherit_verification('ws_t', source_workspace_id: 'ws_src', purchase_new_number: true)

      expect(stub).to have_been_requested
      expect(result['newNumber']).to be true
    end

    it 'sends only the source workspace by default' do
      stub = stub_request(:post, "#{base_url}/enterprise/workspaces/ws_t/verification/inherit")
             .with(body: { sourceWorkspaceId: 'ws_src' }.to_json)
             .to_return(json_ok({ 'verificationId' => 'ver_1', 'status' => 'approved' }))

      workspaces.inherit_verification('ws_t', source_workspace_id: 'ws_src')

      expect(stub).to have_been_requested
    end
  end

  describe '#provision_bulk' do
    it 'sends up to 100 workspaces, the API limit' do
      list = Array.new(100) { |i| { name: "Workspace #{i}" } }
      stub = stub_request(:post, "#{base_url}/enterprise/workspaces/provision/bulk")
             .with(body: { workspaces: list }.to_json)
             .to_return(json_ok({ 'results' => [] }))

      workspaces.provision_bulk(list)

      expect(stub).to have_been_requested
    end

    it 'refuses more than 100 workspaces before sending anything' do
      list = Array.new(101) { |i| { name: "Workspace #{i}" } }

      expect { workspaces.provision_bulk(list) }
        .to raise_error(ArgumentError, 'Maximum 100 workspaces per bulk provision')
      expect(a_request(:post, "#{base_url}/enterprise/workspaces/provision/bulk")).not_to have_been_made
    end
  end

  describe '#create_key' do
    it 'raises ArgumentError without a name, which the API requires' do
      expect { workspaces.create_key('ws_1') }.to raise_error(ArgumentError, /name is required/i)
      expect { workspaces.create_key('ws_1', name: '') }.to raise_error(ArgumentError, /name is required/i)
    end

    it 'sends a blank or Symbol name as before, since the API accepts any non-empty string' do
      created = lambda do |name|
        json_ok({ 'id' => 'key_1', 'name' => name, 'key' => 'sk_test_v1_x', 'keyPrefix' => 'sk_test_v1_x',
                  'type' => 'test', 'scopes' => ['sms:send'], 'createdAt' => '2026-09-25T10:00:00.000Z' },
                status: 201)
      end
      blank = stub_request(:post, "#{base_url}/enterprise/workspaces/ws_1/keys")
              .with(body: { name: '  ' }.to_json).to_return(created.call('  '))
      symbol = stub_request(:post, "#{base_url}/enterprise/workspaces/ws_1/keys")
               .with(body: { name: 'ci' }.to_json).to_return(created.call('ci'))

      expect(workspaces.create_key('ws_1', name: '  ')['name']).to eq('  ')
      expect(workspaces.create_key('ws_1', name: :ci)['name']).to eq('ci')
      expect(blank).to have_been_requested
      expect(symbol).to have_been_requested
    end

    it 'sends the scopes it is given' do
      stub = stub_request(:post, "#{base_url}/enterprise/workspaces/ws_1/keys")
             .with(body: { name: 'k', scopes: ['sms:send'] }.to_json)
             .to_return(json_ok({ 'id' => 'key_1', 'name' => 'k', 'key' => 'sk_test_v1_x', 'type' => 'test',
                                  'scopes' => ['sms:send'] }, status: 201))

      result = workspaces.create_key('ws_1', name: 'k', scopes: ['sms:send'])

      expect(stub).to have_been_requested
      expect(result['scopes']).to eq(['sms:send'])
    end

    it 'sends name and type as before' do
      stub = stub_request(:post, "#{base_url}/enterprise/workspaces/ws_1/keys")
             .with(body: { name: 'k', type: 'live' }.to_json)
             .to_return(json_ok({ 'id' => 'key_1', 'name' => 'k', 'type' => 'live' }, status: 201))

      workspaces.create_key('ws_1', name: 'k', type: 'live')

      expect(stub).to have_been_requested
    end
  end
end
