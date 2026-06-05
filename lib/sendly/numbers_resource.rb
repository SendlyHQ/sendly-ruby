# frozen_string_literal: true

module Sendly
  # A country in which numbers can be searched and purchased, along with the
  # number types available there (e.g. "mobile", "local", "toll_free").
  class NumberCountry
    attr_reader :code, :name, :number_types

    def initialize(data)
      @code = data["code"]
      @name = data["name"]
      @number_types = data["numberTypes"] || data["number_types"] || []
    end

    def to_h
      { code: code, name: name, number_types: number_types }.compact
    end
  end

  # A number that is available to purchase. The monthly cost is already
  # customer-priced and returned as a string in the given currency.
  class AvailableNumber
    attr_reader :phone_number, :country, :number_type, :monthly_cost, :currency

    def initialize(data)
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @country = data["country"]
      @number_type = data["numberType"] || data["number_type"]
      @monthly_cost = data["monthlyCost"] || data["monthly_cost"]
      @currency = data["currency"]
    end

    def to_h
      {
        phone_number: phone_number, country: country,
        number_type: number_type, monthly_cost: monthly_cost,
        currency: currency
      }.compact
    end
  end

  # A number owned by the account.
  class PhoneNumber
    attr_reader :id, :phone_number, :status, :source, :country_code,
                :phone_number_type, :monthly_cost_cents,
                # ISO-8601 timestamp string, or nil when the number still needs
                # regulatory documents (a value means docs are under carrier review).
                :requirements_submitted_at,
                # true when the number is scheduled for release at period end.
                :pending_cancellation,
                # ISO-8601 timestamp string, or nil when no release is scheduled.
                :scheduled_release_at

    def initialize(data)
      @id = data["id"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @status = data["status"]
      @source = data["source"]
      @country_code = data["countryCode"] || data["country_code"]
      @phone_number_type = data["phoneNumberType"] || data["phone_number_type"]
      @monthly_cost_cents = data["monthlyCostCents"] || data["monthly_cost_cents"]
      @requirements_submitted_at = data["requirementsSubmittedAt"] || data["requirements_submitted_at"]
      @pending_cancellation = data.key?("pendingCancellation") ? data["pendingCancellation"] : data["pending_cancellation"]
      @scheduled_release_at = data["scheduledReleaseAt"] || data["scheduled_release_at"]
    end

    def to_h
      {
        id: id, phone_number: phone_number, status: status, source: source,
        country_code: country_code, phone_number_type: phone_number_type,
        monthly_cost_cents: monthly_cost_cents,
        requirements_submitted_at: requirements_submitted_at,
        pending_cancellation: pending_cancellation,
        scheduled_release_at: scheduled_release_at
      }.compact
    end
  end

  # The result of a buy request. The API responds 202 with one of three
  # statuses:
  #
  # - +"provisioning"+: the purchase succeeded and the number is being
  #   provisioned. +number+ carries the new {PhoneNumber}.
  # - +"documents_required"+ / +"payment_required"+: the purchase is paused
  #   pending a hosted Sendly step. +action+ carries the hand-off object,
  #   which holds TWO distinct identifiers:
  #   - +actionCode+ — a 32-hex action identifier (read via {#action_identifier}).
  #     Use THIS to poll the action and to re-call +buy+ (pass it as the
  #     +action_code:+ argument).
  #   - +code+ — a short user code (read via {#action_code}). DISPLAY ONLY:
  #     show it to the human to type on the hosted page to prove terminal
  #     access. Never pass it back as +action_code:+.
  #   Hand the user +action_url+ + {#action_code}, wait for completion, then
  #   re-call +buy+ with the same body plus +action_code:+ set to
  #   {#action_identifier}. +requirements+ describes what's missing (a JSON
  #   array).
  #
  # The raw parsed response is preserved verbatim on +#raw+ so callers can
  # read any field the server adds.
  class NumberPurchase
    attr_reader :status, :number, :requirements, :action, :raw

    def initialize(data)
      @raw = data
      @status = data["status"]
      @number = data["number"] ? PhoneNumber.new(data["number"]) : nil
      @requirements = data["requirements"]
      @action = data["action"]
    end

    def provisioning?
      status == "provisioning"
    end

    def documents_required?
      status == "documents_required"
    end

    def payment_required?
      status == "payment_required"
    end

    # @return [String, nil] The hosted Sendly page URL the user must visit.
    def action_url
      action && (action["url"] || action[:url])
    end

    # The 32-hex action identifier. Use THIS to poll the action's status and
    # to re-call +buy+ (pass it as the +action_code:+ argument). NOT for
    # display.
    #
    # @return [String, nil]
    def action_identifier
      action && (action["actionCode"] || action["action_code"] || action[:actionCode] || action[:action_code])
    end

    # The short user code shown to the human to type on the hosted page to
    # prove terminal access. DISPLAY ONLY — to re-buy/poll, use
    # {#action_identifier}, not this.
    #
    # @return [String, nil]
    def action_code
      action && (action["code"] || action[:code])
    end

    # Expiry of the action, as an epoch-milliseconds number (the server sends
    # a number, not an ISO-8601 string). Older payloads may carry it under
    # +expires_at+; both are accepted.
    #
    # @return [Integer, String, nil]
    def action_expires_at
      action && (action["expiresAt"] || action["expires_at"] || action[:expiresAt] || action[:expires_at])
    end

    def to_h
      {
        status: status, number: number&.to_h,
        requirements: requirements, action: action
      }.compact
    end
  end

  # Numbers resource — search, list, and purchase phone numbers.
  #
  # @example List supported countries
  #   result = client.numbers.list_countries
  #   result[:countries].each { |c| puts "#{c.code} #{c.name}" }
  #
  # @example Find available mobile numbers in the UK
  #   result = client.numbers.list_available(country: "GB", type: "mobile")
  #   number = result[:numbers].first
  #
  # @example Buy a number (may pause for a hosted step)
  #   purchase = client.numbers.buy(
  #     phone_number: number.phone_number,
  #     country_code: number.country,
  #     phone_number_type: number.number_type,
  #     monthly_cost: number.monthly_cost
  #   )
  #   if purchase.documents_required? || purchase.payment_required?
  #     # Show the user the URL + display code; keep the 32-hex identifier for re-buy
  #     puts "Visit #{purchase.action_url} and enter code #{purchase.action_code}"
  #     # ...once they finish, re-call buy with action_code: purchase.action_identifier
  #   end
  class NumbersResource
    def initialize(client)
      @client = client
    end

    # List the countries in which numbers can be searched and purchased,
    # along with the number types available in each.
    #
    # @return [Hash] +{ countries: Array<NumberCountry> }+
    def list_countries
      response = @client.get("/numbers/countries")
      countries = (response["countries"] || []).map { |c| NumberCountry.new(c) }
      { countries: countries }
    end

    # Search for numbers available to purchase in a country.
    #
    # @param country [String] ISO country code (e.g. "GB")
    # @param type [String] Number type (e.g. "mobile", "local", "toll_free")
    # @param contains [String, nil] Optional digit/letter filter
    # @return [Hash] +{ numbers: Array<AvailableNumber> }+
    def list_available(country:, type:, contains: nil)
      raise ValidationError, "country is required" if country.nil? || country.to_s.empty?
      raise ValidationError, "type is required" if type.nil? || type.to_s.empty?

      params = { country: country, type: type }
      params[:contains] = contains if contains

      response = @client.get("/numbers/available", params)
      numbers = (response["numbers"] || []).map { |n| AvailableNumber.new(n) }
      { numbers: numbers }
    end

    # List the numbers owned by the account.
    #
    # @return [Hash] +{ numbers: Array<PhoneNumber> }+
    def list
      response = @client.get("/numbers")
      numbers = (response["numbers"] || []).map { |n| PhoneNumber.new(n) }
      { numbers: numbers }
    end

    # Buy a number.
    #
    # Returns a {NumberPurchase}. When its status is +documents_required+ or
    # +payment_required+, hand the user +purchase.action_url+ +
    # +purchase.action_code+ (the short display code), wait for that hosted
    # step to complete, then re-call +buy+ with the SAME arguments plus
    # +action_code:+ set to +purchase.action_identifier+ (the 32-hex action
    # identifier) — NOT the display code.
    #
    # @param phone_number [String]
    # @param country_code [String]
    # @param phone_number_type [String]
    # @param monthly_cost [String] Customer-priced monthly cost (as returned by {#list_available})
    # @param action_code [String, nil] The 32-hex action identifier of a
    #   completed hosted action (see {NumberPurchase#action_identifier}), on re-call
    # @return [NumberPurchase]
    def buy(phone_number:, country_code:, phone_number_type:, monthly_cost:, action_code: nil)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?
      raise ValidationError, "country_code is required" if country_code.nil? || country_code.to_s.empty?
      raise ValidationError, "phone_number_type is required" if phone_number_type.nil? || phone_number_type.to_s.empty?
      raise ValidationError, "monthly_cost is required" if monthly_cost.nil? || monthly_cost.to_s.empty?

      body = {
        phoneNumber: phone_number,
        countryCode: country_code,
        phoneNumberType: phone_number_type,
        monthlyCost: monthly_cost
      }
      body[:actionCode] = action_code if action_code

      response = @client.post("/numbers/buy", body)
      NumberPurchase.new(response)
    end
  end
end
