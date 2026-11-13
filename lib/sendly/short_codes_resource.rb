# frozen_string_literal: true

module Sendly
  # A compliance problem with a short code application. +path+ is the field
  # it is about, such as "helpResponse" or "documents.loa"; +message+ says
  # what to change.
  class ShortCodeIssue
    attr_reader :path, :message

    def initialize(data)
      data ||= {}
      @path = data["path"]
      @message = data["message"]
    end

    def to_h
      { path: path, message: message }.compact
    end
  end

  # A carrier form the application needs, and where it stands.
  class ShortCodeDocument
    attr_reader :kind, :template_ready, :signed_at, :signed_by_name, :awaiting_signature

    def initialize(data)
      data ||= {}
      @kind = data["kind"]
      @template_ready = data["templateReady"]
      @signed_at = data["signedAt"]
      @signed_by_name = data["signedByName"]
      @awaiting_signature = data["awaitingSignature"]
    end

    def to_h
      {
        kind: kind, template_ready: template_ready, signed_at: signed_at,
        signed_by_name: signed_by_name, awaiting_signature: awaiting_signature
      }.compact
    end
  end

  # The workspace's short code application. With no application yet it is
  # the empty shape: +id+ is nil, the choices show their defaults and every
  # answer is nil. +status+ is where the code stands (see {STATUSES}) and
  # +review_status+ where Sendly's review stands (see {REVIEW_STATUSES});
  # a value this SDK predates comes through unchanged.
  class ShortCodeApplication
    STATUSES = %w[requested provisioning parked active suspended cancelled].freeze
    REVIEW_STATUSES = %w[draft awaiting_review changes_requested approved_for_filing filed rejected].freeze

    FIELDS = {
      id: "id", short_code: "shortCode", country_code: "countryCode", status: "status",
      review_status: "reviewStatus", review_note: "reviewNote", order_type: "orderType",
      code_type: "codeType", content_provider_same_as_brand: "contentProviderSameAsBrand",
      sample_messages: "sampleMessages", use_case: "useCase", opt_in_flow: "optInFlow",
      opt_in_confirmation: "optInConfirmation", help_response: "helpResponse",
      stop_confirmation: "stopConfirmation", message_frequency: "messageFrequency",
      campaign_keyword: "campaignKeyword", expected_monthly_volume: "expectedMonthlyVolume",
      expected_daily_volume: "expectedDailyVolume", privacy_policy_url: "privacyPolicyUrl",
      terms_url: "termsUrl", requested_digits: "requestedDigits", losing_provider: "losingProvider",
      brand_contact_name: "brandContactName", brand_contact_email: "brandContactEmail",
      brand_contact_phone: "brandContactPhone", content_provider_legal_name: "contentProviderLegalName",
      content_provider_ein: "contentProviderEin", content_provider_contact_name: "contentProviderContactName",
      content_provider_contact_email: "contentProviderContactEmail",
      content_provider_contact_phone: "contentProviderContactPhone",
      brand_registration_status: "brandRegistrationStatus",
      content_provider_registration_status: "contentProviderRegistrationStatus",
      submitted_at: "submittedAt", reviewed_at: "reviewedAt", filed_at: "filedAt",
      activated_at: "activatedAt", registry_revetting_due_at: "registryRevettingDueAt",
      created_at: "createdAt", updated_at: "updatedAt"
    }.freeze

    attr_reader(*FIELDS.keys)

    def initialize(data)
      data ||= {}
      FIELDS.each { |attr, key| instance_variable_set("@#{attr}", data[key]) }
      @sample_messages ||= []
    end

    def active?
      status == "active"
    end

    def to_h
      FIELDS.keys.to_h { |attr| [attr, public_send(attr)] }.compact
    end
  end

  # The application plus everything needed to act on it. +prefill+,
  # +generated_defaults+, +quote+, +billing+, +verification+, +carriers+
  # and +payment+ are Hashes with snake_case Symbol keys (for example
  # +quote[:setup_usd]+, +billing[:setup_fee][:status]+ and
  # +carriers[:by_carrier]+). +ignored_fields+ is set on a save or a
  # check; +submitted+, +already_submitted+, +notified+ and +payment+ on a
  # submit (+payment+ is nil when the application was already in review).
  class ShortCodeApplicationView
    attr_reader :enabled, :application, :prefill, :editable, :lock_message,
                :can_start_new_application, :generated_defaults,
                :required_documents, :missing_documents, :documents, :quote,
                :billing, :verification, :carriers, :ignored_fields,
                :submitted, :already_submitted, :notified, :payment

    def initialize(data)
      data ||= {}
      @enabled = data["enabled"]
      @application = ShortCodeApplication.new(data["application"])
      @prefill = RcsRegistrationInput.underscore(data["prefill"] || {})
      @editable = data["editable"]
      @lock_message = data["lockMessage"]
      @can_start_new_application = data["canStartNewApplication"]
      @generated_defaults = data["generatedDefaults"] && RcsRegistrationInput.underscore(data["generatedDefaults"])
      @required_documents = data["requiredDocuments"] || []
      @missing_documents = data["missingDocuments"] || []
      @documents = (data["documents"] || []).map { |d| ShortCodeDocument.new(d) }
      @quote = RcsRegistrationInput.underscore(data["quote"] || {})
      @billing = RcsRegistrationInput.underscore(data["billing"] || {})
      @verification = RcsRegistrationInput.underscore(data["verification"] || {})
      @carriers = RcsRegistrationInput.underscore(data["carriers"] || {})
      @ignored_fields = data["ignoredFields"]
      @submitted = data["submitted"]
      @already_submitted = data["alreadySubmitted"]
      @notified = data["notified"]
      @payment = data["payment"] && RcsRegistrationInput.underscore(data["payment"])
    end

    def editable?
      editable == true
    end

    def already_submitted?
      already_submitted == true
    end

    def to_h
      {
        enabled: enabled, application: application.to_h, prefill: prefill,
        editable: editable, lock_message: lock_message,
        can_start_new_application: can_start_new_application,
        generated_defaults: generated_defaults,
        required_documents: required_documents, missing_documents: missing_documents,
        documents: documents.map(&:to_h), quote: quote, billing: billing,
        verification: verification, carriers: carriers, ignored_fields: ignored_fields,
        submitted: submitted, already_submitted: already_submitted,
        notified: notified, payment: payment
      }.compact
    end
  end

  # A dry run of submitting the application. Nothing is saved. +ok+ is
  # false when there is any issue; +issues+ lists every one at once.
  class ShortCodePreflight
    attr_reader :ok, :issues, :required_documents, :missing_documents, :documents, :ignored_fields

    def initialize(data)
      data ||= {}
      @ok = data["ok"]
      @issues = (data["issues"] || []).map { |i| ShortCodeIssue.new(i) }
      @required_documents = data["requiredDocuments"] || []
      @missing_documents = data["missingDocuments"] || []
      @documents = (data["documents"] || []).map { |d| ShortCodeDocument.new(d) }
      @ignored_fields = data["ignoredFields"]
    end

    def ok?
      ok == true
    end

    def to_h
      {
        ok: ok, issues: issues.map(&:to_h), required_documents: required_documents,
        missing_documents: missing_documents, documents: documents.map(&:to_h),
        ignored_fields: ignored_fields
      }.compact
    end
  end

  # One of the workspace's short code applications, with its code once
  # Sendly assigns one. +short_code+ is nil until then, and drafts,
  # rejected and cancelled applications are listed too. +billing+ is a Hash
  # with snake_case Symbol keys (+billing[:setup_fee][:status]+,
  # +billing[:lease][:state]+).
  class ShortCode
    attr_reader :id, :short_code, :country_code, :status, :review_status, :use_case, :created_at, :billing

    def initialize(data)
      data ||= {}
      @id = data["id"]
      @short_code = data["shortCode"]
      @country_code = data["countryCode"]
      @status = data["status"]
      @review_status = data["reviewStatus"]
      @use_case = data["useCase"]
      @created_at = data["createdAt"]
      @billing = RcsRegistrationInput.underscore(data["billing"] || {})
    end

    def active?
      status == "active"
    end

    def to_h
      {
        id: id, short_code: short_code, country_code: country_code, status: status,
        review_status: review_status, use_case: use_case, created_at: created_at,
        billing: billing
      }.compact
    end
  end

  # The workspace's short code application: read it, save answers, check
  # it against the carrier rules and submit it. Answers are passed as
  # keywords in snake_case or camelCase (+use_case:+ or +useCase:+), the
  # same fields the API takes, such as +use_case+, +opt_in_flow+,
  # +sample_messages+, +order_type+, +code_type+ and +brand_contact_email+.
  class ShortCodeApplicationResource
    def initialize(client)
      @client = client
    end

    # Fetch the application, with the documents it needs, the quote, and
    # +billing+: where the setup fee and the monthly lease stand. Requires
    # the +short_codes:read+ scope.
    #
    # @return [ShortCodeApplicationView]
    # @raise [Sendly::NotFoundError] +short_codes_not_enabled+ (404) when
    #   short codes aren't enabled for the account
    #
    # @example
    #   view = client.short_codes.application.get
    #   puts view.lock_message unless view.editable?
    def get
      ShortCodeApplicationView.new(@client.get("/short_codes/application"))
    end

    # Save answers on the application, creating it on the first call.
    # Fields Sendly or the carriers own (the digits, the status, the review
    # state) are ignored and named back in +ignored_fields+. Requires the
    # +short_codes:write+ scope.
    #
    # @param idempotency_key [String, nil] Idempotency key for this operation
    #   (1-255 printable ASCII characters), so a repeat of the same save
    #   returns the first answer
    # @param application [Hash] The answers to save
    # @return [ShortCodeApplicationView]
    # @raise [Sendly::APIError] 409 +short_code_locked+ once the application
    #   is with Sendly or the carriers
    #
    # @example
    #   client.short_codes.application.update(
    #     use_case: "Delivery alerts for Acme orders",
    #     message_frequency: "4 messages per month"
    #   )
    def update(idempotency_key: nil, **application)
      response = @client.put("/short_codes/application", RcsRegistrationInput.camelize(application),
                             idempotency_key: idempotency_key)
      ShortCodeApplicationView.new(response)
    end

    # Check the application against the carrier rules without changing
    # anything. Unsaved answers can be passed and are checked on top of
    # what is saved. Requires the +short_codes:read+ scope.
    #
    # @param application [Hash] Optional unsaved answers to check as well
    # @return [ShortCodePreflight]
    #
    # @example
    #   check = client.short_codes.application.check
    #   check.issues.each { |issue| puts "#{issue.path}: #{issue.message}" }
    def check(**application)
      response = @client.post("/short_codes/application/preflight", RcsRegistrationInput.camelize(application))
      ShortCodePreflight.new(response)
    end

    # Submit the application to Sendly for review. Submitting charges the
    # one-time $999 setup fee to the workspace's card on file, so pass
    # +accept_terms: true+ to accept it, the monthly lease from go-live and
    # the 3-month minimum. The fee is refunded in full if Sendly rejects
    # the application before filing it. Submitting twice is safe: the
    # second call reports +already_submitted+ and charges nothing. Requires
    # the +short_codes:write+ scope.
    #
    # @param idempotency_key [String, nil] Idempotency key for this operation
    #   (1-255 printable ASCII characters), so a repeat of the same submit
    #   returns the first answer
    # @param application [Hash] +accept_terms+, plus optional final answers
    #   saved before the check
    # @return [ShortCodeApplicationView] With +submitted+, +already_submitted+,
    #   +notified+ and +payment+ (whether this call charged the fee)
    # @raise [Sendly::APIError] 403 +verification_required+ until
    #   the workspace's business is verified; the answers sent are saved anyway
    # @raise [Sendly::ValidationError] 422 +short_code_invalid_application+
    #   (with an +errors+ array naming every field, +acceptTerms+ included) or
    #   +short_code_ai_draft_unedited+
    # @raise [Sendly::InsufficientCreditsError] 402 +payment_method_required+,
    #   +payment_failed+ or +payment_requires_authentication+ when the fee
    #   can't be charged; the application stays a draft
    #
    # @example
    #   result = client.short_codes.application.submit(accept_terms: true)
    #   puts result.application.review_status # "awaiting_review"
    #   puts result.billing[:setup_fee][:status] # "paid"
    def submit(idempotency_key: nil, **application)
      response = @client.post("/short_codes/application/submit", RcsRegistrationInput.camelize(application),
                              idempotency_key: idempotency_key)
      ShortCodeApplicationView.new(response)
    end
  end

  # Short codes: 5 or 6 digit US senders. Getting one is an application,
  # not a purchase: you fill it in, Sendly reviews it, the carrier forms are
  # signed, Sendly files it, and each carrier certifies the code.
  class ShortCodesResource
    # @return [ShortCodeApplicationResource] The workspace's application
    attr_reader :application

    def initialize(client)
      @client = client
      @application = ShortCodeApplicationResource.new(client)
    end

    # List every short code application of the workspace, newest first,
    # with its code once Sendly assigns one. Drafts, rejected and cancelled
    # applications are listed too, so filter on +status+ for the codes you
    # can send from. Requires the +short_codes:read+ scope.
    #
    # @return [Array<ShortCode>]
    #
    # @example
    #   sendable = client.short_codes.list.select(&:active?)
    def list
      response = @client.get("/short_codes")
      (response["shortCodes"] || []).map { |code| ShortCode.new(code) }
    end
  end
end
