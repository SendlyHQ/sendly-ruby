# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::NumbersResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:numbers) { client.numbers }

  describe '#list_countries' do
    it 'GETs /numbers/countries and maps NumberCountry objects' do
      stub_request_with_auth(:get, '/numbers/countries', response_body: {
        'countries' => [
          { 'code' => 'GB', 'name' => 'United Kingdom', 'numberTypes' => %w[mobile local] },
          { 'code' => 'US', 'name' => 'United States', 'numberTypes' => %w[local toll_free] }
        ]
      })

      result = numbers.list_countries

      expect(result[:countries].length).to eq(2)
      gb = result[:countries].first
      expect(gb).to be_a(Sendly::NumberCountry)
      expect(gb.code).to eq('GB')
      expect(gb.name).to eq('United Kingdom')
      expect(gb.number_types).to eq(%w[mobile local])
    end

    it 'returns an empty list when the API returns no countries' do
      stub_request_with_auth(:get, '/numbers/countries', response_body: {})
      expect(numbers.list_countries[:countries]).to eq([])
    end
  end

  describe '#list_available' do
    it 'GETs /numbers/available with country and type and maps AvailableNumber' do
      stub = stub_request(:get, "#{base_url}/numbers/available")
        .with(query: { 'country' => 'GB', 'type' => 'mobile' },
              headers: { 'Authorization' => "Bearer #{valid_api_key}" })
        .to_return(status: 200, body: {
          'numbers' => [
            { 'phoneNumber' => '+447400000001', 'country' => 'GB',
              'numberType' => 'mobile', 'monthlyCost' => '3.00', 'currency' => 'USD' }
          ]
        }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = numbers.list_available(country: 'GB', type: 'mobile')

      expect(stub).to have_been_requested
      number = result[:numbers].first
      expect(number).to be_a(Sendly::AvailableNumber)
      expect(number.phone_number).to eq('+447400000001')
      expect(number.country).to eq('GB')
      expect(number.number_type).to eq('mobile')
      expect(number.monthly_cost).to eq('3.00')
      expect(number.currency).to eq('USD')
    end

    it 'passes the optional contains filter through' do
      stub = stub_request(:get, "#{base_url}/numbers/available")
        .with(query: { 'country' => 'GB', 'type' => 'mobile', 'contains' => '777' })
        .to_return(status: 200, body: { 'numbers' => [] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      numbers.list_available(country: 'GB', type: 'mobile', contains: '777')
      expect(stub).to have_been_requested
    end

    it 'raises ValidationError when country is missing' do
      expect { numbers.list_available(country: '', type: 'mobile') }
        .to raise_error(Sendly::ValidationError, /country is required/)
    end

    it 'raises ValidationError when type is missing' do
      expect { numbers.list_available(country: 'GB', type: nil) }
        .to raise_error(Sendly::ValidationError, /type is required/)
    end
  end

  describe '#list' do
    it 'GETs /numbers and maps PhoneNumber objects' do
      stub_request_with_auth(:get, '/numbers', response_body: {
        'numbers' => [
          { 'id' => 'num_1', 'phoneNumber' => '+447400000001', 'status' => 'active',
            'source' => 'purchased', 'countryCode' => 'GB',
            'phoneNumberType' => 'mobile', 'monthlyCostCents' => 300 }
        ]
      })

      result = numbers.list
      number = result[:numbers].first
      expect(number).to be_a(Sendly::PhoneNumber)
      expect(number.id).to eq('num_1')
      expect(number.phone_number).to eq('+447400000001')
      expect(number.status).to eq('active')
      expect(number.source).to eq('purchased')
      expect(number.country_code).to eq('GB')
      expect(number.phone_number_type).to eq('mobile')
      expect(number.monthly_cost_cents).to eq(300)
    end
  end

  describe '#buy' do
    let(:buy_args) do
      {
        phone_number: '+447400000001',
        country_code: 'GB',
        phone_number_type: 'mobile',
        monthly_cost: '3.00'
      }
    end

    it 'POSTs camelCase body to /numbers/buy and returns a provisioning NumberPurchase' do
      stub = stub_request(:post, "#{base_url}/numbers/buy")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: {
            phoneNumber: '+447400000001',
            countryCode: 'GB',
            phoneNumberType: 'mobile',
            monthlyCost: '3.00'
          }.to_json
        )
        .to_return(status: 202, body: {
          'status' => 'provisioning',
          'number' => { 'id' => 'num_1', 'phoneNumber' => '+447400000001',
                        'status' => 'provisioning', 'countryCode' => 'GB',
                        'phoneNumberType' => 'mobile', 'monthlyCostCents' => 300 }
        }.to_json, headers: { 'Content-Type' => 'application/json' })

      purchase = numbers.buy(**buy_args)

      expect(stub).to have_been_requested
      expect(purchase).to be_a(Sendly::NumberPurchase)
      expect(purchase.provisioning?).to be true
      expect(purchase.number).to be_a(Sendly::PhoneNumber)
      expect(purchase.number.id).to eq('num_1')
      expect(purchase.action).to be_nil
    end

    it 'exposes the hosted action hand-off on documents_required' do
      stub_request(:post, "#{base_url}/numbers/buy")
        .to_return(status: 202, body: {
          'status' => 'documents_required',
          'requirements' => [{ 'field' => 'identity_document' }],
          'action' => {
            'actionCode' => '0123456789abcdef0123456789abcdef',
            'url' => 'https://sendly.live/action/abc123',
            'code' => 'ABC23XYZ',
            'expiresAt' => 1_780_000_000_000
          }
        }.to_json, headers: { 'Content-Type' => 'application/json' })

      purchase = numbers.buy(**buy_args)

      expect(purchase.documents_required?).to be true
      expect(purchase.action_url).to eq('https://sendly.live/action/abc123')
      # 32-hex identifier for polling + re-buy
      expect(purchase.action_identifier).to eq('0123456789abcdef0123456789abcdef')
      # short user code shown to the human (display only)
      expect(purchase.action_code).to eq('ABC23XYZ')
      # epoch-ms number, not an ISO string
      expect(purchase.action_expires_at).to eq(1_780_000_000_000)
      expect(purchase.requirements).to eq([{ 'field' => 'identity_document' }])
      expect(purchase.raw['status']).to eq('documents_required')
    end

    it 're-buys with the 32-hex action_identifier, not the display code' do
      stub_request(:post, "#{base_url}/numbers/buy")
        .to_return(status: 202, body: {
          'status' => 'documents_required',
          'action' => {
            'actionCode' => '0123456789abcdef0123456789abcdef',
            'url' => 'https://sendly.live/action/abc123',
            'code' => 'ABC23XYZ',
            'expiresAt' => 1_780_000_000_000
          }
        }.to_json, headers: { 'Content-Type' => 'application/json' })

      purchase = numbers.buy(**buy_args)

      rebuy = stub_request(:post, "#{base_url}/numbers/buy")
        .with(body: {
          phoneNumber: '+447400000001',
          countryCode: 'GB',
          phoneNumberType: 'mobile',
          monthlyCost: '3.00',
          actionCode: '0123456789abcdef0123456789abcdef'
        }.to_json)
        .to_return(status: 202, body: { 'status' => 'provisioning' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      numbers.buy(**buy_args, action_code: purchase.action_identifier)
      expect(rebuy).to have_been_requested
    end

    it 'reports payment_required' do
      stub_request(:post, "#{base_url}/numbers/buy")
        .to_return(status: 202, body: {
          'status' => 'payment_required',
          'action' => { 'url' => 'https://sendly.live/pay/x', 'code' => 'PAY-9' }
        }.to_json, headers: { 'Content-Type' => 'application/json' })

      purchase = numbers.buy(**buy_args)
      expect(purchase.payment_required?).to be true
      expect(purchase.action_url).to eq('https://sendly.live/pay/x')
    end

    it 'includes actionCode in the body when re-calling buy' do
      stub = stub_request(:post, "#{base_url}/numbers/buy")
        .with(body: {
          phoneNumber: '+447400000001',
          countryCode: 'GB',
          phoneNumberType: 'mobile',
          monthlyCost: '3.00',
          actionCode: 'ABC-123'
        }.to_json)
        .to_return(status: 202, body: { 'status' => 'provisioning' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      numbers.buy(**buy_args, action_code: 'ABC-123')
      expect(stub).to have_been_requested
    end

    it 'raises ValidationError when phone_number is missing' do
      expect { numbers.buy(**buy_args.merge(phone_number: nil)) }
        .to raise_error(Sendly::ValidationError, /phone_number is required/)
    end

    it 'raises ValidationError when monthly_cost is missing' do
      expect { numbers.buy(**buy_args.merge(monthly_cost: '')) }
        .to raise_error(Sendly::ValidationError, /monthly_cost is required/)
    end
  end

  describe 'client accessor' do
    it 'memoizes the numbers resource' do
      expect(client.numbers).to be_a(Sendly::NumbersResource)
      expect(client.numbers).to equal(client.numbers)
    end
  end
end
