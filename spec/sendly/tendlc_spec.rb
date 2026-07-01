# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::TenDlcResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:ten_dlc) { client.ten_dlc }

  let(:brand_body) do
    {
      'id' => 'brd_1', 'legalName' => 'Acme Holdings LLC', 'dba' => 'Acme',
      'entityType' => 'PRIVATE_PROFIT', 'ein' => '12-3456789',
      'vertical' => 'TECHNOLOGY', 'website' => 'https://acme.example',
      'status' => 'pending', 'identityStatus' => nil, 'failureReasons' => nil,
      'createdAt' => '2026-06-30T10:00:00Z', 'updatedAt' => '2026-06-30T10:00:00Z'
    }
  end

  let(:campaign_body) do
    {
      'id' => 'cmp_1', 'brandId' => 'brd_1', 'useCase' => 'MIXED',
      'subUseCases' => %w[CUSTOMER_CARE], 'description' => 'Order updates',
      'status' => 'pending', 'sampleMessages' => ['Your order #123 has shipped!'],
      'throughput' => nil, 'failureReasons' => nil,
      'createdAt' => '2026-06-30T10:00:00Z', 'updatedAt' => '2026-06-30T10:00:00Z'
    }
  end

  let(:assignment_body) do
    {
      'id' => 'asg_1', 'campaignId' => 'cmp_1', 'phoneNumber' => '+15551234567',
      'status' => 'Under review', 'assignedAt' => nil
    }
  end

  describe '#list_brands' do
    it 'GETs /tendlc/brands and maps TenDlcBrand objects' do
      stub_request_with_auth(:get, '/tendlc/brands', response_body: { 'data' => [brand_body] })

      result = ten_dlc.list_brands

      expect(result[:brands].length).to eq(1)
      brand = result[:brands].first
      expect(brand).to be_a(Sendly::TenDlcBrand)
      expect(brand.id).to eq('brd_1')
      expect(brand.legal_name).to eq('Acme Holdings LLC')
      expect(brand.dba).to eq('Acme')
      expect(brand.entity_type).to eq('PRIVATE_PROFIT')
      expect(brand.ein).to eq('12-3456789')
      expect(brand.status).to eq('pending')
      expect(brand.pending?).to be true
      expect(brand.verified?).to be false
    end

    it 'returns an empty list when the API returns no brands' do
      stub_request_with_auth(:get, '/tendlc/brands', response_body: { 'data' => [] })
      expect(ten_dlc.list_brands[:brands]).to eq([])
    end
  end

  describe '#create_brand' do
    it 'POSTs camelCase body to /tendlc/brands and returns a TenDlcBrand' do
      stub = stub_request(:post, "#{base_url}/tendlc/brands")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: {
            legalName: 'Acme Holdings LLC',
            ein: '12-3456789',
            entityType: 'PRIVATE_PROFIT',
            website: 'https://acme.example',
            email: 'ops@acme.example'
          }.to_json
        )
        .to_return(status: 201, body: { 'data' => brand_body }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      brand = ten_dlc.create_brand(
        legal_name: 'Acme Holdings LLC',
        ein: '12-3456789',
        entity_type: 'PRIVATE_PROFIT',
        website: 'https://acme.example',
        email: 'ops@acme.example'
      )

      expect(stub).to have_been_requested
      expect(brand).to be_a(Sendly::TenDlcBrand)
      expect(brand.legal_name).to eq('Acme Holdings LLC')
      expect(brand.pending?).to be true
    end

    it 'omits optional fields that were not given' do
      stub = stub_request(:post, "#{base_url}/tendlc/brands")
        .with(body: { legalName: 'Acme Holdings LLC' }.to_json)
        .to_return(status: 201, body: { 'data' => brand_body }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      ten_dlc.create_brand(legal_name: 'Acme Holdings LLC')
      expect(stub).to have_been_requested
    end

    it 'raises ValidationError when legal_name is missing' do
      expect { ten_dlc.create_brand(legal_name: '') }
        .to raise_error(Sendly::ValidationError, /legal_name is required/)
    end
  end

  describe '#get_brand' do
    it 'GETs /tendlc/brands/:id and returns the refreshed brand' do
      stub_request_with_auth(:get, '/tendlc/brands/brd_1', response_body: {
        'data' => brand_body.merge('status' => 'verified')
      })

      brand = ten_dlc.get_brand('brd_1')

      expect(brand.status).to eq('verified')
      expect(brand.verified?).to be true
    end

    it 'exposes failure_reasons when the review failed' do
      stub_request_with_auth(:get, '/tendlc/brands/brd_1', response_body: {
        'data' => brand_body.merge('status' => 'failed', 'failureReasons' => ['Business name mismatch'])
      })

      brand = ten_dlc.get_brand('brd_1')

      expect(brand.failed?).to be true
      expect(brand.failure_reasons).to eq(['Business name mismatch'])
    end

    it 'raises ValidationError when id is missing' do
      expect { ten_dlc.get_brand(nil) }
        .to raise_error(Sendly::ValidationError, /Brand ID is required/)
    end
  end

  describe '#qualify' do
    it 'GETs /tendlc/brands/:id/qualify/:usecase and maps the result' do
      stub_request_with_auth(:get, '/tendlc/brands/brd_1/qualify/MIXED', response_body: {
        'data' => {
          'useCase' => 'MIXED', 'qualified' => true, 'reason' => nil,
          'throughput' => { 'tier' => 'Standard', 'carriersReady' => 3 }
        }
      })

      result = ten_dlc.qualify('brd_1', 'MIXED')

      expect(result).to be_a(Sendly::TenDlcQualifyResult)
      expect(result.use_case).to eq('MIXED')
      expect(result.qualified?).to be true
      expect(result.throughput).to be_a(Sendly::TenDlcThroughput)
      expect(result.throughput.tier).to eq('Standard')
      expect(result.throughput.carriers_ready).to eq(3)
    end

    it 'carries the reason when the use case does not qualify' do
      stub_request_with_auth(:get, '/tendlc/brands/brd_1/qualify/MARKETING', response_body: {
        'data' => { 'useCase' => 'MARKETING', 'qualified' => false,
                    'reason' => 'Brand not eligible for this use case', 'throughput' => nil }
      })

      result = ten_dlc.qualify('brd_1', 'MARKETING')

      expect(result.qualified?).to be false
      expect(result.reason).to eq('Brand not eligible for this use case')
      expect(result.throughput).to be_nil
    end

    it 'raises ValidationError when brand_id is missing' do
      expect { ten_dlc.qualify('', 'MIXED') }
        .to raise_error(Sendly::ValidationError, /Brand ID is required/)
    end

    it 'raises ValidationError when use_case is missing' do
      expect { ten_dlc.qualify('brd_1', nil) }
        .to raise_error(Sendly::ValidationError, /use_case is required/)
    end
  end

  describe '#list_campaigns' do
    it 'GETs /tendlc/campaigns and maps TenDlcCampaign objects' do
      stub_request_with_auth(:get, '/tendlc/campaigns', response_body: { 'data' => [campaign_body] })

      result = ten_dlc.list_campaigns

      campaign = result[:campaigns].first
      expect(campaign).to be_a(Sendly::TenDlcCampaign)
      expect(campaign.id).to eq('cmp_1')
      expect(campaign.brand_id).to eq('brd_1')
      expect(campaign.use_case).to eq('MIXED')
      expect(campaign.sub_use_cases).to eq(%w[CUSTOMER_CARE])
      expect(campaign.sample_messages).to eq(['Your order #123 has shipped!'])
      expect(campaign.pending?).to be true
    end

    it 'returns an empty list when the API returns no campaigns' do
      stub_request_with_auth(:get, '/tendlc/campaigns', response_body: { 'data' => [] })
      expect(ten_dlc.list_campaigns[:campaigns]).to eq([])
    end
  end

  describe '#create_campaign' do
    let(:campaign_args) do
      {
        brand_id: 'brd_1',
        use_case: 'MIXED',
        description: 'Order updates',
        message_flow: 'Customers opt in at checkout',
        sample_messages: ['Your order #123 has shipped!']
      }
    end

    it 'POSTs camelCase body to /tendlc/campaigns and returns a TenDlcCampaign' do
      stub = stub_request(:post, "#{base_url}/tendlc/campaigns")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: {
            brandId: 'brd_1',
            useCase: 'MIXED',
            description: 'Order updates',
            messageFlow: 'Customers opt in at checkout',
            sampleMessages: ['Your order #123 has shipped!']
          }.to_json
        )
        .to_return(status: 201, body: { 'data' => campaign_body }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      campaign = ten_dlc.create_campaign(**campaign_args)

      expect(stub).to have_been_requested
      expect(campaign).to be_a(Sendly::TenDlcCampaign)
      expect(campaign.pending?).to be true
    end

    it 'passes optional keyword and boolean fields through' do
      stub = stub_request(:post, "#{base_url}/tendlc/campaigns")
        .with(body: {
          brandId: 'brd_1',
          useCase: 'MIXED',
          description: 'Order updates',
          messageFlow: 'Customers opt in at checkout',
          sampleMessages: ['Your order #123 has shipped!'],
          optOutKeywords: 'STOP',
          embeddedLink: false
        }.to_json)
        .to_return(status: 201, body: { 'data' => campaign_body }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      ten_dlc.create_campaign(**campaign_args, opt_out_keywords: 'STOP', embedded_link: false)
      expect(stub).to have_been_requested
    end

    it 'raises ValidationError when brand_id is missing' do
      expect { ten_dlc.create_campaign(**campaign_args.merge(brand_id: nil)) }
        .to raise_error(Sendly::ValidationError, /brand_id is required/)
    end

    it 'raises ValidationError when sample_messages is empty' do
      expect { ten_dlc.create_campaign(**campaign_args.merge(sample_messages: [])) }
        .to raise_error(Sendly::ValidationError, /sample_messages is required/)
    end
  end

  describe '#get_campaign' do
    it 'GETs /tendlc/campaigns/:id and maps throughput once carriers approve' do
      stub_request_with_auth(:get, '/tendlc/campaigns/cmp_1', response_body: {
        'data' => campaign_body.merge(
          'status' => 'active',
          'throughput' => { 'tier' => 'High volume', 'carriersReady' => 4 }
        )
      })

      campaign = ten_dlc.get_campaign('cmp_1')

      expect(campaign.active?).to be true
      expect(campaign.throughput.tier).to eq('High volume')
      expect(campaign.throughput.carriers_ready).to eq(4)
    end

    it 'raises ValidationError when id is missing' do
      expect { ten_dlc.get_campaign('') }
        .to raise_error(Sendly::ValidationError, /Campaign ID is required/)
    end
  end

  describe '#assign_number' do
    it 'POSTs the number to /tendlc/campaigns/:id/assign and returns the assignment' do
      stub = stub_request(:post, "#{base_url}/tendlc/campaigns/cmp_1/assign")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: { phoneNumber: '+15551234567' }.to_json
        )
        .to_return(status: 201, body: { 'data' => assignment_body }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      assignment = ten_dlc.assign_number('cmp_1', phone_number: '+15551234567')

      expect(stub).to have_been_requested
      expect(assignment).to be_a(Sendly::TenDlcAssignment)
      expect(assignment.campaign_id).to eq('cmp_1')
      expect(assignment.phone_number).to eq('+15551234567')
      expect(assignment.status).to eq('Under review')
      expect(assignment.active?).to be false
      expect(assignment.assigned_at).to be_nil
    end

    it 'reports an Active assignment' do
      stub_request(:post, "#{base_url}/tendlc/campaigns/cmp_1/assign")
        .to_return(status: 201, body: {
          'data' => assignment_body.merge('status' => 'Active', 'assignedAt' => '2026-06-30T11:00:00Z')
        }.to_json, headers: { 'Content-Type' => 'application/json' })

      assignment = ten_dlc.assign_number('cmp_1', phone_number: '+15551234567')

      expect(assignment.active?).to be true
      expect(assignment.assigned_at).to eq('2026-06-30T11:00:00Z')
    end

    it 'raises ValidationError when campaign_id is missing' do
      expect { ten_dlc.assign_number(nil, phone_number: '+15551234567') }
        .to raise_error(Sendly::ValidationError, /Campaign ID is required/)
    end

    it 'raises ValidationError when phone_number is missing' do
      expect { ten_dlc.assign_number('cmp_1', phone_number: '') }
        .to raise_error(Sendly::ValidationError, /phone_number is required/)
    end
  end

  describe '#list_assignments' do
    it 'GETs /tendlc/assignments and maps TenDlcAssignment objects' do
      stub_request_with_auth(:get, '/tendlc/assignments', response_body: { 'data' => [assignment_body] })

      result = ten_dlc.list_assignments

      assignment = result[:assignments].first
      expect(assignment).to be_a(Sendly::TenDlcAssignment)
      expect(assignment.id).to eq('asg_1')
      expect(assignment.phone_number).to eq('+15551234567')
    end

    it 'returns an empty list when the API returns no assignments' do
      stub_request_with_auth(:get, '/tendlc/assignments', response_body: { 'data' => [] })
      expect(ten_dlc.list_assignments[:assignments]).to eq([])
    end
  end

  describe 'error mapping' do
    it 'raises NotFoundError when a brand does not exist in this workspace' do
      stub_request_with_auth(:get, '/tendlc/brands/brd_missing',
                             status: 404, response_body: { 'error' => 'not_found' })

      expect { ten_dlc.get_brand('brd_missing') }
        .to raise_error(Sendly::NotFoundError)
    end
  end

  describe 'client accessor' do
    it 'memoizes the ten_dlc resource' do
      expect(client.ten_dlc).to be_a(Sendly::TenDlcResource)
      expect(client.ten_dlc).to equal(client.ten_dlc)
    end
  end
end
