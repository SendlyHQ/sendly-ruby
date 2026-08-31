# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::AccountResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:account) { client.account }

  def api_key_response(overrides = {})
    {
      'id' => 'key_abc123',
      'name' => 'Production',
      'type' => 'live',
      'prefix' => 'sk_live_v1_a...',
      'scopes' => ['sms:send'],
      'isActive' => true,
      'createdAt' => '2026-01-15T10:00:00Z'
    }.merge(overrides)
  end

  describe '#api_keys' do
    it 'lists keys from /account/keys and unwraps the keys envelope' do
      stub_request_with_auth(:get, '/account/keys',
                             response_body: { 'keys' => [api_key_response] })

      keys = account.api_keys

      expect(keys.length).to eq(1)
      expect(keys.first).to be_a(Sendly::ApiKey)
      expect(keys.first.id).to eq('key_abc123')
      expect(keys.first.live?).to be true
    end

    it 'handles an empty collection' do
      stub_request_with_auth(:get, '/account/keys', response_body: { 'keys' => [] })

      expect(account.api_keys).to eq([])
    end
  end

  describe '#api_key' do
    it 'fetches a single key from /account/keys/:id' do
      stub_request_with_auth(:get, '/account/keys/key_abc123', response_body: api_key_response)

      key = account.api_key('key_abc123')

      expect(key).to be_a(Sendly::ApiKey)
      expect(key.name).to eq('Production')
    end
  end

  describe '#api_key_usage' do
    it 'fetches usage from /account/keys/:id/usage' do
      stub_request_with_auth(:get, '/account/keys/key_abc123/usage',
                             response_body: {
                               'keyId' => 'key_abc123',
                               'summary' => { 'totalRequests' => 12, 'totalCredits' => 4 }
                             })

      usage = account.api_key_usage('key_abc123')

      expect(usage['keyId']).to eq('key_abc123')
      expect(usage.dig('summary', 'totalRequests')).to eq(12)
    end
  end

  describe '#revoke_api_key' do
    it 'patches /account/keys/:id/revoke' do
      stub = stub_request(:patch, "#{base_url}/account/keys/key_abc123/revoke")
        .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" }, body: {}.to_json)
        .to_return(status: 200,
                   body: { 'id' => 'key_abc123', 'name' => 'Production', 'revoked' => true,
                           'revokedAt' => '2026-01-16T10:00:00Z' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = account.revoke_api_key('key_abc123')

      expect(stub).to have_been_requested
      expect(result['revoked']).to be true
    end

    it 'sends a reason when supplied' do
      stub = stub_request(:patch, "#{base_url}/account/keys/key_abc123/revoke")
        .with(body: { reason: 'rotated' }.to_json)
        .to_return(status: 200, body: { 'revoked' => true }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      account.revoke_api_key('key_abc123', reason: 'rotated')

      expect(stub).to have_been_requested
    end

    it 'requires a key id' do
      expect { account.revoke_api_key('') }.to raise_error(ArgumentError)
    end
  end

  describe '#transactions' do
    it 'unwraps the transactions envelope from /credits/transactions' do
      stub_request_with_auth(:get, '/credits/transactions',
                             response_body: {
                               'transactions' => [
                                 { 'id' => 'ctx_1', 'amount' => -2, 'balance_after' => 98,
                                   'type' => 'usage', 'description' => 'SMS',
                                   'created_at' => '2026-01-15T10:00:00Z' }
                               ]
                             })

      txs = account.transactions

      expect(txs.length).to eq(1)
      expect(txs.first).to be_a(Sendly::CreditTransaction)
      expect(txs.first.debit?).to be true
      expect(txs.first.balance_after).to eq(98)
    end

    it 'returns an empty array when the account has no history' do
      stub_request_with_auth(:get, '/credits/transactions',
                             response_body: { 'transactions' => [] })

      expect(account.transactions).to eq([])
    end
  end
end
