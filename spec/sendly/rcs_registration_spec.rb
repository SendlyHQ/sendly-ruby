# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RCS registration' do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:rcs) { client.rcs }

  let(:auto_key_pattern) do
    /\Asendly-ruby-retry-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  end

  let(:brand_body) do
    {
      'id' => 'rcb_1', 'reviewStatus' => 'draft', 'customerStage' => 'draft',
      'displayName' => 'Acme Coffee', 'legalName' => 'Acme Holdings LLC',
      'legalEntityType' => 'LIMITED_LIABILITY_COMPANY', 'organizationType' => 'PRIVATE_PROFIT',
      'stockSymbol' => nil, 'websiteUrl' => 'https://acme.example', 'ein' => '12-3456789',
      'address' => { 'line1' => '1 Main St', 'line2' => nil, 'city' => 'Austin', 'state' => 'TX',
                     'postalCode' => '78701', 'countryCode' => 'US' },
      'contact' => { 'firstName' => 'Sam', 'lastName' => 'Lee', 'title' => nil,
                     'email' => 'sam@acme.example', 'phoneNumber' => '+15551234567' },
      'reviewNote' => nil, 'rejectionReason' => nil, 'submittedForReviewAt' => nil,
      'sentToCarrierAt' => nil, 'verifiedAt' => nil,
      'createdAt' => '2026-09-01T10:00:00Z', 'updatedAt' => '2026-09-01T10:00:00Z'
    }
  end

  let(:device_body) do
    {
      'id' => 'rcd_1', 'phoneNumber' => '+15557654321', 'label' => "Sam's Pixel",
      'inviteStatus' => 'PENDING', 'createdAt' => '2026-09-01T10:05:00Z'
    }
  end

  let(:agent_body) do
    {
      'id' => 'rca_1', 'brandId' => 'rcb_1', 'status' => 'draft', 'reviewStatus' => 'draft',
      'customerStage' => 'draft', 'displayName' => 'Acme Coffee', 'useCase' => 'MULTI_USE',
      'hostingRegion' => 'NORTH_AMERICA',
      'basics' => {
        'displayName' => 'Acme Coffee', 'useCase' => 'MULTI_USE', 'hostingRegion' => 'NORTH_AMERICA',
        'description' => 'Order updates from Acme Coffee',
        'logoUrl' => 'https://acme.example/rcs/logo.png',
        'heroUrl' => 'https://acme.example/rcs/hero.png',
        'brandColor' => '#5B3A29',
        'privacyPolicyUrl' => 'https://acme.example/privacy',
        'termsAndConditionsUrl' => 'https://acme.example/terms',
        'phoneNumber' => { 'number' => '+15551234567', 'label' => 'Support' }
      },
      'campaign' => {
        'companyOverview' => 'Coffee roaster', 'agentOverview' => 'Order updates',
        'additionalInformation' => nil,
        'interactions' => [{ 'interactionType' => 'TRANSACTIONAL_UPDATES', 'description' => 'Order status' }],
        'messageExamples' => ['Your order has shipped!'],
        'consentSettings' => {
          'optInMethods' => [{ 'methodType' => 'WEBSITE', 'description' => 'Checkout opt-in' }],
          'callToAction' => 'Get order updates',
          'callToActionUrl' => 'https://acme.example/optin',
          'doubleOptIn' => false,
          'helpResponse' => 'Reply HELP for help',
          'optOutResponse' => 'You are opted out'
        }
      },
      'testing' => { 'testUrl' => 'https://acme.example/rcs-test', 'messageId' => nil,
                     'additionalInformation' => nil },
      'reviewNote' => nil, 'rejectionReason' => nil, 'testDevices' => [device_body],
      'submittedForReviewAt' => nil, 'basicsSubmittedAt' => nil, 'launchSubmittedAt' => nil,
      'liveAt' => nil, 'createdAt' => '2026-09-01T10:00:00Z', 'updatedAt' => '2026-09-01T10:00:00Z'
    }
  end

  let(:dark_body) do
    { 'error' => 'rcs_not_enabled', 'message' => "RCS registration isn't enabled for this account yet." }
  end

  def json(status, body)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  it 'exposes the registration sub-resources on client.rcs' do
    expect(rcs.registration).to be_a(Sendly::RcsRegistrationResource)
    expect(rcs.dossier).to be_a(Sendly::RcsDossierResource)
    expect(rcs.brands).to be_a(Sendly::RcsBrandsResource)
    expect(rcs.agents).to be_a(Sendly::RcsAgentsResource)
  end

  it 'publishes the stage, review status and error code vocabularies' do
    expect(Sendly::RcsRegistration::CUSTOMER_STAGES).to include('draft', 'testing', 'live')
    expect(Sendly::RcsRegistration::REVIEW_STATUSES).to include('awaiting_review', 'launch_requested')
    expect(Sendly::RcsRegistration::ERROR_CODES).to include('rcs_not_enabled', 'rcs_field_locked')
    expect(Sendly::RcsBrand::LEGAL_ENTITY_TYPES).to include('LIMITED_LIABILITY_COMPANY')
    expect(Sendly::RcsAgentRegistration::USE_CASES).to eq(%w[MULTI_USE PROMOTIONAL TRANSACTIONAL OTP])
  end

  describe 'registration.get' do
    it 'GETs /rcs/registration and maps brand, agent, devices and stage' do
      stub_request_with_auth(:get, '/rcs/registration', response_body: {
        'brand' => brand_body, 'agent' => agent_body, 'devices' => [device_body],
        'stage' => 'draft', 'usEligible' => true
      })

      reg = rcs.registration.get

      expect(reg).to be_a(Sendly::RcsRegistration)
      expect(reg.brand).to be_a(Sendly::RcsBrand)
      expect(reg.brand.legal_name).to eq('Acme Holdings LLC')
      expect(reg.brand.address).to be_a(Sendly::RcsAddress)
      expect(reg.brand.address.postal_code).to eq('78701')
      expect(reg.brand.contact).to be_a(Sendly::RcsContact)
      expect(reg.brand.contact.first_name).to eq('Sam')
      expect(reg.agent).to be_a(Sendly::RcsAgentRegistration)
      expect(reg.agent.id).to eq('rca_1')
      expect(reg.devices.first).to be_a(Sendly::RcsTestDevice)
      expect(reg.devices.first.phone_number).to eq('+15557654321')
      expect(reg.stage).to eq('draft')
      expect(reg.us_eligible?).to be true
      expect(reg.live?).to be false
      expect(reg.to_h[:brand][:ein]).to eq('12-3456789')
    end

    it 'reads as an empty draft before anything exists' do
      stub_request_with_auth(:get, '/rcs/registration', response_body: {
        'brand' => nil, 'agent' => nil, 'devices' => [], 'stage' => 'draft', 'usEligible' => true
      })

      reg = rcs.registration.get

      expect(reg.brand).to be_nil
      expect(reg.agent).to be_nil
      expect(reg.devices).to eq([])
      expect(reg.stage).to eq('draft')
    end
  end

  describe 'dossier.get' do
    let(:dossier_response) do
      {
        'brand' => {
          'legalName' => 'Acme Holdings LLC', 'ein' => '12-3456789',
          'organizationType' => 'PRIVATE_PROFIT', 'websiteUrl' => 'https://acme.example',
          'address' => { 'line1' => '1 Main St', 'city' => 'Austin', 'state' => 'TX',
                         'postalCode' => '78701', 'countryCode' => 'US' },
          'contact' => { 'firstName' => 'Sam', 'lastName' => 'Lee',
                         'email' => 'sam@acme.example', 'phoneNumber' => '+15551234567' }
        },
        'usEligible' => true, 'source' => 'tendlc'
      }
    end

    it 'GETs /rcs/dossier and snake-cases the prefilled brand' do
      stub_request_with_auth(:get, '/rcs/dossier', response_body: dossier_response)

      dossier = rcs.dossier.get

      expect(dossier).to be_a(Sendly::RcsDossier)
      expect(dossier.source).to eq('tendlc')
      expect(dossier.us_eligible?).to be true
      expect(dossier.prefilled?).to be true
      expect(dossier.brand[:legal_name]).to eq('Acme Holdings LLC')
      expect(dossier.brand[:organization_type]).to eq('PRIVATE_PROFIT')
      expect(dossier.brand[:address][:postal_code]).to eq('78701')
      expect(dossier.brand[:address][:line1]).to eq('1 Main St')
      expect(dossier.brand[:contact][:first_name]).to eq('Sam')
    end

    it 'feeds brands.create directly' do
      stub_request_with_auth(:get, '/rcs/dossier', response_body: dossier_response)
      stub = stub_request(:post, "#{base_url}/rcs/brands")
        .with(body: {
          legalName: 'Acme Holdings LLC',
          organizationType: 'PRIVATE_PROFIT',
          websiteUrl: 'https://acme.example',
          ein: '12-3456789',
          address: { line1: '1 Main St', city: 'Austin', state: 'TX', postalCode: '78701', countryCode: 'US' },
          contact: { firstName: 'Sam', lastName: 'Lee', email: 'sam@acme.example', phoneNumber: '+15551234567' }
        }.to_json)
        .to_return(json(201, 'brand' => brand_body))

      brand = rcs.brands.create(**rcs.dossier.get.brand)

      expect(stub).to have_been_requested
      expect(brand.id).to eq('rcb_1')
    end

    it 'is empty when nothing is on file' do
      stub_request_with_auth(:get, '/rcs/dossier',
                             response_body: { 'brand' => {}, 'usEligible' => true, 'source' => 'none' })

      dossier = rcs.dossier.get

      expect(dossier.prefilled?).to be false
      expect(dossier.brand).to eq({})
      expect(dossier.source).to eq('none')
    end
  end

  describe 'brands.create' do
    it 'POSTs a camelCase body with nested address and contact and returns an RcsBrand' do
      stub = stub_request(:post, "#{base_url}/rcs/brands")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: {
            displayName: 'Acme Coffee',
            legalName: 'Acme Holdings LLC',
            legalEntityType: 'LIMITED_LIABILITY_COMPANY',
            organizationType: 'PRIVATE_PROFIT',
            websiteUrl: 'https://acme.example',
            ein: '12-3456789',
            address: { line1: '1 Main St', city: 'Austin', state: 'TX', postalCode: '78701', countryCode: 'US' },
            contact: { firstName: 'Sam', lastName: 'Lee', email: 'sam@acme.example', phoneNumber: '+15551234567' }
          }.to_json
        )
        .to_return(json(201, 'brand' => brand_body))

      brand = rcs.brands.create(
        display_name: 'Acme Coffee',
        legal_name: 'Acme Holdings LLC',
        legal_entity_type: 'LIMITED_LIABILITY_COMPANY',
        organization_type: 'PRIVATE_PROFIT',
        website_url: 'https://acme.example',
        ein: '12-3456789',
        address: { line1: '1 Main St', city: 'Austin', state: 'TX', postal_code: '78701', country_code: 'US' },
        contact: { first_name: 'Sam', last_name: 'Lee', email: 'sam@acme.example', phone_number: '+15551234567' }
      )

      expect(stub).to have_been_requested
      expect(brand).to be_a(Sendly::RcsBrand)
      expect(brand.id).to eq('rcb_1')
      expect(brand.review_status).to eq('draft')
      expect(brand.customer_stage).to eq('draft')
      expect(brand.draft?).to be true
      expect(brand.editable?).to be true
      expect(brand.verified?).to be false
      expect(brand.legal_entity_type).to eq('LIMITED_LIABILITY_COMPANY')
      expect(brand.address.country_code).to eq('US')
      expect(brand.contact.email).to eq('sam@acme.example')
      expect(brand.stock_symbol).to be_nil
      expect(brand.to_h[:address]).to eq(line1: '1 Main St', city: 'Austin', state: 'TX',
                                         postal_code: '78701', country_code: 'US')
    end

    it 'attaches an auto-generated Idempotency-Key and sends a caller key verbatim' do
      keys = []
      stub_request(:post, "#{base_url}/rcs/brands")
        .with { |req| keys << req.headers['Idempotency-Key'] }
        .to_return(json(201, 'brand' => brand_body), json(201, 'brand' => brand_body))

      rcs.brands.create(display_name: 'Acme Coffee')
      rcs.brands.create(display_name: 'Acme Coffee', idempotency_key: 'brand-acme-1')

      expect(keys[0]).to match(auto_key_pattern)
      expect(keys[1]).to eq('brand-acme-1')
    end

    it 'passes camelCase keys in nested hashes through unchanged' do
      stub = stub_request(:post, "#{base_url}/rcs/brands")
        .with(body: { address: { line1: '1 Main St', postalCode: '78701', countryCode: 'US' } }.to_json)
        .to_return(json(201, 'brand' => brand_body))

      rcs.brands.create(address: { line1: '1 Main St', postalCode: '78701', countryCode: 'US' })

      expect(stub).to have_been_requested
    end

    it 'raises ValidationError on 422 rcs_us_only' do
      stub_request(:post, "#{base_url}/rcs/brands")
        .to_return(json(422, 'error' => 'rcs_us_only',
                             'message' => 'RCS registration is available to US businesses for now.'))

      expect { rcs.brands.create(address: { country_code: 'GB' }) }
        .to raise_error(Sendly::ValidationError, /US businesses/)
    end
  end

  describe 'brands.update' do
    it 'PATCHes only the fields given, sending nil as null to clear, with the caller key' do
      stub = stub_request(:patch, "#{base_url}/rcs/brands/rcb_1")
        .with(
          headers: { 'Idempotency-Key' => 'brand-fix-1' },
          body: { websiteUrl: 'https://acme.example', stockSymbol: nil, address: { line2: 'Suite 4' } }.to_json
        )
        .to_return(json(200, 'brand' => brand_body.merge(
          'address' => brand_body['address'].merge('line2' => 'Suite 4')
        )))

      brand = rcs.brands.update('rcb_1', website_url: 'https://acme.example', stock_symbol: nil,
                                         address: { line2: 'Suite 4' }, idempotency_key: 'brand-fix-1')

      expect(stub).to have_been_requested
      expect(brand).to be_a(Sendly::RcsBrand)
      expect(brand.address.line2).to eq('Suite 4')
    end

    it 'sends no Idempotency-Key on PATCH unless one is given' do
      keys = []
      stub_request(:patch, "#{base_url}/rcs/brands/rcb_1")
        .with { |req| keys << req.headers['Idempotency-Key'] }
        .to_return(json(200, 'brand' => brand_body))

      rcs.brands.update('rcb_1', ein: '12-3456789')

      expect(keys.first).to be_nil
    end

    it 'raises ValidationError when nothing is given' do
      expect { rcs.brands.update('rcb_1') }
        .to raise_error(Sendly::ValidationError, /at least one brand field/)
    end

    it 'raises ValidationError when id is missing' do
      expect { rcs.brands.update('', ein: '12-3456789') }
        .to raise_error(Sendly::ValidationError, /Brand ID is required/)
    end

    it 'raises NotFoundError on 404 rcs_not_found' do
      stub_request(:patch, "#{base_url}/rcs/brands/rcb_missing")
        .to_return(json(404, 'error' => 'rcs_not_found', 'message' => 'Brand not found'))

      expect { rcs.brands.update('rcb_missing', ein: '12-3456789') }
        .to raise_error(Sendly::NotFoundError, /Brand not found/)
    end

    it 'raises APIError with status 409 on rcs_field_locked' do
      stub_request(:patch, "#{base_url}/rcs/brands/rcb_1")
        .to_return(json(409, 'error' => 'rcs_field_locked',
                             'message' => 'This registration is being reviewed; we will email you if changes are needed.'))

      expect { rcs.brands.update('rcb_1', ein: '12-3456789') }.to raise_error(Sendly::APIError) do |e|
        expect(e.status_code).to eq(409)
        expect(e.message).to match(/being reviewed/)
      end
    end
  end

  describe 'agents.create' do
    it 'POSTs brandId with camelised basics, campaign and testing and returns an RcsAgentRegistration' do
      stub = stub_request(:post, "#{base_url}/rcs/agents")
        .with(
          headers: { 'Authorization' => "Bearer #{valid_api_key}" },
          body: {
            brandId: 'rcb_1',
            displayName: 'Acme Coffee',
            useCase: 'MULTI_USE',
            basics: {
              description: 'Order updates from Acme Coffee',
              logoUrl: 'https://acme.example/rcs/logo.png',
              brandColor: '#5B3A29',
              phoneNumber: { number: '+15551234567', label: 'Support' }
            },
            campaign: {
              agentOverview: 'Order updates',
              interactions: [{ interactionType: 'TRANSACTIONAL_UPDATES', description: 'Order status' }],
              messageExamples: ['Your order has shipped!'],
              consentSettings: {
                optInMethods: [{ methodType: 'WEBSITE', description: 'Checkout opt-in' }],
                doubleOptIn: false
              }
            },
            testing: { testUrl: 'https://acme.example/rcs-test' }
          }.to_json
        )
        .to_return(json(201, 'agent' => agent_body))

      agent = rcs.agents.create(
        brand_id: 'rcb_1',
        display_name: 'Acme Coffee',
        use_case: 'MULTI_USE',
        basics: {
          description: 'Order updates from Acme Coffee',
          logo_url: 'https://acme.example/rcs/logo.png',
          brand_color: '#5B3A29',
          phone_number: { number: '+15551234567', label: 'Support' }
        },
        campaign: {
          agent_overview: 'Order updates',
          interactions: [{ interaction_type: 'TRANSACTIONAL_UPDATES', description: 'Order status' }],
          message_examples: ['Your order has shipped!'],
          consent_settings: {
            opt_in_methods: [{ method_type: 'WEBSITE', description: 'Checkout opt-in' }],
            double_opt_in: false
          }
        },
        testing: { test_url: 'https://acme.example/rcs-test' }
      )

      expect(stub).to have_been_requested
      expect(agent).to be_a(Sendly::RcsAgentRegistration)
      expect(agent.id).to eq('rca_1')
      expect(agent.brand_id).to eq('rcb_1')
      expect(agent.status).to eq('draft')
      expect(agent.draft?).to be true
      expect(agent.editable?).to be true
      expect(agent.use_case).to eq('MULTI_USE')
      expect(agent.hosting_region).to eq('NORTH_AMERICA')
      expect(agent.basics).to be_a(Sendly::RcsAgentBasics)
      expect(agent.basics.logo_url).to eq('https://acme.example/rcs/logo.png')
      expect(agent.basics.terms_and_conditions_url).to eq('https://acme.example/terms')
      expect(agent.basics.phone_number).to eq('number' => '+15551234567', 'label' => 'Support')
      expect(agent.campaign).to be_a(Sendly::RcsAgentCampaign)
      expect(agent.campaign.interactions.first).to be_a(Sendly::RcsCampaignInteraction)
      expect(agent.campaign.interactions.first.interaction_type).to eq('TRANSACTIONAL_UPDATES')
      expect(agent.campaign.message_examples).to eq(['Your order has shipped!'])
      expect(agent.campaign.consent_settings).to be_a(Sendly::RcsConsentSettings)
      expect(agent.campaign.consent_settings.opt_in_methods.first).to be_a(Sendly::RcsOptInMethod)
      expect(agent.campaign.consent_settings.opt_in_methods.first.method_type).to eq('WEBSITE')
      expect(agent.campaign.consent_settings.double_opt_in).to be false
      expect(agent.campaign.consent_settings.call_to_action_url).to eq('https://acme.example/optin')
      expect(agent.testing).to be_a(Sendly::RcsAgentTesting)
      expect(agent.testing.test_url).to eq('https://acme.example/rcs-test')
      expect(agent.test_devices.first).to be_a(Sendly::RcsTestDevice)
      expect(agent.test_devices.first.label).to eq("Sam's Pixel")
      expect(agent.to_h[:campaign][:consent_settings][:opt_in_methods]).to eq(
        [{ method_type: 'WEBSITE', description: 'Checkout opt-in' }]
      )
    end

    it 'sends only brandId when nothing else is given, with an auto-generated key' do
      keys = []
      stub = stub_request(:post, "#{base_url}/rcs/agents")
        .with(body: { brandId: 'rcb_1' }.to_json) { |req| keys << req.headers['Idempotency-Key'] }
        .to_return(json(201, 'agent' => agent_body))

      rcs.agents.create(brand_id: 'rcb_1')

      expect(stub).to have_been_requested
      expect(keys.first).to match(auto_key_pattern)
    end

    it 'raises ValidationError when brand_id is missing' do
      expect { rcs.agents.create(brand_id: nil) }
        .to raise_error(Sendly::ValidationError, /brand_id is required/)
    end

    it 'raises ValidationError with field_errors on 422 rcs_invalid_content' do
      stub_request(:post, "#{base_url}/rcs/agents")
        .to_return(json(422,
                        'error' => 'rcs_invalid_content',
                        'message' => "Assets can't be uploaded over the API. Logo, hero, and call-to-action media must be public https:// URLs.",
                        'errors' => [{ 'path' => 'basics.logoUrl', 'message' => 'Must be a public https:// URL' }]))

      expect { rcs.agents.create(brand_id: 'rcb_1', basics: { logo_url: 'data:image/png;base64,AAAA' }) }
        .to raise_error(Sendly::ValidationError) do |e|
          expect(e.status_code).to eq(400)
          expect(e.message).to match(/public https/)
          expect(e.field_errors).to eq([{ 'path' => 'basics.logoUrl', 'message' => 'Must be a public https:// URL' }])
        end
    end
  end

  describe 'agents.get' do
    it 'GETs /rcs/agents/:id and maps the registration record' do
      stub_request_with_auth(:get, '/rcs/agents/rca_1', response_body: {
        'agent' => agent_body.merge('reviewStatus' => 'changes_requested',
                                    'customerStage' => 'changes_requested',
                                    'reviewNote' => 'Please add a hero image'),
        'devices' => [device_body],
        'stage' => 'changes_requested'
      })

      agent = rcs.agents.get('rca_1')

      expect(agent).to be_a(Sendly::RcsAgentRegistration)
      expect(agent.changes_requested?).to be true
      expect(agent.editable?).to be true
      expect(agent.awaiting_review?).to be false
      expect(agent.customer_stage).to eq('changes_requested')
      expect(agent.review_note).to eq('Please add a hero image')
      expect(agent.test_devices.first.invited?).to be true
      expect(agent.live?).to be false
    end

    it 'raises ValidationError when id is missing' do
      expect { rcs.agents.get(nil) }
        .to raise_error(Sendly::ValidationError, /Agent ID is required/)
    end

    it 'raises NotFoundError on 404 rcs_not_found' do
      stub_request_with_auth(:get, '/rcs/agents/rca_missing', status: 404,
                             response_body: { 'error' => 'rcs_not_found', 'message' => 'Agent not found' })

      expect { rcs.agents.get('rca_missing') }.to raise_error(Sendly::NotFoundError, /Agent not found/)
    end
  end

  describe 'agents.update' do
    it 'PATCHes the groups given and clears a section with nil, with the caller key' do
      stub = stub_request(:patch, "#{base_url}/rcs/agents/rca_1")
        .with(
          headers: { 'Idempotency-Key' => 'agent-fix-1' },
          body: { basics: { heroUrl: 'https://acme.example/rcs/hero-v2.png' }, testing: nil }.to_json
        )
        .to_return(json(200, 'agent' => agent_body.merge('testing' => nil)))

      agent = rcs.agents.update('rca_1', basics: { hero_url: 'https://acme.example/rcs/hero-v2.png' },
                                         testing: nil, idempotency_key: 'agent-fix-1')

      expect(stub).to have_been_requested
      expect(agent).to be_a(Sendly::RcsAgentRegistration)
      expect(agent.testing).to be_nil
    end

    it 'patches display_name and use_case on their own' do
      stub = stub_request(:patch, "#{base_url}/rcs/agents/rca_1")
        .with(body: { displayName: 'Acme Coffee Co', useCase: 'TRANSACTIONAL' }.to_json)
        .to_return(json(200, 'agent' => agent_body.merge('displayName' => 'Acme Coffee Co',
                                                          'useCase' => 'TRANSACTIONAL')))

      agent = rcs.agents.update('rca_1', display_name: 'Acme Coffee Co', use_case: 'TRANSACTIONAL')

      expect(stub).to have_been_requested
      expect(agent.display_name).to eq('Acme Coffee Co')
      expect(agent.use_case).to eq('TRANSACTIONAL')
    end

    it 'raises ValidationError when nothing is given' do
      expect { rcs.agents.update('rca_1') }
        .to raise_error(Sendly::ValidationError, /at least one agent field/)
    end

    it 'raises APIError with status 409 on rcs_field_locked' do
      stub_request(:patch, "#{base_url}/rcs/agents/rca_1")
        .to_return(json(409, 'error' => 'rcs_field_locked',
                             'message' => 'This registration is being reviewed; we will email you if changes are needed.'))

      expect { rcs.agents.update('rca_1', display_name: 'Acme') }.to raise_error(Sendly::APIError) do |e|
        expect(e.status_code).to eq(409)
      end
    end
  end

  describe 'agents.set_test_devices' do
    it 'PUTs the full device list and returns RcsTestDevice models' do
      stub = stub_request(:put, "#{base_url}/rcs/agents/rca_1/test-devices")
        .with(
          headers: { 'Idempotency-Key' => 'devices-1' },
          body: { devices: [{ phoneNumber: '+15557654321', label: "Sam's Pixel" },
                            { phoneNumber: '+15551112222' }] }.to_json
        )
        .to_return(json(200, 'devices' => [
          device_body,
          device_body.merge('id' => 'rcd_2', 'phoneNumber' => '+15551112222', 'label' => nil, 'inviteStatus' => nil)
        ]))

      result = rcs.agents.set_test_devices('rca_1', devices: [
        { phone_number: '+15557654321', label: "Sam's Pixel" },
        '+15551112222'
      ], idempotency_key: 'devices-1')

      expect(stub).to have_been_requested
      expect(result[:devices].length).to eq(2)
      expect(result[:devices].first).to be_a(Sendly::RcsTestDevice)
      expect(result[:devices].first.invited?).to be true
      expect(result[:devices].first.invite_status).to eq('PENDING')
      expect(result[:devices].last.phone_number).to eq('+15551112222')
      expect(result[:devices].last.label).to be_nil
      expect(result[:devices].last.invited?).to be false
    end

    it 'sends an empty list to remove every device, without an auto key' do
      keys = []
      stub = stub_request(:put, "#{base_url}/rcs/agents/rca_1/test-devices")
        .with(body: { devices: [] }.to_json) { |req| keys << req.headers['Idempotency-Key'] }
        .to_return(json(200, 'devices' => []))

      result = rcs.agents.set_test_devices('rca_1', devices: [])

      expect(stub).to have_been_requested
      expect(result[:devices]).to eq([])
      expect(keys.first).to be_nil
    end

    it 'raises ValidationError when devices is not an array' do
      expect { rcs.agents.set_test_devices('rca_1', devices: '+15557654321') }
        .to raise_error(Sendly::ValidationError, /devices must be an array/)
    end

    it 'raises ValidationError with field_errors on 422 rcs_invalid_content' do
      stub_request(:put, "#{base_url}/rcs/agents/rca_1/test-devices")
        .to_return(json(422, 'error' => 'rcs_invalid_content', 'message' => 'Check the device list',
                             'errors' => [{ 'path' => 'devices.1.phoneNumber',
                                            'message' => "Enter the device's phone number in E.164 format, like +13125550100" }]))

      expect { rcs.agents.set_test_devices('rca_1', devices: ['+15557654321', 'not-a-number']) }
        .to raise_error(Sendly::ValidationError) do |e|
          expect(e.field_errors.first['path']).to eq('devices.1.phoneNumber')
        end
    end
  end

  describe 'agents.submit' do
    it 'POSTs an empty body with the caller key and returns the agent awaiting review' do
      stub = stub_request(:post, "#{base_url}/rcs/agents/rca_1/submit")
        .with(headers: { 'Idempotency-Key' => 'rcs-submit-rca_1' }, body: {}.to_json)
        .to_return(json(200,
                        'agent' => agent_body.merge('status' => 'submitted', 'reviewStatus' => 'awaiting_review',
                                                    'customerStage' => 'in_review',
                                                    'submittedForReviewAt' => '2026-09-02T09:00:00Z'),
                        'stage' => 'in_review'))

      agent = rcs.agents.submit('rca_1', idempotency_key: 'rcs-submit-rca_1')

      expect(stub).to have_been_requested
      expect(agent).to be_a(Sendly::RcsAgentRegistration)
      expect(agent.awaiting_review?).to be true
      expect(agent.editable?).to be false
      expect(agent.customer_stage).to eq('in_review')
      expect(agent.submitted_for_review_at).to eq('2026-09-02T09:00:00Z')
    end

    it 'auto-generates a key when none is given' do
      keys = []
      stub_request(:post, "#{base_url}/rcs/agents/rca_1/submit")
        .with { |req| keys << req.headers['Idempotency-Key'] }
        .to_return(json(200, 'agent' => agent_body, 'stage' => 'in_review'))

      rcs.agents.submit('rca_1')

      expect(keys.first).to match(auto_key_pattern)
    end

    it 'raises ValidationError listing brand and agent fields on 422 rcs_invalid_content' do
      stub_request(:post, "#{base_url}/rcs/agents/rca_1/submit")
        .to_return(json(422, 'error' => 'rcs_invalid_content', 'message' => 'Finish the brand and agent first',
                             'errors' => [{ 'path' => 'brand.ein', 'message' => 'Enter a 9-digit EIN' },
                                          { 'path' => 'agent.logoUrl', 'message' => 'Must be a public https:// URL' }]))

      expect { rcs.agents.submit('rca_1') }.to raise_error(Sendly::ValidationError) do |e|
        expect(e.field_errors.map { |f| f['path'] }).to eq(%w[brand.ein agent.logoUrl])
      end
    end

    it 'raises APIError with status 409 on rcs_brand_not_verified' do
      stub_request(:post, "#{base_url}/rcs/agents/rca_1/submit")
        .to_return(json(409, 'error' => 'rcs_brand_not_verified', 'message' => 'The brand failed verification'))

      expect { rcs.agents.submit('rca_1') }.to raise_error(Sendly::APIError) do |e|
        expect(e.status_code).to eq(409)
        expect(e.message).to match(/failed verification/)
      end
    end
  end

  describe 'agents.request_launch' do
    it 'POSTs the testing details and returns the agent with launch requested' do
      stub = stub_request(:post, "#{base_url}/rcs/agents/rca_1/request-launch")
        .with(body: { testUrl: 'https://acme.example/rcs-test',
                      testingAdditionalInformation: 'Tested on two devices' }.to_json)
        .to_return(json(200,
                        'agent' => agent_body.merge('status' => 'testing', 'reviewStatus' => 'launch_requested',
                                                    'customerStage' => 'launch_review'),
                        'stage' => 'launch_review'))

      agent = rcs.agents.request_launch('rca_1', test_url: 'https://acme.example/rcs-test',
                                                 testing_additional_information: 'Tested on two devices')

      expect(stub).to have_been_requested
      expect(agent).to be_a(Sendly::RcsAgentRegistration)
      expect(agent.launch_requested?).to be true
      expect(agent.testing?).to be true
      expect(agent.customer_stage).to eq('launch_review')
    end

    it 'POSTs an empty body when no details are given' do
      stub = stub_request(:post, "#{base_url}/rcs/agents/rca_1/request-launch")
        .with(body: {}.to_json)
        .to_return(json(200, 'agent' => agent_body, 'stage' => 'launch_review'))

      rcs.agents.request_launch('rca_1')

      expect(stub).to have_been_requested
    end

    it 'raises APIError with status 409 on rcs_launch_not_ready' do
      stub_request(:post, "#{base_url}/rcs/agents/rca_1/request-launch")
        .to_return(json(409, 'error' => 'rcs_launch_not_ready',
                             'message' => "This agent isn't ready to launch yet. Finish testing on an invited device first."))

      expect { rcs.agents.request_launch('rca_1') }.to raise_error(Sendly::APIError) do |e|
        expect(e.status_code).to eq(409)
        expect(e.message).to match(/isn't ready to launch/)
      end
    end
  end

  describe 'agents.list' do
    it 'carries the new stage field alongside the existing ones' do
      stub_request_with_auth(:get, '/rcs/agents', response_body: {
        'agents' => [{ 'id' => 'rca_1', 'name' => 'Acme Coffee', 'status' => 'testing',
                       'useCase' => 'MULTI_USE', 'sendable' => true, 'stage' => 'testing',
                       'createdAt' => '2026-09-01T10:00:00Z' }]
      })

      agent = rcs.agents.list[:agents].first

      expect(agent).to be_a(Sendly::RcsAgent)
      expect(agent.stage).to eq('testing')
      expect(agent.to_h[:stage]).to eq('testing')
      expect(agent.sendable?).to be true
    end
  end

  describe 'dark posture' do
    it 'raises NotFoundError on every registration read while RCS is off for the account' do
      stub_request_with_auth(:get, '/rcs/registration', status: 404, response_body: dark_body)
      stub_request_with_auth(:get, '/rcs/dossier', status: 404, response_body: dark_body)
      stub_request_with_auth(:get, '/rcs/agents/rca_1', status: 404, response_body: dark_body)

      expect { rcs.registration.get }.to raise_error(Sendly::NotFoundError) do |e|
        expect(e.message).to eq("RCS registration isn't enabled for this account yet.")
        expect(e.status_code).to eq(404)
      end
      expect { rcs.dossier.get }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
      expect { rcs.agents.get('rca_1') }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
    end

    it 'raises NotFoundError on every registration write too' do
      stub_request(:post, "#{base_url}/rcs/brands").to_return(json(404, dark_body))
      stub_request(:patch, "#{base_url}/rcs/brands/rcb_1").to_return(json(404, dark_body))
      stub_request(:post, "#{base_url}/rcs/agents").to_return(json(404, dark_body))
      stub_request(:patch, "#{base_url}/rcs/agents/rca_1").to_return(json(404, dark_body))
      stub_request(:put, "#{base_url}/rcs/agents/rca_1/test-devices").to_return(json(404, dark_body))
      stub_request(:post, "#{base_url}/rcs/agents/rca_1/submit").to_return(json(404, dark_body))
      stub_request(:post, "#{base_url}/rcs/agents/rca_1/request-launch").to_return(json(404, dark_body))

      expect { rcs.brands.create(display_name: 'Acme') }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
      expect { rcs.brands.update('rcb_1', ein: '12-3456789') }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
      expect { rcs.agents.create(brand_id: 'rcb_1') }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
      expect { rcs.agents.update('rca_1', display_name: 'Acme') }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
      expect { rcs.agents.set_test_devices('rca_1', devices: []) }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
      expect { rcs.agents.submit('rca_1') }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
      expect { rcs.agents.request_launch('rca_1') }.to raise_error(Sendly::NotFoundError, /isn't enabled/)
    end
  end

  describe 'scope errors' do
    it 'raises APIError with status 403 when the key lacks the scope' do
      stub_request_with_auth(:get, '/rcs/registration', status: 403,
                             response_body: { 'error' => 'insufficient_permissions',
                                              'message' => 'This API key lacks the rcs:read scope' })

      expect { rcs.registration.get }.to raise_error(Sendly::APIError) do |e|
        expect(e.status_code).to eq(403)
        expect(e.message).to match(/rcs:read/)
      end
    end
  end
end
