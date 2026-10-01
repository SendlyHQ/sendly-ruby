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

  describe '#get' do
    let(:account_body) do
      {
        'user' => { 'id' => 'user_1', 'email' => 'a@example.com', 'createdAt' => '2026-01-15T10:00:00.000Z' },
        'organization' => { 'id' => 'org_1', 'name' => 'Acme', 'isPersonal' => false },
        'credits' => { 'balance' => 500, 'reservedBalance' => 10 },
        'verification' => {
          'status' => 'approved', 'type' => 'toll_free', 'region' => 'us',
          'submittedAt' => '2026-01-16T10:00:00.000Z', 'updatedAt' => '2026-01-17T10:00:00.000Z'
        },
        'apiKey' => {
          'id' => 'key_1', 'name' => 'CI', 'type' => 'test', 'scopes' => ['sms:send'],
          'createdAt' => '2026-01-15T10:00:00.000Z', 'lastUsedAt' => nil
        },
        'limits' => { 'messagesPerMinute' => 60, 'messagesPerDay' => 100 }
      }
    end

    it 'reads the user, workspace and key the API nests in the response' do
      stub_request_with_auth(:get, '/account', response_body: account_body)

      result = account.get

      expect(result.id).to eq('user_1')
      expect(result.email).to eq('a@example.com')
      expect(result.created_at).to eq(Time.parse('2026-01-15T10:00:00.000Z'))
      expect(result.name).to eq('Acme')
      expect(result.organization_id).to eq('org_1')
      expect(result.organization).to eq(account_body['organization'])
      expect(result.credits).to eq(account_body['credits'])
      expect(result.verification).to eq(account_body['verification'])
      expect(result.api_key).to eq(account_body['apiKey'])
      expect(result.limits).to eq(account_body['limits'])
      expect(result.raw).to eq(account_body)
    end

    it 'has no workspace for a key that is not bound to one' do
      stub_request_with_auth(:get, '/account', response_body: account_body.merge('organization' => nil))

      result = account.get

      expect(result.id).to eq('user_1')
      expect(result.organization).to be_nil
      expect(result.organization_id).to be_nil
      expect(result.name).to be_nil
    end
  end

  describe '#create_api_key' do
    def created_key_body(type)
      {
        'id' => 'key_new', 'name' => 'CI', 'key' => "sk_#{type}_v1_secret", 'keyPrefix' => "sk_#{type}_v1_se",
        'type' => type, 'createdAt' => '2026-09-25T10:00:00.000Z', 'expiresAt' => nil,
        'apiKey' => { 'id' => 'key_new', 'name' => 'CI', 'type' => type, 'scopes' => ['sms:send'] }
      }
    end

    it 'sends type test by default' do
      stub = stub_request(:post, "#{base_url}/account/keys")
             .with(body: { name: 'CI', type: 'test' }.to_json)
             .to_return(status: 200, body: created_key_body('test').to_json,
                        headers: { 'Content-Type' => 'application/json' })

      result = account.create_api_key('CI')

      expect(stub).to have_been_requested
      expect(result['key']).to eq('sk_test_v1_secret')
      expect(result.dig('apiKey', 'id')).to eq('key_new')
    end

    it 'creates a live key with the scopes it is given' do
      stub = stub_request(:post, "#{base_url}/account/keys")
             .with(body: hash_including(name: 'Prod', type: 'live', scopes: ['sms:send']))
             .to_return(status: 200, body: created_key_body('live').to_json,
                        headers: { 'Content-Type' => 'application/json' })

      account.create_api_key('Prod', type: 'live', scopes: ['sms:send'])

      expect(stub).to have_been_requested
    end

    it 'sends expiresAt when given' do
      stub = stub_request(:post, "#{base_url}/account/keys")
             .with(body: { name: 'CI', type: 'test', expiresAt: '2027-01-01T00:00:00Z' }.to_json)
             .to_return(status: 200, body: created_key_body('test').to_json,
                        headers: { 'Content-Type' => 'application/json' })

      account.create_api_key('CI', expires_at: '2027-01-01T00:00:00Z')

      expect(stub).to have_been_requested
    end

    it 'rejects a type other than test or live before sending' do
      expect { account.create_api_key('CI', type: 'prod') }.to raise_error(ArgumentError, /test.*live/)
    end
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

    it 'reads the scopes and revocation the single-key response sends' do
      stub_request_with_auth(:get, '/account/keys/key_1',
                             response_body: {
                               'id' => 'key_1', 'name' => 'Old', 'type' => 'live',
                               'prefix' => 'sk_live_v1_ab...', 'scopes' => ['sms:send'],
                               'isActive' => false, 'createdAt' => '2026-01-15T10:00:00.000Z',
                               'lastUsedAt' => nil, 'expiresAt' => nil,
                               'revokedAt' => '2026-09-25T10:00:00.000Z'
                             })

      key = account.api_key('key_1')

      expect(key.permissions).to eq(['sms:send'])
      expect(key.scopes).to eq(['sms:send'])
      expect(key.is_active).to be false
      expect(key.revoked?).to be true
      expect(key.revoked_at).to eq(Time.parse('2026-09-25T10:00:00.000Z'))
    end

    it 'reports an active key as not revoked' do
      stub_request_with_auth(:get, '/account/keys/key_abc123', response_body: api_key_response)

      key = account.api_key('key_abc123')

      expect(key.revoked?).to be false
      expect(key.is_active).to be true
      expect(key.revoked_at).to be_nil
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

  describe '#credits' do
    it 'reads the reserved and available balances the API sends' do
      stub_request_with_auth(:get, '/credits',
                             response_body: { 'balance' => 100, 'reservedBalance' => 10,
                                              'availableBalance' => 90, 'billingMode' => 'prepaid' })

      credits = account.credits

      expect(credits.balance).to eq(100)
      expect(credits.reserved_balance).to eq(10)
      expect(credits.available_balance).to eq(90)
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

    it 'lists every transaction type the ledger records' do
      expect(Sendly::CreditTransaction::TYPES)
        .to include('purchase', 'usage', 'refund', 'bonus', 'transfer', 'admin_grant', 'admin_seed')
    end

    it 'keeps a transfer as the API sends it' do
      stub_request_with_auth(:get, '/credits/transactions',
                             response_body: {
                               'transactions' => [
                                 { 'id' => 'ctx_2', 'amount' => -500, 'balance_after' => 1500,
                                   'type' => 'transfer', 'description' => nil,
                                   'created_at' => '2026-09-25T10:00:00Z' }
                               ]
                             })

      tx = account.transactions.first

      expect(tx.type).to eq('transfer')
      expect(Sendly::CreditTransaction::TYPES).to include(tx.type)
      expect(tx.description).to be_nil
    end
  end
end
