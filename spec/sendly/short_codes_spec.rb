# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::ShortCodesResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key, max_retries: 0) }
  let(:short_codes) { client.short_codes }

  let(:lease) do
    {
      'monthlyCents' => 100_000, 'minimumTermMonths' => 3, 'state' => 'not_started',
      'billingEnabled' => true, 'startedAt' => nil, 'nextChargeAt' => nil, 'paidThrough' => nil,
      'termEndsAt' => nil, 'endsAt' => nil, 'cancelRequestedAt' => nil, 'pastDue' => nil,
      'dueMonths' => 0, 'dueCents' => 0
    }
  end

  let(:application) do
    {
      'id' => 'sc_1', 'shortCode' => nil, 'countryCode' => 'US', 'status' => 'requested',
      'reviewStatus' => 'awaiting_review', 'reviewNote' => nil, 'orderType' => 'new',
      'codeType' => 'random', 'contentProviderSameAsBrand' => true,
      'sampleMessages' => ['Acme: your order shipped. Reply STOP to opt out.'],
      'useCase' => 'Order and delivery alerts', 'optInFlow' => 'Customers text JOIN after checkout.',
      'expectedMonthlyVolume' => '50000', 'expectedDailyVolume' => '2000',
      'helpResponse' => nil, 'stopConfirmation' => nil, 'optInConfirmation' => nil,
      'privacyPolicyUrl' => 'https://acme.example/privacy', 'termsUrl' => 'https://acme.example/terms',
      'messageFrequency' => 'Up to 4 messages per order', 'campaignKeyword' => 'JOIN',
      'requestedDigits' => nil, 'losingProvider' => nil, 'brandContactName' => 'Ada Lovelace',
      'brandContactEmail' => 'ada@acme.example', 'brandContactPhone' => '+15125550100',
      'contentProviderLegalName' => nil, 'contentProviderEin' => nil,
      'contentProviderContactName' => nil, 'contentProviderContactEmail' => nil,
      'contentProviderContactPhone' => nil, 'brandRegistrationStatus' => 'registered',
      'contentProviderRegistrationStatus' => 'not_started',
      'submittedAt' => '2026-09-01T10:00:00.000Z', 'reviewedAt' => '2026-09-03T10:00:00.000Z',
      'filedAt' => nil, 'activatedAt' => nil, 'registryRevettingDueAt' => nil,
      'createdAt' => '2026-08-30T10:00:00.000Z', 'updatedAt' => '2026-09-03T10:00:00.000Z'
    }
  end

  let(:view) do
    {
      'enabled' => true,
      'application' => application,
      'prefill' => { 'source' => 'tendlc', 'legalName' => 'Acme Inc', 'contact' => { 'name' => 'Ada' } },
      'editable' => false,
      'lockMessage' => 'Sendly is reviewing this application.',
      'canStartNewApplication' => false,
      'generatedDefaults' => nil,
      'requiredDocuments' => ['loa'],
      'missingDocuments' => [],
      'documents' => [
        { 'kind' => 'loa', 'templateReady' => true, 'signedAt' => '2026-09-02T10:00:00.000Z',
          'signedByName' => 'Ada Lovelace', 'awaitingSignature' => false }
      ],
      'quote' => {
        'codeType' => 'random', 'monthlyUsd' => 1000, 'setupUsd' => 999, 'currency' => 'USD',
        'autoBilled' => false, 'setupCents' => 99_900, 'monthlyCents' => 100_000,
        'minimumTermMonths' => 3, 'setupChargedAt' => 'submit', 'leaseStartsAt' => 'go_live'
      },
      'billing' => {
        'setupFee' => { 'amountCents' => 99_900, 'status' => 'paid', 'chargedAt' => 'submit',
                        'paidAt' => '2026-09-01T10:00:00.000Z', 'refundedCents' => 0, 'refundedAt' => nil },
        'lease' => lease.merge('startsAt' => 'go_live'),
        'terms' => { 'version' => '2026-09', 'acceptedVersion' => '2026-09', 'acceptedAt' => '2026-09-01T10:00:00.000Z' },
        'refundPolicy' => 'full_refund_before_filing',
        'exempt' => nil,
        'charges' => []
      },
      'verification' => { 'verified' => true, 'state' => 'verified', 'href' => '/verify' },
      'carriers' => {
        'approved' => 1, 'total' => 4, 'overall' => 'in_progress',
        'byCarrier' => [
          { 'carrier' => 'ATT', 'label' => 'AT&T', 'status' => 'approved', 'updatedAt' => '2026-09-10T10:00:00.000Z' },
          { 'carrier' => 'TMOBILE', 'label' => 'T-Mobile', 'status' => 'in_review', 'updatedAt' => nil }
        ]
      }
    }
  end

  describe '#list' do
    it 'gets /short_codes and returns each code with its billing' do
      stub = stub_request(:get, "#{base_url}/short_codes")
        .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
        .to_return(status: 200, body: {
          shortCodes: [
            { id: 'sc_1', shortCode: '55123', countryCode: 'US', status: 'active',
              reviewStatus: 'filed', useCase: 'Order alerts', createdAt: '2026-08-30T10:00:00.000Z',
              billing: { setupFee: { status: 'paid', amountCents: 99_900 }, lease: lease } },
            { id: 'sc_2', shortCode: nil, countryCode: 'US', status: 'requested',
              reviewStatus: 'draft', useCase: '', createdAt: '2026-10-01T10:00:00.000Z',
              billing: { setupFee: { status: 'unpaid', amountCents: 99_900 }, lease: lease } }
          ]
        }.to_json)

      codes = short_codes.list

      expect(stub).to have_been_requested
      expect(codes.map(&:class).uniq).to eq([Sendly::ShortCode])
      expect(codes.first.short_code).to eq('55123')
      expect(codes.first.review_status).to eq('filed')
      expect(codes.first.billing[:setup_fee][:status]).to eq('paid')
      expect(codes.first.billing[:lease][:monthly_cents]).to eq(100_000)
      expect(codes.select(&:active?).map(&:id)).to eq(['sc_1'])
      expect(codes.last.short_code).to be_nil
    end
  end

  describe '#application' do
    describe '#get' do
      it 'gets /short_codes/application and returns the view' do
        stub = stub_request(:get, "#{base_url}/short_codes/application")
          .to_return(status: 200, body: view.to_json)

        result = short_codes.application.get

        expect(stub).to have_been_requested
        expect(result).to be_a(Sendly::ShortCodeApplicationView)
        expect(result.editable?).to be false
        expect(result.lock_message).to eq('Sendly is reviewing this application.')
        expect(result.application).to be_a(Sendly::ShortCodeApplication)
        expect(result.application.review_status).to eq('awaiting_review')
        expect(result.application.reviewed_at).to eq('2026-09-03T10:00:00.000Z')
        expect(result.application.sample_messages).to eq(['Acme: your order shipped. Reply STOP to opt out.'])
        expect(result.application.content_provider_same_as_brand).to be true
        expect(result.prefill[:legal_name]).to eq('Acme Inc')
        expect(result.prefill[:contact]).to eq(name: 'Ada')
        expect(result.documents.first.signed_by_name).to eq('Ada Lovelace')
        expect(result.documents.first.template_ready).to be true
        expect(result.quote[:setup_usd]).to eq(999)
        expect(result.quote[:minimum_term_months]).to eq(3)
        expect(result.billing[:setup_fee][:status]).to eq('paid')
        expect(result.billing[:lease][:starts_at]).to eq('go_live')
        expect(result.verification[:state]).to eq('verified')
        expect(result.carriers[:by_carrier][1]).to eq(carrier: 'TMOBILE', label: 'T-Mobile', status: 'in_review', updated_at: nil)
        expect(result.generated_defaults).to be_nil
        expect(result.ignored_fields).to be_nil
      end

      it 'raises NotFoundError when short codes are not enabled' do
        stub_request(:get, "#{base_url}/short_codes/application")
          .to_return(status: 404, body: { error: 'short_codes_not_enabled', message: 'Short codes are not enabled' }.to_json)

        expect { short_codes.application.get }
          .to raise_error(Sendly::NotFoundError) { |e| expect(e.code).to eq('short_codes_not_enabled') }
      end
    end

    describe '#update' do
      it 'puts camelCase answers and returns the saved view with ignored fields' do
        stub = stub_request(:put, "#{base_url}/short_codes/application")
          .with(body: {
            useCase: 'Delivery alerts for Acme orders',
            messageFrequency: '4 messages per month',
            sampleMessages: ['Acme: shipped. Reply STOP to opt out.']
          }.to_json)
          .to_return(status: 200, body: view.merge('editable' => true, 'ignoredFields' => ['status']).to_json)

        result = short_codes.application.update(
          use_case: 'Delivery alerts for Acme orders',
          messageFrequency: '4 messages per month',
          sample_messages: ['Acme: shipped. Reply STOP to opt out.']
        )

        expect(stub).to have_been_requested
        expect(result.editable?).to be true
        expect(result.ignored_fields).to eq(['status'])
      end

      it 'sends no Idempotency-Key unless one is given, and a caller key verbatim' do
        keys = []
        stub_request(:put, "#{base_url}/short_codes/application")
          .with { |req| keys << req.headers['Idempotency-Key'] }
          .to_return(status: 200, body: view.to_json)

        short_codes.application.update(use_case: 'Alerts')
        short_codes.application.update(use_case: 'Alerts', idempotency_key: 'save-1')

        expect(keys).to eq([nil, 'save-1'])
      end
    end

    describe '#check' do
      it 'posts unsaved answers to the preflight and returns every issue' do
        stub = stub_request(:post, "#{base_url}/short_codes/application/preflight")
          .with(body: { helpResponse: 'Acme: reply STOP to opt out.' }.to_json)
          .to_return(status: 200, body: {
            ok: false,
            issues: [{ path: 'helpResponse', message: 'Include a way to reach you, such as a phone number.' }],
            requiredDocuments: ['loa'],
            missingDocuments: ['loa'],
            documents: []
          }.to_json)

        result = short_codes.application.check(help_response: 'Acme: reply STOP to opt out.')

        expect(stub).to have_been_requested
        expect(result).to be_a(Sendly::ShortCodePreflight)
        expect(result.ok?).to be false
        expect(result.issues.first.path).to eq('helpResponse')
        expect(result.issues.first.message).to include('phone number')
        expect(result.missing_documents).to eq(['loa'])
      end

      it 'posts an empty body when nothing is passed' do
        stub = stub_request(:post, "#{base_url}/short_codes/application/preflight")
          .with(body: {}.to_json)
          .to_return(status: 200, body: { ok: true, issues: [], requiredDocuments: [], missingDocuments: [], documents: [] }.to_json)

        expect(short_codes.application.check.ok?).to be true
        expect(stub).to have_been_requested
      end
    end

    describe '#submit' do
      it 'posts acceptTerms with a caller idempotency key and returns the payment' do
        stub = stub_request(:post, "#{base_url}/short_codes/application/submit")
          .with(
            headers: { 'Idempotency-Key' => 'submit-sc-1' },
            body: { acceptTerms: true }.to_json
          )
          .to_return(status: 200, body: view.merge(
            'submitted' => true, 'alreadySubmitted' => false, 'notified' => true,
            'payment' => { 'status' => 'paid', 'charged' => true }
          ).to_json)

        result = short_codes.application.submit(accept_terms: true, idempotency_key: 'submit-sc-1')

        expect(stub).to have_been_requested
        expect(result.submitted).to be true
        expect(result.already_submitted?).to be false
        expect(result.notified).to be true
        expect(result.payment).to eq(status: 'paid', charged: true)
      end

      it 'raises InsufficientCreditsError with the checkout URL when the fee cannot be charged' do
        stub_request(:post, "#{base_url}/short_codes/application/submit")
          .to_return(status: 402, body: {
            error: 'payment_requires_authentication',
            message: 'Your bank needs to confirm this payment.',
            checkoutUrl: 'https://checkout.example/pay/cs_1'
          }.to_json)

        expect { short_codes.application.submit(accept_terms: true) }
          .to raise_error(Sendly::InsufficientCreditsError) { |e|
            expect(e.code).to eq('payment_requires_authentication')
            expect(e.response_body['checkoutUrl']).to eq('https://checkout.example/pay/cs_1')
          }
      end
    end
  end
end
