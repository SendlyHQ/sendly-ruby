# frozen_string_literal: true

module Sendly
  # A business identity registered for carrier review. The status starts
  # +"pending"+ and moves to +"verified"+ (campaigns can be created) or
  # +"failed"+ (see +failure_reasons+).
  class TenDlcBrand
    attr_reader :id, :legal_name, :dba, :entity_type, :ein, :vertical,
                :website, :status, :identity_status, :failure_reasons,
                :created_at, :updated_at

    def initialize(data)
      @id = data["id"]
      @legal_name = data["legalName"] || data["legal_name"]
      @dba = data["dba"]
      @entity_type = data["entityType"] || data["entity_type"]
      @ein = data["ein"]
      @vertical = data["vertical"]
      @website = data["website"]
      @status = data["status"]
      @identity_status = data["identityStatus"] || data["identity_status"]
      @failure_reasons = data["failureReasons"] || data["failure_reasons"]
      @created_at = data["createdAt"] || data["created_at"]
      @updated_at = data["updatedAt"] || data["updated_at"]
    end

    def pending?
      status == "pending"
    end

    def verified?
      status == "verified"
    end

    def failed?
      status == "failed"
    end

    def to_h
      {
        id: id, legal_name: legal_name, dba: dba, entity_type: entity_type,
        ein: ein, vertical: vertical, website: website, status: status,
        identity_status: identity_status, failure_reasons: failure_reasons,
        created_at: created_at, updated_at: updated_at
      }.compact
    end
  end

  # Messaging throughput granted by the carrier network.
  class TenDlcThroughput
    attr_reader :tier, :carriers_ready

    def initialize(data)
      @tier = data["tier"]
      @carriers_ready = data["carriersReady"] || data["carriers_ready"]
    end

    def to_h
      { tier: tier, carriers_ready: carriers_ready }.compact
    end
  end

  # The result of a use-case qualification pre-check. When +qualified+ is
  # false, +reason+ explains why; +throughput+ carries the expected tier
  # when the carrier network reports it.
  class TenDlcQualifyResult
    attr_reader :use_case, :qualified, :reason, :throughput

    def initialize(data)
      @use_case = data["useCase"] || data["use_case"]
      @qualified = data["qualified"]
      @reason = data["reason"]
      @throughput = data["throughput"] ? TenDlcThroughput.new(data["throughput"]) : nil
    end

    def qualified?
      qualified == true
    end

    def to_h
      {
        use_case: use_case, qualified: qualified, reason: reason,
        throughput: throughput&.to_h
      }.compact
    end
  end

  # A messaging campaign registered for carrier review. The status starts
  # +"pending"+ and moves to +"active"+ (numbers can be assigned) or
  # +"failed"+ (see +failure_reasons+); the carrier network may later mark
  # it +"suspended"+ or +"expired"+.
  class TenDlcCampaign
    attr_reader :id, :brand_id, :use_case, :sub_use_cases, :description,
                :status, :sample_messages, :throughput, :failure_reasons,
                :created_at, :updated_at

    def initialize(data)
      @id = data["id"]
      @brand_id = data["brandId"] || data["brand_id"]
      @use_case = data["useCase"] || data["use_case"]
      @sub_use_cases = data["subUseCases"] || data["sub_use_cases"] || []
      @description = data["description"]
      @status = data["status"]
      @sample_messages = data["sampleMessages"] || data["sample_messages"] || []
      @throughput = data["throughput"] ? TenDlcThroughput.new(data["throughput"]) : nil
      @failure_reasons = data["failureReasons"] || data["failure_reasons"]
      @created_at = data["createdAt"] || data["created_at"]
      @updated_at = data["updatedAt"] || data["updated_at"]
    end

    def pending?
      status == "pending"
    end

    def active?
      status == "active"
    end

    def failed?
      status == "failed"
    end

    def to_h
      {
        id: id, brand_id: brand_id, use_case: use_case,
        sub_use_cases: sub_use_cases, description: description,
        status: status, sample_messages: sample_messages,
        throughput: throughput&.to_h, failure_reasons: failure_reasons,
        created_at: created_at, updated_at: updated_at
      }.compact
    end
  end

  # A phone number assigned to a campaign. The number can send once the
  # status is +"Active"+.
  class TenDlcAssignment
    attr_reader :id, :campaign_id, :phone_number, :status, :assigned_at

    def initialize(data)
      @id = data["id"]
      @campaign_id = data["campaignId"] || data["campaign_id"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @status = data["status"]
      @assigned_at = data["assignedAt"] || data["assigned_at"]
    end

    def active?
      status == "Active"
    end

    def to_h
      {
        id: id, campaign_id: campaign_id, phone_number: phone_number,
        status: status, assigned_at: assigned_at
      }.compact
    end
  end

  # 10DLC resource — register your business for carrier review so you can
  # text from local (10-digit) US numbers. The flow has three steps:
  #
  # 1. Register a brand with {#create_brand}, then poll {#get_brand} until
  #    it is verified.
  # 2. Create a campaign under the verified brand with {#create_campaign},
  #    then poll {#get_campaign} until it is active. {#qualify} pre-checks
  #    a use case before you create the campaign.
  # 3. Attach a number you own with {#assign_number}. Once the assignment
  #    is "Active", the number can send.
  #
  # Writes require a live API key with the +tendlc:write+ scope.
  #
  # @example Register a brand and poll until it's verified
  #   brand = client.ten_dlc.create_brand(
  #     legal_name: "Acme Holdings LLC",
  #     ein: "12-3456789",
  #     website: "https://acme.example",
  #     email: "ops@acme.example"
  #   )
  #   # ...poll client.ten_dlc.get_brand(brand.id) until brand.verified?
  #
  # @example Pre-check the use case, then create a campaign
  #   check = client.ten_dlc.qualify(brand.id, "MIXED")
  #   if check.qualified?
  #     campaign = client.ten_dlc.create_campaign(
  #       brand_id: brand.id,
  #       use_case: "MIXED",
  #       description: "Order updates and support replies for Acme customers",
  #       message_flow: "Customers opt in at checkout on acme.example",
  #       sample_messages: ["Your order #123 has shipped!"]
  #     )
  #     # ...poll client.ten_dlc.get_campaign(campaign.id) until campaign.active?
  #   end
  #
  # @example Assign a number you own
  #   client.ten_dlc.assign_number(campaign.id, phone_number: "+15551234567")
  class TenDlcResource
    def initialize(client)
      @client = client
    end

    # List the brands registered for carrier review.
    #
    # @return [Hash] +{ brands: Array<TenDlcBrand> }+
    def list_brands
      response = @client.get("/tendlc/brands")
      brands = (response["data"] || []).map { |b| TenDlcBrand.new(b) }
      { brands: brands }
    end

    # Register a brand for carrier review — step 1 of enabling local-number
    # texting. Requires a live API key.
    #
    # The brand starts pending. Poll {#get_brand} until it is verified
    # before creating a campaign.
    #
    # @param legal_name [String] Legal business name
    # @param dba [String, nil] "Doing business as" name, if different from the legal name
    # @param ein [String, nil] Business registration number (e.g. EIN)
    # @param entity_type [String, nil] Business entity type (e.g. "PRIVATE_PROFIT",
    #   "SOLE_PROPRIETOR"); the API defaults to "PRIVATE_PROFIT"
    # @param vertical [String, nil] Industry vertical
    # @param website [String, nil] Business website URL
    # @param email [String, nil] Business contact email
    # @param phone [String, nil] Business phone number
    # @param mobile_phone [String, nil] Business mobile phone number
    # @param street [String, nil] Street address
    # @param city [String, nil] City
    # @param state [String, nil] State or region
    # @param postal_code [String, nil] Postal code
    # @param country [String, nil] ISO 3166-1 alpha-2 country code; the API defaults to "US"
    # @param verification_id [String, nil] Existing Sendly verification to prefill
    #   business details from
    # @return [TenDlcBrand]
    def create_brand(legal_name:, dba: nil, ein: nil, entity_type: nil,
                     vertical: nil, website: nil, email: nil, phone: nil,
                     mobile_phone: nil, street: nil, city: nil, state: nil,
                     postal_code: nil, country: nil, verification_id: nil)
      raise ValidationError, "legal_name is required" if legal_name.nil? || legal_name.to_s.empty?

      body = { legalName: legal_name }
      body[:dba] = dba if dba
      body[:ein] = ein if ein
      body[:entityType] = entity_type if entity_type
      body[:vertical] = vertical if vertical
      body[:website] = website if website
      body[:email] = email if email
      body[:phone] = phone if phone
      body[:mobilePhone] = mobile_phone if mobile_phone
      body[:street] = street if street
      body[:city] = city if city
      body[:state] = state if state
      body[:postalCode] = postal_code if postal_code
      body[:country] = country if country
      body[:verificationId] = verification_id if verification_id

      response = @client.post("/tendlc/brands", body)
      TenDlcBrand.new(response["data"] || {})
    end

    # Fetch one brand. Also refreshes its carrier-review status, so polling
    # this method shows progress (pending -> verified/failed).
    #
    # @param id [String] Brand identifier
    # @return [TenDlcBrand]
    def get_brand(id)
      raise ValidationError, "Brand ID is required" if id.nil? || id.to_s.empty?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.get("/tendlc/brands/#{encoded_id}")
      TenDlcBrand.new(response["data"] || {})
    end

    # Pre-check whether a use case qualifies for a brand on the carrier
    # network before creating a campaign.
    #
    # @param brand_id [String] Brand identifier
    # @param use_case [String] Use-case code (e.g. "MIXED", "MARKETING",
    #   "ACCOUNT_NOTIFICATION", "2FA")
    # @return [TenDlcQualifyResult]
    def qualify(brand_id, use_case)
      raise ValidationError, "Brand ID is required" if brand_id.nil? || brand_id.to_s.empty?
      raise ValidationError, "use_case is required" if use_case.nil? || use_case.to_s.empty?

      encoded_id = URI.encode_www_form_component(brand_id)
      encoded_use_case = URI.encode_www_form_component(use_case)
      response = @client.get("/tendlc/brands/#{encoded_id}/qualify/#{encoded_use_case}")
      TenDlcQualifyResult.new(response["data"] || {})
    end

    # List your messaging campaigns.
    #
    # @return [Hash] +{ campaigns: Array<TenDlcCampaign> }+
    def list_campaigns
      response = @client.get("/tendlc/campaigns")
      campaigns = (response["data"] || []).map { |c| TenDlcCampaign.new(c) }
      { campaigns: campaigns }
    end

    # Create a messaging campaign under a verified brand and submit it for
    # carrier review. Requires a live API key.
    #
    # The campaign starts pending. Poll {#get_campaign} until it is active
    # before assigning numbers.
    #
    # @param brand_id [String] The verified brand to create the campaign under
    # @param use_case [String] Primary use-case code (e.g. "MIXED", "MARKETING")
    # @param description [String] What the campaign sends and why
    # @param message_flow [String] How recipients opt in to receive messages
    # @param sample_messages [Array<String>] Example messages the campaign sends
    #   (the first 5 are used)
    # @param sub_use_cases [Array<String>, nil] Sub-use-case codes
    # @param opt_in_keywords [String, nil] Comma-separated keywords that opt a recipient in
    # @param opt_out_keywords [String, nil] Comma-separated keywords that opt a recipient out
    # @param help_keywords [String, nil] Comma-separated keywords that request help
    # @param opt_in_message [String, nil] Auto-reply sent on opt-in
    # @param opt_out_message [String, nil] Auto-reply sent on opt-out
    # @param help_message [String, nil] Auto-reply sent on a help request
    # @param embedded_link [Boolean, nil] Whether messages may contain links;
    #   the API defaults to true
    # @param embedded_phone [Boolean, nil] Whether messages may contain phone
    #   numbers; the API defaults to false
    # @return [TenDlcCampaign]
    def create_campaign(brand_id:, use_case:, description:, message_flow:,
                        sample_messages:, sub_use_cases: nil,
                        opt_in_keywords: nil, opt_out_keywords: nil,
                        help_keywords: nil, opt_in_message: nil,
                        opt_out_message: nil, help_message: nil,
                        embedded_link: nil, embedded_phone: nil)
      raise ValidationError, "brand_id is required" if brand_id.nil? || brand_id.to_s.empty?
      raise ValidationError, "use_case is required" if use_case.nil? || use_case.to_s.empty?
      raise ValidationError, "description is required" if description.nil? || description.to_s.empty?
      raise ValidationError, "message_flow is required" if message_flow.nil? || message_flow.to_s.empty?
      raise ValidationError, "sample_messages is required" if sample_messages.nil? || sample_messages.empty?

      body = {
        brandId: brand_id,
        useCase: use_case,
        description: description,
        messageFlow: message_flow,
        sampleMessages: sample_messages
      }
      body[:subUseCases] = sub_use_cases if sub_use_cases
      body[:optInKeywords] = opt_in_keywords if opt_in_keywords
      body[:optOutKeywords] = opt_out_keywords if opt_out_keywords
      body[:helpKeywords] = help_keywords if help_keywords
      body[:optInMessage] = opt_in_message if opt_in_message
      body[:optOutMessage] = opt_out_message if opt_out_message
      body[:helpMessage] = help_message if help_message
      body[:embeddedLink] = embedded_link unless embedded_link.nil?
      body[:embeddedPhone] = embedded_phone unless embedded_phone.nil?

      response = @client.post("/tendlc/campaigns", body)
      TenDlcCampaign.new(response["data"] || {})
    end

    # Fetch one campaign. Also refreshes its carrier-review status, so
    # polling this method shows progress (pending -> active) including
    # throughput once carriers approve.
    #
    # @param id [String] Campaign identifier
    # @return [TenDlcCampaign]
    def get_campaign(id)
      raise ValidationError, "Campaign ID is required" if id.nil? || id.to_s.empty?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.get("/tendlc/campaigns/#{encoded_id}")
      TenDlcCampaign.new(response["data"] || {})
    end

    # Assign a phone number you own to an active (carrier-approved)
    # campaign, making the number sendable. Requires a live API key.
    #
    # Idempotent — re-assigning the same number to the same campaign
    # returns the existing assignment.
    #
    # @param campaign_id [String] Campaign identifier
    # @param phone_number [String] E.164 number the workspace already owns
    # @return [TenDlcAssignment] The number can send once its status is "Active"
    def assign_number(campaign_id, phone_number:)
      raise ValidationError, "Campaign ID is required" if campaign_id.nil? || campaign_id.to_s.empty?
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?

      encoded_id = URI.encode_www_form_component(campaign_id)
      response = @client.post("/tendlc/campaigns/#{encoded_id}/assign", { phoneNumber: phone_number })
      TenDlcAssignment.new(response["data"] || {})
    end

    # List your number-to-campaign assignments.
    #
    # @return [Hash] +{ assignments: Array<TenDlcAssignment> }+
    def list_assignments
      response = @client.get("/tendlc/assignments")
      assignments = (response["data"] || []).map { |a| TenDlcAssignment.new(a) }
      { assignments: assignments }
    end
  end
end
