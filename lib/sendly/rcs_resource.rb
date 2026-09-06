# frozen_string_literal: true

module Sendly
  # An RCS agent registered for your workspace — the branded identity your
  # RCS messages come from. +status+ moves +"draft"+ → +"submitted"+ →
  # +"testing"+ (can send, but only to invited test devices) → +"approved"+
  # (can send to everyone); +"suspended"+ agents cannot send. +sendable+ is
  # true when the agent is fully provisioned and its status allows sending.
  # +stage+ is the registration stage, one of
  # {RcsRegistration::CUSTOMER_STAGES}.
  class RcsAgent
    attr_reader :id, :name, :status, :use_case, :sendable, :stage, :created_at

    STATUSES = %w[draft submitted testing approved suspended].freeze

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @status = data["status"]
      @use_case = data["useCase"] || data["use_case"]
      @sendable = data["sendable"] || false
      @stage = data["stage"]
      @created_at = data["createdAt"] || data["created_at"]
    end

    def sendable?
      sendable
    end

    def approved?
      status == "approved"
    end

    def to_h
      {
        id: id, name: name, status: status, use_case: use_case,
        sendable: sendable, stage: stage, created_at: created_at
      }.compact
    end
  end

  # Whether a recipient's device and network can receive RCS. When
  # +capable+ is false, a text send to this recipient falls back to plain
  # SMS (unless the fallback is disabled) and a card send fails. +features+
  # lists the feature tags the device reports.
  class RcsCapability
    attr_reader :to, :agent_id, :capable, :features

    def initialize(data)
      @to = data["to"]
      @agent_id = data["agentId"] || data["agent_id"]
      @capable = data["capable"] || false
      @features = data["features"] || []
    end

    def capable?
      capable
    end

    def to_h
      { to: to, agent_id: agent_id, capable: capable, features: features }.compact
    end
  end

  # RCS-specific details on a sent message. On a native RCS delivery +kind+
  # is what was sent ("text" or "card") and +agent_name+ is the brand name
  # recipients see. On an SMS fallback +requested_channel+ is "rcs" and
  # +suggestions_dropped+ is true when suggested replies/actions were
  # dropped (they have no SMS form).
  class RcsMessageDetails
    attr_reader :kind, :agent_id, :agent_name, :requested_channel,
                :suggestions_dropped

    KINDS = %w[text card].freeze

    def initialize(data)
      @kind = data["kind"]
      @agent_id = data["agentId"] || data["agent_id"]
      @agent_name = data["agentName"] || data["agent_name"]
      @requested_channel = data["requestedChannel"] || data["requested_channel"]
      @suggestions_dropped = data["suggestionsDropped"] || data["suggestions_dropped"] || false
    end

    def to_h
      {
        kind: kind, agent_id: agent_id, agent_name: agent_name,
        requested_channel: requested_channel,
        suggestions_dropped: suggestions_dropped
      }.compact
    end
  end

  # A message sent through the RCS channel. +channel+ is "rcs" when it was
  # delivered as RCS, or "sms" when the recipient couldn't receive RCS and
  # the message fell back to plain SMS — check with {#fell_back?}. On a
  # fallback +fell_back_to+ is "sms" and +segments+/+credits_used+ are
  # billed as SMS; +rcs+ carries the channel-specific details either way.
  class RcsMessage
    attr_reader :id, :channel, :fell_back_to, :message_format, :to, :from,
                :text, :status, :segments, :credits_used, :rcs, :created_at,
                :metadata

    def initialize(data)
      @id = data["id"]
      @channel = data["channel"] || "rcs"
      @fell_back_to = data["fellBackTo"] || data["fell_back_to"]
      @message_format = data["message_format"] || data["messageFormat"] || @channel
      @to = data["to"]
      @from = data["from"]
      @text = data["text"]
      @status = data["status"]
      @segments = data["segments"] || 1
      @credits_used = data["creditsUsed"] || data["credits_used"] || 0
      @rcs = data["rcs"] ? RcsMessageDetails.new(data["rcs"]) : nil
      @created_at = data["createdAt"] || data["created_at"]
      @metadata = data["metadata"]
    end

    def fell_back?
      fell_back_to == "sms"
    end

    def delivered?
      status == "delivered"
    end

    def failed?
      status == "failed"
    end

    def to_h
      {
        id: id, channel: channel, fell_back_to: fell_back_to,
        message_format: message_format, to: to, from: from, text: text,
        status: status, segments: segments, credits_used: credits_used,
        rcs: rcs&.to_h, created_at: created_at, metadata: metadata
      }.compact
    end
  end

  # Shapes RCS registration input before it leaves the process. Nested
  # hashes (address, contact, basics, campaign, testing, devices) accept
  # either snake_case or camelCase keys; keys are camelised and values are
  # passed through untouched.
  #
  # @api private
  module RcsRegistrationInput
    OMIT = Object.new.freeze

    module_function

    def omitted?(value)
      OMIT.equal?(value)
    end

    def camelize(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), out| out[camel_key(k)] = camelize(v) }
      when Array
        value.map { |v| camelize(v) }
      else
        value
      end
    end

    def underscore(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), out| out[snake_key(k)] = underscore(v) }
      when Array
        value.map { |v| underscore(v) }
      else
        value
      end
    end

    def camel_key(key)
      key.to_s.gsub(/_([a-z0-9])/) { Regexp.last_match(1).upcase }.to_sym
    end

    def snake_key(key)
      key.to_s.gsub(/([A-Z])/) { "_#{Regexp.last_match(1).downcase}" }.to_sym
    end

    def encode_id!(id, label)
      raise ValidationError, "#{label} is required" if id.nil? || id.to_s.empty?

      URI.encode_www_form_component(id)
    end
  end

  # A postal address on an RCS brand. +country_code+ is always "US": RCS
  # registration is open to US businesses for now.
  class RcsAddress
    attr_reader :line1, :line2, :city, :state, :postal_code, :country_code

    def initialize(data)
      data ||= {}
      @line1 = data["line1"]
      @line2 = data["line2"]
      @city = data["city"]
      @state = data["state"]
      @postal_code = data["postalCode"] || data["postal_code"]
      @country_code = data["countryCode"] || data["country_code"]
    end

    def to_h
      {
        line1: line1, line2: line2, city: city, state: state,
        postal_code: postal_code, country_code: country_code
      }.compact
    end
  end

  # The business contact on an RCS brand.
  class RcsContact
    attr_reader :first_name, :last_name, :title, :email, :phone_number

    def initialize(data)
      data ||= {}
      @first_name = data["firstName"] || data["first_name"]
      @last_name = data["lastName"] || data["last_name"]
      @title = data["title"]
      @email = data["email"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
    end

    def to_h
      {
        first_name: first_name, last_name: last_name, title: title,
        email: email, phone_number: phone_number
      }.compact
    end
  end

  # The business behind an RCS agent. +review_status+ starts +"draft"+,
  # becomes +"awaiting_review"+ once an agent under it is submitted, and
  # moves to +"approved_for_carrier"+ (Sendly approved it and sent it on to
  # the carrier network), +"changes_requested"+ (see +review_note+) or
  # +"rejected"+ (see +rejection_reason+). +verified_at+ is set once the
  # carrier network has verified the business. +customer_stage+ is the
  # same lifecycle summarised as one of {RcsRegistration::CUSTOMER_STAGES}.
  class RcsBrand
    LEGAL_ENTITY_TYPES = %w[LIMITED_LIABILITY_COMPANY SOLE_PROPRIETORSHIP PARTNERSHIP
                            CORPORATION S_CORPORATION].freeze
    ORGANIZATION_TYPES = %w[PRIVATE_PROFIT PUBLIC_PROFIT NON_PROFIT GOVERNMENT UNKNOWN].freeze

    attr_reader :id, :review_status, :customer_stage, :display_name,
                :legal_name, :legal_entity_type, :organization_type,
                :stock_symbol, :website_url, :ein, :address, :contact,
                :review_note, :rejection_reason, :submitted_for_review_at,
                :sent_to_carrier_at, :verified_at, :created_at, :updated_at

    def initialize(data)
      @id = data["id"]
      @review_status = data["reviewStatus"] || data["review_status"]
      @customer_stage = data["customerStage"] || data["customer_stage"]
      @display_name = data["displayName"] || data["display_name"]
      @legal_name = data["legalName"] || data["legal_name"]
      @legal_entity_type = data["legalEntityType"] || data["legal_entity_type"]
      @organization_type = data["organizationType"] || data["organization_type"]
      @stock_symbol = data["stockSymbol"] || data["stock_symbol"]
      @website_url = data["websiteUrl"] || data["website_url"]
      @ein = data["ein"]
      @address = data["address"] ? RcsAddress.new(data["address"]) : nil
      @contact = data["contact"] ? RcsContact.new(data["contact"]) : nil
      @review_note = data["reviewNote"] || data["review_note"]
      @rejection_reason = data["rejectionReason"] || data["rejection_reason"]
      @submitted_for_review_at = data["submittedForReviewAt"] || data["submitted_for_review_at"]
      @sent_to_carrier_at = data["sentToCarrierAt"] || data["sent_to_carrier_at"]
      @verified_at = data["verifiedAt"] || data["verified_at"]
      @created_at = data["createdAt"] || data["created_at"]
      @updated_at = data["updatedAt"] || data["updated_at"]
    end

    def draft?
      review_status == "draft"
    end

    def awaiting_review?
      review_status == "awaiting_review"
    end

    def changes_requested?
      review_status == "changes_requested"
    end

    def rejected?
      review_status == "rejected"
    end

    def verified?
      !verified_at.nil?
    end

    # True while the brand can still be edited (draft or changes requested).
    def editable?
      draft? || changes_requested?
    end

    def to_h
      {
        id: id, review_status: review_status, customer_stage: customer_stage,
        display_name: display_name, legal_name: legal_name,
        legal_entity_type: legal_entity_type, organization_type: organization_type,
        stock_symbol: stock_symbol, website_url: website_url, ein: ein,
        address: address&.to_h, contact: contact&.to_h,
        review_note: review_note, rejection_reason: rejection_reason,
        submitted_for_review_at: submitted_for_review_at,
        sent_to_carrier_at: sent_to_carrier_at, verified_at: verified_at,
        created_at: created_at, updated_at: updated_at
      }.compact
    end
  end

  # A phone that can receive an agent's messages while it is in testing.
  # +invite_status+ is nil until the carrier network has been asked to
  # invite the device.
  class RcsTestDevice
    attr_reader :id, :phone_number, :label, :invite_status, :created_at

    def initialize(data)
      @id = data["id"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @label = data["label"]
      @invite_status = data["inviteStatus"] || data["invite_status"]
      @created_at = data["createdAt"] || data["created_at"]
    end

    def invited?
      !invite_status.nil?
    end

    def to_h
      {
        id: id, phone_number: phone_number, label: label,
        invite_status: invite_status, created_at: created_at
      }.compact
    end
  end

  # What recipients see of an agent: name, use case, description, logo and
  # hero images, colour, policy links and contact entries. +phone_number+,
  # +website+ and +email+ are hashes as stored (+"number"+ / +"url"+ /
  # +"address"+ plus +"label"+). +logo_url+ and +hero_url+ must be public
  # https URLs; assets cannot be uploaded over the API.
  class RcsAgentBasics
    attr_reader :display_name, :use_case, :hosting_region, :description,
                :logo_url, :hero_url, :brand_color, :privacy_policy_url,
                :terms_and_conditions_url, :phone_number, :website, :email

    def initialize(data)
      data ||= {}
      @display_name = data["displayName"] || data["display_name"]
      @use_case = data["useCase"] || data["use_case"]
      @hosting_region = data["hostingRegion"] || data["hosting_region"]
      @description = data["description"]
      @logo_url = data["logoUrl"] || data["logo_url"]
      @hero_url = data["heroUrl"] || data["hero_url"]
      @brand_color = data["brandColor"] || data["brand_color"]
      @privacy_policy_url = data["privacyPolicyUrl"] || data["privacy_policy_url"]
      @terms_and_conditions_url = data["termsAndConditionsUrl"] || data["terms_and_conditions_url"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @website = data["website"]
      @email = data["email"]
    end

    def to_h
      {
        display_name: display_name, use_case: use_case,
        hosting_region: hosting_region, description: description,
        logo_url: logo_url, hero_url: hero_url, brand_color: brand_color,
        privacy_policy_url: privacy_policy_url,
        terms_and_conditions_url: terms_and_conditions_url,
        phone_number: phone_number, website: website, email: email
      }.compact
    end
  end

  # One kind of conversation the agent will have with recipients.
  class RcsCampaignInteraction
    INTERACTION_TYPES = %w[TRANSACTIONAL_UPDATES CUSTOMER_SUPPORT LOYALTY_OR_REWARD
                           MARKETING_OR_PROMOTIONAL ACCOUNT_ALERTS TWO_WAY_CONVERSATION
                           OTHER].freeze

    attr_reader :interaction_type, :description

    def initialize(data)
      data ||= {}
      @interaction_type = data["interactionType"] || data["interaction_type"]
      @description = data["description"]
    end

    def to_h
      { interaction_type: interaction_type, description: description }.compact
    end
  end

  # One way recipients opt in to the agent's messages.
  class RcsOptInMethod
    METHOD_TYPES = %w[SMS WEBSITE MOBILE_APP QR_CODE SALE_POINT OTHER].freeze

    attr_reader :method_type, :description

    def initialize(data)
      data ||= {}
      @method_type = data["methodType"] || data["method_type"]
      @description = data["description"]
    end

    def to_h
      { method_type: method_type, description: description }.compact
    end
  end

  # How recipients consent to, get help with, and stop the agent's
  # messages. +call_to_action_media_url+ must be a public https URL.
  class RcsConsentSettings
    attr_reader :opt_in_methods, :call_to_action, :call_to_action_url,
                :call_to_action_media_url, :double_opt_in,
                :double_opt_in_message, :opt_in_message, :help_response,
                :opt_out_response

    def initialize(data)
      data ||= {}
      methods = data["optInMethods"] || data["opt_in_methods"]
      @opt_in_methods = methods ? methods.map { |m| RcsOptInMethod.new(m) } : nil
      @call_to_action = data["callToAction"] || data["call_to_action"]
      @call_to_action_url = data["callToActionUrl"] || data["call_to_action_url"]
      @call_to_action_media_url = data["callToActionMediaUrl"] || data["call_to_action_media_url"]
      @double_opt_in = data.key?("doubleOptIn") ? data["doubleOptIn"] : data["double_opt_in"]
      @double_opt_in_message = data["doubleOptInMessage"] || data["double_opt_in_message"]
      @opt_in_message = data["optInMessage"] || data["opt_in_message"]
      @help_response = data["helpResponse"] || data["help_response"]
      @opt_out_response = data["optOutResponse"] || data["opt_out_response"]
    end

    def to_h
      {
        opt_in_methods: opt_in_methods&.map(&:to_h), call_to_action: call_to_action,
        call_to_action_url: call_to_action_url,
        call_to_action_media_url: call_to_action_media_url,
        double_opt_in: double_opt_in, double_opt_in_message: double_opt_in_message,
        opt_in_message: opt_in_message, help_response: help_response,
        opt_out_response: opt_out_response
      }.compact
    end
  end

  # The agent's campaign: what the business does, what the agent sends,
  # example messages and consent settings. Reviewed before launch.
  class RcsAgentCampaign
    attr_reader :company_overview, :agent_overview, :additional_information,
                :interactions, :message_examples, :consent_settings

    def initialize(data)
      data ||= {}
      @company_overview = data["companyOverview"] || data["company_overview"]
      @agent_overview = data["agentOverview"] || data["agent_overview"]
      @additional_information = data["additionalInformation"] || data["additional_information"]
      interactions = data["interactions"]
      @interactions = interactions ? interactions.map { |i| RcsCampaignInteraction.new(i) } : nil
      @message_examples = data["messageExamples"] || data["message_examples"]
      consent = data["consentSettings"] || data["consent_settings"]
      @consent_settings = consent ? RcsConsentSettings.new(consent) : nil
    end

    def to_h
      {
        company_overview: company_overview, agent_overview: agent_overview,
        additional_information: additional_information,
        interactions: interactions&.map(&:to_h),
        message_examples: message_examples,
        consent_settings: consent_settings&.to_h
      }.compact
    end
  end

  # How the agent was tested on an invited device before launch.
  class RcsAgentTesting
    attr_reader :test_url, :message_id, :additional_information

    def initialize(data)
      data ||= {}
      @test_url = data["testUrl"] || data["test_url"]
      @message_id = data["messageId"] || data["message_id"]
      @additional_information = data["additionalInformation"] || data["additional_information"]
    end

    def to_h
      {
        test_url: test_url, message_id: message_id,
        additional_information: additional_information
      }.compact
    end
  end

  # The full registration record of an RCS agent: its basics, campaign,
  # testing details, test devices and review state. +status+ is the send
  # status also shown by {RcsAgentsResource#list} ("draft", "submitted",
  # "testing", "approved", "suspended"); +review_status+ tracks the
  # registration itself, one of {RcsRegistration::REVIEW_STATUSES}, and
  # +customer_stage+ summarises both with the brand as one of
  # {RcsRegistration::CUSTOMER_STAGES}. +review_note+ carries Sendly's
  # note when changes are requested and +rejection_reason+ the carrier
  # network's reason when it rejects the agent.
  class RcsAgentRegistration
    USE_CASES = %w[MULTI_USE PROMOTIONAL TRANSACTIONAL OTP].freeze

    attr_reader :id, :brand_id, :status, :review_status, :customer_stage,
                :display_name, :use_case, :hosting_region, :basics,
                :campaign, :testing, :review_note, :rejection_reason,
                :test_devices, :submitted_for_review_at,
                :basics_submitted_at, :launch_submitted_at, :live_at,
                :created_at, :updated_at

    def initialize(data)
      @id = data["id"]
      @brand_id = data["brandId"] || data["brand_id"]
      @status = data["status"]
      @review_status = data["reviewStatus"] || data["review_status"]
      @customer_stage = data["customerStage"] || data["customer_stage"]
      @display_name = data["displayName"] || data["display_name"]
      @use_case = data["useCase"] || data["use_case"]
      @hosting_region = data["hostingRegion"] || data["hosting_region"]
      @basics = data["basics"] ? RcsAgentBasics.new(data["basics"]) : nil
      @campaign = data["campaign"] ? RcsAgentCampaign.new(data["campaign"]) : nil
      @testing = data["testing"] ? RcsAgentTesting.new(data["testing"]) : nil
      @review_note = data["reviewNote"] || data["review_note"]
      @rejection_reason = data["rejectionReason"] || data["rejection_reason"]
      devices = data["testDevices"] || data["test_devices"] || []
      @test_devices = devices.map { |d| RcsTestDevice.new(d) }
      @submitted_for_review_at = data["submittedForReviewAt"] || data["submitted_for_review_at"]
      @basics_submitted_at = data["basicsSubmittedAt"] || data["basics_submitted_at"]
      @launch_submitted_at = data["launchSubmittedAt"] || data["launch_submitted_at"]
      @live_at = data["liveAt"] || data["live_at"]
      @created_at = data["createdAt"] || data["created_at"]
      @updated_at = data["updatedAt"] || data["updated_at"]
    end

    def draft?
      review_status == "draft"
    end

    def awaiting_review?
      review_status == "awaiting_review"
    end

    def changes_requested?
      review_status == "changes_requested"
    end

    def approved_for_carrier?
      review_status == "approved_for_carrier"
    end

    def launch_requested?
      review_status == "launch_requested"
    end

    def launch_rejected?
      review_status == "launch_rejected"
    end

    def rejected?
      review_status == "rejected"
    end

    # True while the agent reaches invited test devices only.
    def testing?
      status == "testing"
    end

    def live?
      customer_stage == "live"
    end

    # True while the agent's basics can still be edited and it can be
    # submitted for review.
    def editable?
      draft? || changes_requested?
    end

    def to_h
      {
        id: id, brand_id: brand_id, status: status,
        review_status: review_status, customer_stage: customer_stage,
        display_name: display_name, use_case: use_case,
        hosting_region: hosting_region, basics: basics&.to_h,
        campaign: campaign&.to_h, testing: testing&.to_h,
        review_note: review_note, rejection_reason: rejection_reason,
        test_devices: test_devices.map(&:to_h),
        submitted_for_review_at: submitted_for_review_at,
        basics_submitted_at: basics_submitted_at,
        launch_submitted_at: launch_submitted_at, live_at: live_at,
        created_at: created_at, updated_at: updated_at
      }.compact
    end
  end

  # The workspace's RCS registration at a glance: the newest agent, its
  # brand and test devices, and the +stage+ they are at together. +brand+
  # and +agent+ are nil until something has been drafted, and +stage+ is
  # then "draft". +us_eligible+ is false when something on file names a
  # non-US country.
  class RcsRegistration
    CUSTOMER_STAGES = %w[draft in_review changes_requested rejected brand_verification
                         agent_review testing launch_review launching launch_rejected
                         live suspended failed].freeze
    REVIEW_STATUSES = %w[draft awaiting_review changes_requested approved_for_carrier
                         rejected launch_requested launch_submitted launch_rejected
                         failed].freeze
    ERROR_CODES = %w[rcs_not_enabled rcs_not_found rcs_field_locked rcs_us_only
                     rcs_invalid_content rcs_brand_not_verified rcs_launch_not_ready
                     rcs_internal_error].freeze

    attr_reader :brand, :agent, :devices, :stage, :us_eligible

    def initialize(data)
      @brand = data["brand"] ? RcsBrand.new(data["brand"]) : nil
      @agent = data["agent"] ? RcsAgentRegistration.new(data["agent"]) : nil
      @devices = (data["devices"] || []).map { |d| RcsTestDevice.new(d) }
      @stage = data["stage"]
      @us_eligible = data.key?("usEligible") ? data["usEligible"] : data["us_eligible"]
    end

    def us_eligible?
      us_eligible == true
    end

    def live?
      stage == "live"
    end

    def to_h
      {
        brand: brand&.to_h, agent: agent&.to_h,
        devices: devices.map(&:to_h), stage: stage, us_eligible: us_eligible
      }.compact
    end
  end

  # Business details Sendly already holds for the workspace, ready to seed
  # an RCS brand. +brand+ is a snake_case hash of only the fields on file
  # (+legal_name+, +display_name+, +ein+, +organization_type+,
  # +website_url+, +address+, +contact+), so it can be passed straight to
  # {RcsBrandsResource#create} with +**dossier.brand+. +source+ says where
  # the details came from: "tendlc" (the workspace's newest 10DLC brand),
  # "verification" (its active toll-free verification) or "none".
  class RcsDossier
    SOURCES = %w[tendlc verification none].freeze

    attr_reader :brand, :us_eligible, :source

    def initialize(data)
      @brand = RcsRegistrationInput.underscore(data["brand"] || {})
      @us_eligible = data.key?("usEligible") ? data["usEligible"] : data["us_eligible"]
      @source = data["source"]
    end

    def us_eligible?
      us_eligible == true
    end

    def prefilled?
      !brand.empty?
    end

    def to_h
      { brand: brand, us_eligible: us_eligible, source: source }.compact
    end
  end

  # Read the workspace's RCS registration as a whole.
  class RcsRegistrationResource
    def initialize(client)
      @client = client
    end

    # Fetch the registration: the newest agent, its brand and test devices,
    # and the stage they are at. Requires the +rcs:read+ scope.
    #
    # @return [RcsRegistration]
    #
    # @example
    #   reg = client.rcs.registration.get
    #   puts reg.stage                # "draft" until something is submitted
    #   puts reg.agent&.review_status # e.g. "awaiting_review"
    def get
      response = @client.get("/rcs/registration")
      RcsRegistration.new(response)
    end
  end

  # Business details already on file, to seed an RCS brand from.
  class RcsDossierResource
    def initialize(client)
      @client = client
    end

    # Fetch the details Sendly already holds for this workspace (from its
    # 10DLC brand or toll-free verification), compacted to the fields that
    # are set. Requires the +rcs:read+ scope.
    #
    # @return [RcsDossier]
    #
    # @example Seed a brand from the dossier
    #   dossier = client.rcs.dossier.get
    #   brand = client.rcs.brands.create(**dossier.brand) if dossier.prefilled?
    def get
      response = @client.get("/rcs/dossier")
      RcsDossier.new(response)
    end
  end

  # Draft and edit the business behind your RCS agents.
  class RcsBrandsResource
    def initialize(client)
      @client = client
    end

    # Draft a brand. Every field is optional here; required fields are
    # checked when an agent under the brand is submitted for review. The
    # address must be in the US. Requires the +rcs:write+ scope.
    #
    # Nested hashes accept snake_case or camelCase keys.
    #
    # @param display_name [String, nil] The brand name recipients see
    # @param legal_name [String, nil] Registered legal name
    # @param legal_entity_type [String, nil] One of {RcsBrand::LEGAL_ENTITY_TYPES}
    # @param organization_type [String, nil] One of {RcsBrand::ORGANIZATION_TYPES}
    # @param website_url [String, nil] Public https website
    # @param ein [String, nil] Employer identification number ("12-3456789" or "123456789")
    # @param stock_symbol [String, nil] "EXCHANGE:TICKER" for public companies
    # @param address [Hash, nil] +{ line1:, line2:, city:, state:, postal_code:, country_code: "US" }+
    # @param contact [Hash, nil] +{ first_name:, last_name:, title:, email:, phone_number: }+ (E.164 phone)
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [RcsBrand]
    # @raise [Sendly::ValidationError] HTTP 422 +rcs_us_only+ when the address is outside the US
    #
    # @example
    #   brand = client.rcs.brands.create(
    #     display_name: "Acme Coffee",
    #     legal_name: "Acme Holdings LLC",
    #     legal_entity_type: "LIMITED_LIABILITY_COMPANY",
    #     organization_type: "PRIVATE_PROFIT",
    #     website_url: "https://acme.example",
    #     ein: "12-3456789",
    #     address: { line1: "1 Main St", city: "Austin", state: "TX",
    #                postal_code: "78701", country_code: "US" },
    #     contact: { first_name: "Sam", last_name: "Lee", email: "sam@acme.example",
    #                phone_number: "+15551234567" }
    #   )
    def create(display_name: nil, legal_name: nil, legal_entity_type: nil,
               organization_type: nil, website_url: nil, ein: nil,
               stock_symbol: nil, address: nil, contact: nil,
               idempotency_key: nil)
      body = {}
      body[:displayName] = display_name unless display_name.nil?
      body[:legalName] = legal_name unless legal_name.nil?
      body[:legalEntityType] = legal_entity_type unless legal_entity_type.nil?
      body[:organizationType] = organization_type unless organization_type.nil?
      body[:websiteUrl] = website_url unless website_url.nil?
      body[:ein] = ein unless ein.nil?
      body[:stockSymbol] = stock_symbol unless stock_symbol.nil?
      body[:address] = RcsRegistrationInput.camelize(address) unless address.nil?
      body[:contact] = RcsRegistrationInput.camelize(contact) unless contact.nil?

      response = @client.post("/rcs/brands", body, idempotency_key: idempotency_key)
      RcsBrand.new(response["brand"] || {})
    end

    # Edit a brand that is still editable (draft or changes requested).
    # Only the fields you pass are changed; pass +nil+ to clear a nullable
    # field. +address+ and +contact+ may be partial hashes. Requires the
    # +rcs:write+ scope.
    #
    # @param id [String] Brand identifier
    # @param display_name [String, nil]
    # @param legal_name [String, nil]
    # @param legal_entity_type [String, nil] One of {RcsBrand::LEGAL_ENTITY_TYPES}
    # @param organization_type [String, nil] One of {RcsBrand::ORGANIZATION_TYPES}
    # @param website_url [String, nil]
    # @param ein [String, nil]
    # @param stock_symbol [String, nil]
    # @param address [Hash, nil] Partial address; +country_code+, when present, must be "US"
    # @param contact [Hash, nil] Partial contact
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [RcsBrand] The updated brand
    # @raise [Sendly::ValidationError] If no field is given, or HTTP 422
    #   (+rcs_us_only+, +rcs_invalid_content+ with +field_errors+)
    # @raise [Sendly::NotFoundError] HTTP 404 +rcs_not_found+ when the brand isn't in this workspace
    # @raise [Sendly::APIError] HTTP 409 +rcs_field_locked+ while the brand is under review
    #
    # @example
    #   client.rcs.brands.update(brand.id, website_url: "https://acme.example",
    #                                      address: { line2: "Suite 4" })
    def update(id, display_name: RcsRegistrationInput::OMIT,
               legal_name: RcsRegistrationInput::OMIT,
               legal_entity_type: RcsRegistrationInput::OMIT,
               organization_type: RcsRegistrationInput::OMIT,
               website_url: RcsRegistrationInput::OMIT,
               ein: RcsRegistrationInput::OMIT,
               stock_symbol: RcsRegistrationInput::OMIT,
               address: RcsRegistrationInput::OMIT,
               contact: RcsRegistrationInput::OMIT,
               idempotency_key: nil)
      encoded_id = RcsRegistrationInput.encode_id!(id, "Brand ID")

      body = {}
      body[:displayName] = display_name unless RcsRegistrationInput.omitted?(display_name)
      body[:legalName] = legal_name unless RcsRegistrationInput.omitted?(legal_name)
      body[:legalEntityType] = legal_entity_type unless RcsRegistrationInput.omitted?(legal_entity_type)
      body[:organizationType] = organization_type unless RcsRegistrationInput.omitted?(organization_type)
      body[:websiteUrl] = website_url unless RcsRegistrationInput.omitted?(website_url)
      body[:ein] = ein unless RcsRegistrationInput.omitted?(ein)
      body[:stockSymbol] = stock_symbol unless RcsRegistrationInput.omitted?(stock_symbol)
      body[:address] = RcsRegistrationInput.camelize(address) unless RcsRegistrationInput.omitted?(address)
      body[:contact] = RcsRegistrationInput.camelize(contact) unless RcsRegistrationInput.omitted?(contact)
      raise ValidationError, "Provide at least one brand field to update" if body.empty?

      response = @client.patch("/rcs/brands/#{encoded_id}", body, idempotency_key: idempotency_key)
      RcsBrand.new(response["brand"] || {})
    end
  end

  # Draft, edit, test, submit and launch the RCS agents registered for
  # your workspace, and list them.
  class RcsAgentsResource
    def initialize(client)
      @client = client
    end

    # List your RCS agents, newest first. An empty list means no agent has
    # been drafted yet: register one with {#create} or from the dashboard.
    # +stage+ on each agent is its registration stage.
    #
    # @return [Hash] +{ agents: Array<RcsAgent> }+
    #
    # @example
    #   client.rcs.agents.list[:agents].each do |a|
    #     puts "#{a.name} — #{a.status}#{a.sendable? ? ' (sendable)' : ''}"
    #   end
    def list
      response = @client.get("/rcs/agents")
      agents = (response["agents"] || []).map { |a| RcsAgent.new(a) }
      { agents: agents }
    end

    # Draft an agent under a brand. Everything but +brand_id+ is optional
    # here; required fields are checked when you {#submit}. Nested hashes
    # accept snake_case or camelCase keys. Logo, hero and call-to-action
    # media must already be public https URLs: assets cannot be uploaded
    # over the API, only from the dashboard. Requires the +rcs:write+ scope.
    #
    # @param brand_id [String] The brand this agent belongs to
    # @param display_name [String, nil] The agent name recipients see
    # @param use_case [String, nil] One of {RcsAgentRegistration::USE_CASES}
    # @param basics [Hash, nil] +{ description:, logo_url:, hero_url:, brand_color:,
    #   privacy_policy_url:, terms_and_conditions_url:, phone_number: { number:, label: },
    #   website: { url:, label: }, email: { address:, label: } }+
    # @param campaign [Hash, nil] +{ company_overview:, agent_overview:, additional_information:,
    #   interactions: [{ interaction_type:, description: }], message_examples: [...],
    #   consent_settings: { opt_in_methods: [{ method_type:, description: }], call_to_action:,
    #   call_to_action_url:, call_to_action_media_url:, double_opt_in:, double_opt_in_message:,
    #   opt_in_message:, help_response:, opt_out_response: } }+
    # @param testing [Hash, nil] +{ test_url:, message_id:, additional_information: }+
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [RcsAgentRegistration]
    # @raise [Sendly::NotFoundError] HTTP 404 +rcs_not_found+ when the brand isn't in this workspace
    # @raise [Sendly::ValidationError] HTTP 422 +rcs_invalid_content+ (see +field_errors+)
    #
    # @example
    #   agent = client.rcs.agents.create(
    #     brand_id: brand.id,
    #     display_name: "Acme Coffee",
    #     use_case: "MULTI_USE",
    #     basics: {
    #       description: "Order updates and offers from Acme Coffee",
    #       logo_url: "https://acme.example/rcs/logo.png",
    #       hero_url: "https://acme.example/rcs/hero.png",
    #       brand_color: "#5B3A29",
    #       privacy_policy_url: "https://acme.example/privacy",
    #       terms_and_conditions_url: "https://acme.example/terms",
    #       phone_number: { number: "+15551234567", label: "Support" }
    #     }
    #   )
    def create(brand_id:, display_name: nil, use_case: nil, basics: nil,
               campaign: nil, testing: nil, idempotency_key: nil)
      raise ValidationError, "brand_id is required" if brand_id.nil? || brand_id.to_s.empty?

      body = { brandId: brand_id }
      body[:displayName] = display_name unless display_name.nil?
      body[:useCase] = use_case unless use_case.nil?
      body[:basics] = RcsRegistrationInput.camelize(basics) unless basics.nil?
      body[:campaign] = RcsRegistrationInput.camelize(campaign) unless campaign.nil?
      body[:testing] = RcsRegistrationInput.camelize(testing) unless testing.nil?

      response = @client.post("/rcs/agents", body, idempotency_key: idempotency_key)
      RcsAgentRegistration.new(response["agent"] || {})
    end

    # Fetch one agent's full registration record, including its test
    # devices and review state. Requires the +rcs:read+ scope.
    #
    # @param id [String] Agent identifier
    # @return [RcsAgentRegistration]
    # @raise [Sendly::NotFoundError] HTTP 404 +rcs_not_found+ when the agent isn't in this workspace
    #
    # @example
    #   agent = client.rcs.agents.get("rca_abc123")
    #   puts agent.customer_stage
    #   puts agent.review_note if agent.changes_requested?
    def get(id)
      encoded_id = RcsRegistrationInput.encode_id!(id, "Agent ID")
      response = @client.get("/rcs/agents/#{encoded_id}")
      RcsAgentRegistration.new(response["agent"] || {})
    end

    # Edit an agent that is still editable. Only the groups you pass are
    # changed: +display_name+, +use_case+ and +basics+ are merged into the
    # basics, +campaign+ and +testing+ are merged section-wise, and
    # +campaign: nil+ or +testing: nil+ clears that section. The same
    # public-https rule applies to logo, hero and call-to-action media.
    # Requires the +rcs:write+ scope.
    #
    # @param id [String] Agent identifier
    # @param display_name [String, nil]
    # @param use_case [String, nil] One of {RcsAgentRegistration::USE_CASES}
    # @param basics [Hash, nil] Partial basics (see {#create})
    # @param campaign [Hash, nil] Partial campaign, or +nil+ to clear it
    # @param testing [Hash, nil] Partial testing details, or +nil+ to clear them
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [RcsAgentRegistration] The updated agent
    # @raise [Sendly::ValidationError] If no field is given, or HTTP 422
    #   +rcs_invalid_content+ (see +field_errors+)
    # @raise [Sendly::NotFoundError] HTTP 404 +rcs_not_found+
    # @raise [Sendly::APIError] HTTP 409 +rcs_field_locked+ while the agent is under review
    #
    # @example
    #   client.rcs.agents.update(agent.id,
    #     campaign: {
    #       agent_overview: "Order updates, delivery alerts and support replies",
    #       interactions: [{ interaction_type: "TRANSACTIONAL_UPDATES",
    #                        description: "Order and delivery status" }],
    #       message_examples: ["Your order #4821 has shipped!",
    #                          "Your barista is ready for pickup",
    #                          "Reply HELP for support or STOP to opt out"]
    #     }
    #   )
    def update(id, display_name: RcsRegistrationInput::OMIT,
               use_case: RcsRegistrationInput::OMIT,
               basics: RcsRegistrationInput::OMIT,
               campaign: RcsRegistrationInput::OMIT,
               testing: RcsRegistrationInput::OMIT,
               idempotency_key: nil)
      encoded_id = RcsRegistrationInput.encode_id!(id, "Agent ID")

      body = {}
      body[:displayName] = display_name unless RcsRegistrationInput.omitted?(display_name)
      body[:useCase] = use_case unless RcsRegistrationInput.omitted?(use_case)
      body[:basics] = RcsRegistrationInput.camelize(basics) unless RcsRegistrationInput.omitted?(basics)
      body[:campaign] = RcsRegistrationInput.camelize(campaign) unless RcsRegistrationInput.omitted?(campaign)
      body[:testing] = RcsRegistrationInput.camelize(testing) unless RcsRegistrationInput.omitted?(testing)
      raise ValidationError, "Provide at least one agent field to update" if body.empty?

      response = @client.patch("/rcs/agents/#{encoded_id}", body, idempotency_key: idempotency_key)
      RcsAgentRegistration.new(response["agent"] || {})
    end

    # Replace the agent's test devices: the phones that can receive its
    # messages while it is in testing. The list is authoritative, so
    # numbers left out are removed and new ones are invited. Up to 20
    # devices. Requires the +rcs:write+ scope.
    #
    # @param id [String] Agent identifier
    # @param devices [Array<String, Hash>] E.164 numbers, or
    #   +{ phone_number:, label: }+ hashes
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [Hash] +{ devices: Array<RcsTestDevice> }+ — the full list after the change
    # @raise [Sendly::ValidationError] If +devices+ isn't an array, or HTTP 422
    #   +rcs_invalid_content+ (bad number, more than 20 devices)
    # @raise [Sendly::APIError] HTTP 409 +rcs_field_locked+ while the agent is under review
    #
    # @example
    #   client.rcs.agents.set_test_devices(agent.id, devices: [
    #     { phone_number: "+15551234567", label: "Sam's Pixel" },
    #     "+15557654321"
    #   ])
    def set_test_devices(id, devices:, idempotency_key: nil)
      encoded_id = RcsRegistrationInput.encode_id!(id, "Agent ID")
      raise ValidationError, "devices must be an array" unless devices.is_a?(Array)

      body = {
        devices: devices.map do |device|
          device.is_a?(Hash) ? RcsRegistrationInput.camelize(device) : { phoneNumber: device }
        end
      }
      response = @client.put("/rcs/agents/#{encoded_id}/test-devices", body,
                             idempotency_key: idempotency_key)
      list = (response["devices"] || []).map { |d| RcsTestDevice.new(d) }
      { devices: list }
    end

    # Submit the agent and its brand for Sendly's review. Once approved
    # they go on to the carrier network for brand verification and agent
    # review; watch +customer_stage+ with {#get}. Requires the +rcs:write+
    # scope.
    #
    # Pass your own +idempotency_key+ if you may retry: a replay returns
    # the original response without submitting again.
    #
    # @param id [String] Agent identifier
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [RcsAgentRegistration] The agent, now +awaiting_review?+
    # @raise [Sendly::ValidationError] HTTP 422 +rcs_invalid_content+ when the
    #   brand or agent basics are incomplete (+field_errors+ lists
    #   +brand.<field>+ / +agent.<field>+ paths)
    # @raise [Sendly::APIError] HTTP 409 +rcs_field_locked+ when already
    #   submitted, or +rcs_brand_not_verified+ when the brand failed verification
    #
    # @example
    #   agent = client.rcs.agents.submit(agent.id, idempotency_key: "rcs-submit-#{agent.id}")
    #   puts agent.review_status # "awaiting_review"
    def submit(id, idempotency_key: nil)
      encoded_id = RcsRegistrationInput.encode_id!(id, "Agent ID")
      response = @client.post("/rcs/agents/#{encoded_id}/submit", {}, idempotency_key: idempotency_key)
      RcsAgentRegistration.new(response["agent"] || {})
    end

    # Ask to launch an agent that has been tested on an invited device.
    # Sendly reviews the campaign and testing details, then sends the
    # launch on to the carrier network. Requires the +rcs:write+ scope.
    #
    # @param id [String] Agent identifier
    # @param test_url [String, nil] Where the test conversation can be seen; stored
    #   into the agent's testing details first
    # @param testing_additional_information [String, nil] Anything else the
    #   reviewer should know about the test
    # @param idempotency_key [String, nil] Idempotency key for this operation
    # @return [RcsAgentRegistration] The agent, now +launch_requested?+
    # @raise [Sendly::ValidationError] HTTP 422 +rcs_invalid_content+ when the
    #   campaign or testing details are incomplete (+field_errors+ lists
    #   +campaign.<field>+ / +testing.<field>+ paths)
    # @raise [Sendly::APIError] HTTP 409 +rcs_launch_not_ready+ until the agent
    #   is in testing, or +rcs_field_locked+ while a request is pending
    #
    # @example
    #   client.rcs.agents.request_launch(agent.id,
    #     test_url: "https://acme.example/rcs-test",
    #     testing_additional_information: "Tested on two invited devices"
    #   )
    def request_launch(id, test_url: nil, testing_additional_information: nil,
                       idempotency_key: nil)
      encoded_id = RcsRegistrationInput.encode_id!(id, "Agent ID")

      body = {}
      body[:testUrl] = test_url unless test_url.nil?
      body[:testingAdditionalInformation] = testing_additional_information unless testing_additional_information.nil?

      response = @client.post("/rcs/agents/#{encoded_id}/request-launch", body,
                              idempotency_key: idempotency_key)
      RcsAgentRegistration.new(response["agent"] || {})
    end
  end

  # RCS resource — register your RCS agent, discover your agents and
  # pre-flight recipient capability.
  #
  # RCS is a first-class Sendly channel: send branded rich messages — text
  # with suggested replies and actions, or rich cards — via
  # +client.messages.send(channel: "rcs", ...)+.
  #
  # Registration is self-serve, from the dashboard or this API: draft the
  # brand ({RcsBrandsResource#create}) and the agent
  # ({RcsAgentsResource#create}), submit them for Sendly's review
  # ({RcsAgentsResource#submit}), and once approved they go on to the
  # carrier network for brand verification and agent review. The agent
  # then reaches invited test devices only
  # ({RcsAgentsResource#set_test_devices}); when you have tested it,
  # {RcsAgentsResource#request_launch} asks Sendly to review the campaign
  # and send the launch on to the carrier network. {RcsRegistrationResource#get}
  # shows where the registration is, and {RcsDossierResource#get} seeds
  # the brand from details Sendly already holds. Logo, hero and
  # call-to-action media must be public https URLs; assets cannot be
  # uploaded over the API, only from the dashboard. Registration reads
  # need the +rcs:read+ scope and writes +rcs:write+.
  #
  # Delivery is per-recipient: not every device or network supports RCS.
  # Text messages fall back to plain SMS automatically (billed as SMS)
  # unless you pass +fallback_to_sms: false+; rich cards have no SMS form
  # and only deliver to RCS-capable recipients. Use {#capability} to check
  # a recipient before sending.
  #
  # RCS sends and capability checks require a live API key
  # (+sk_live_v1_xxx+).
  #
  # @example Check capability, then send
  #   cap = client.rcs.capability(to: "+15551234567")
  #   if cap.capable?
  #     client.messages.send(
  #       channel: "rcs",
  #       to: "+15551234567",
  #       text: "Your order has shipped!"
  #     )
  #   end
  class RcsResource
    # @return [RcsAgentsResource] Register and list agents
    attr_reader :agents

    # @return [RcsRegistrationResource] The registration at a glance
    attr_reader :registration

    # @return [RcsDossierResource] Business details on file, to seed a brand
    attr_reader :dossier

    # @return [RcsBrandsResource] Draft and edit brands
    attr_reader :brands

    def initialize(client)
      @client = client
      @agents = RcsAgentsResource.new(client)
      @registration = RcsRegistrationResource.new(client)
      @dossier = RcsDossierResource.new(client)
      @brands = RcsBrandsResource.new(client)
    end

    # Check whether a recipient can receive RCS.
    #
    # Probes the recipient's device and network. When the recipient is not
    # capable, a text send falls back to plain SMS (unless the fallback is
    # disabled) and a card send fails with
    # +rcs_not_supported_for_recipient+.
    #
    # @param to [String] The recipient's number, in E.164 format
    # @param agent_id [String, nil] The agent to probe with. Optional when
    #   your workspace has exactly one sendable agent; required (the API
    #   responds 400 +rcs_agent_ambiguous+) when it has more.
    # @return [RcsCapability]
    #
    # @example
    #   cap = client.rcs.capability(to: "+15551234567")
    #   puts cap.capable?
    #   puts cap.features.inspect
    def capability(to:, agent_id: nil)
      raise ValidationError, "to is required" if to.nil? || to.to_s.empty?

      params = { to: to }
      params[:agentId] = agent_id if agent_id
      response = @client.get("/rcs/capability", params)
      RcsCapability.new(response)
    end
  end
end
