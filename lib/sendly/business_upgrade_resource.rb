# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "securerandom"

module Sendly
  # Business Upgrade resource — Entity-Upgrade ("fork-with-new-number")
  #
  # Manages the toll-free business entity upgrade flow: when a customer
  # forms a new legal entity (e.g. an LLC), this resource lets them
  # reserve a new toll-free number under the new entity, submit it for
  # carrier review, and atomically swap to it on approval — without
  # disrupting outbound SMS during the 1-2 week review window.
  #
  # @see https://sendly.live/docs/business-upgrade
  #
  # @example Validate before submitting
  #   preview = client.business_upgrade.preflight(
  #     business_name: "Acme Holdings LLC",
  #     brn: "12-3456789",
  #     brn_type: "EIN",
  #     brn_country: "US",
  #     entity_type: "PRIVATE_PROFIT"
  #   )
  #
  # @example Submit an upgrade with the IRS letter
  #   result = client.business_upgrade.start(
  #     "ws_abc",
  #     business_name: "Acme Holdings LLC",
  #     brn: "12-3456789",
  #     brn_type: "EIN",
  #     brn_country: "US",
  #     entity_type: "PRIVATE_PROFIT",
  #     ein_doc_path: "./CP-575.pdf"
  #   )
  class BusinessUpgradeResource
    # Entity types accepted by the carrier
    ENTITY_TYPES = %w[
      SOLE_PROPRIETOR
      PRIVATE_PROFIT
      PUBLIC_PROFIT
      NON_PROFIT
      GOVERNMENT
    ].freeze

    # Business Registration Number types
    BRN_TYPES = %w[EIN SSN DUNS CRA VAT LEI OTHER].freeze

    # Disposition options for the old toll-free number after approval
    DISPOSITIONS = %w[moved released].freeze

    def initialize(client)
      @client = client
    end

    # Validate a candidate entity upgrade payload before submission.
    # Returns issues + proposed auto-fixes. No writes — purely advisory.
    #
    # Accepts the same fields as +start+. Returns a hash with
    # +verdict+ (+"ready"+, +"warnings"+, +"blocked"+), +issues+, and
    # +proposedFixes+.
    #
    # @param business_name [String, nil]
    # @param brn [String, nil]
    # @param brn_type [String, nil] One of {BRN_TYPES}
    # @param brn_country [String, nil] ISO country code
    # @param entity_type [String, nil] One of {ENTITY_TYPES}
    # @param doing_business_as [String, nil]
    # @param website [String, nil]
    # @param address1 [String, nil]
    # @param address2 [String, nil]
    # @param city [String, nil]
    # @param state [String, nil]
    # @param zip [String, nil]
    # @param address_country [String, nil]
    # @param contact_first_name [String, nil]
    # @param contact_last_name [String, nil]
    # @param contact_email [String, nil]
    # @param contact_phone [String, nil]
    # @param monthly_volume [String, nil]
    # @param use_case [String, nil]
    # @param use_case_summary [String, nil]
    # @param sample_messages [String, nil]
    # @param opt_in_workflow [String, nil]
    # @param privacy_url [String, nil]
    # @param terms_url [String, nil]
    # @param additional_information [String, nil]
    # @param age_gated_content [Boolean, nil]
    # @return [Hash] Preflight report
    def preflight(business_name: nil, brn: nil, brn_type: nil, brn_country: nil,
                  entity_type: nil, doing_business_as: nil, website: nil,
                  address1: nil, address2: nil, city: nil, state: nil, zip: nil,
                  address_country: nil, contact_first_name: nil,
                  contact_last_name: nil, contact_email: nil, contact_phone: nil,
                  monthly_volume: nil, use_case: nil, use_case_summary: nil,
                  sample_messages: nil, opt_in_workflow: nil, privacy_url: nil,
                  terms_url: nil, additional_information: nil,
                  age_gated_content: nil)
      body = build_upgrade_body(
        business_name: business_name, brn: brn, brn_type: brn_type,
        brn_country: brn_country, entity_type: entity_type,
        doing_business_as: doing_business_as, website: website,
        address1: address1, address2: address2, city: city, state: state,
        zip: zip, address_country: address_country,
        contact_first_name: contact_first_name,
        contact_last_name: contact_last_name, contact_email: contact_email,
        contact_phone: contact_phone, monthly_volume: monthly_volume,
        use_case: use_case, use_case_summary: use_case_summary,
        sample_messages: sample_messages, opt_in_workflow: opt_in_workflow,
        privacy_url: privacy_url, terms_url: terms_url,
        additional_information: additional_information,
        age_gated_content: age_gated_content
      )

      @client.post("/verification/preflight", body)
    end

    # Get a "best-of" prefill across all the caller's verified workspaces.
    # Returns most-recent non-empty values per messaging field. Use this
    # to pre-populate the upgrade form for users whose current workspace
    # has incomplete data.
    #
    # @return [Hash] +{ "prefill" => {...}, "sourceWorkspaceCount" => Integer }+
    def best_prefill
      @client.get("/verification/best-prefill")
    end

    # Start an entity upgrade for the given workspace. Auto-provisions
    # a new toll-free number + messaging profile and submits to the
    # carrier for review. Returns the pending verification details.
    #
    # The current toll-free number continues sending throughout the
    # 1-2 week carrier review; on approval, an atomic swap promotes
    # the new number.
    #
    # The EIN document (when supplied) is uploaded as multipart form-data
    # under the +einDoc+ field. Provide either +ein_doc_path+ (a path on
    # disk) or +ein_doc+ (raw bytes / IO) — not both.
    #
    # @param workspace_id [String]
    # @param business_name [String]
    # @param brn [String]
    # @param brn_type [String] One of {BRN_TYPES}
    # @param brn_country [String] ISO country code
    # @param entity_type [String] One of {ENTITY_TYPES}
    # @param ein_doc_path [String, nil] Path to the EIN/CP-575 PDF
    # @param ein_doc [String, IO, nil] Raw EIN PDF bytes or IO
    # @param ein_doc_filename [String, nil] Filename (defaults to "ein-doc.pdf")
    # @param ein_doc_content_type [String, nil] MIME type (defaults to "application/pdf")
    # @return [Hash] Upgrade start response
    def start(workspace_id, business_name:, brn:, brn_type:, brn_country:,
              entity_type:, doing_business_as: nil, website: nil,
              address1: nil, address2: nil, city: nil, state: nil, zip: nil,
              address_country: nil, contact_first_name: nil,
              contact_last_name: nil, contact_email: nil, contact_phone: nil,
              monthly_volume: nil, use_case: nil, use_case_summary: nil,
              sample_messages: nil, opt_in_workflow: nil, privacy_url: nil,
              terms_url: nil, additional_information: nil,
              age_gated_content: nil, ein_doc_path: nil, ein_doc: nil,
              ein_doc_filename: nil, ein_doc_content_type: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      fields = build_upgrade_body(
        business_name: business_name, brn: brn, brn_type: brn_type,
        brn_country: brn_country, entity_type: entity_type,
        doing_business_as: doing_business_as, website: website,
        address1: address1, address2: address2, city: city, state: state,
        zip: zip, address_country: address_country,
        contact_first_name: contact_first_name,
        contact_last_name: contact_last_name, contact_email: contact_email,
        contact_phone: contact_phone, monthly_volume: monthly_volume,
        use_case: use_case, use_case_summary: use_case_summary,
        sample_messages: sample_messages, opt_in_workflow: opt_in_workflow,
        privacy_url: privacy_url, terms_url: terms_url,
        additional_information: additional_information,
        age_gated_content: age_gated_content
      )

      post_multipart_with_fields(
        "/workspaces/#{url_escape(workspace_id)}/upgrade",
        fields,
        ein_doc_path: ein_doc_path,
        ein_doc: ein_doc,
        ein_doc_filename: ein_doc_filename,
        ein_doc_content_type: ein_doc_content_type
      )
    end

    # Check whether the given workspace has a pending entity upgrade.
    # Returns +{ "pending" => nil }+ when no upgrade is in flight.
    #
    # @param workspace_id [String]
    # @return [Hash]
    def status(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/workspaces/#{url_escape(workspace_id)}/upgrade/status")
    end

    # Cancel a pending entity upgrade for the given workspace. Releases
    # the reserved toll-free number, deletes the new messaging profile,
    # and removes the stored EIN document. Idempotent.
    #
    # @param workspace_id [String]
    # @return [Hash]
    def cancel(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.post("/workspaces/#{url_escape(workspace_id)}/upgrade/cancel", {})
    end

    # Resubmit a rejected (or waiting-for-customer) entity upgrade with
    # updated fields and optionally a new EIN document. All fields are
    # optional — only the ones you pass are sent.
    #
    # @param workspace_id [String]
    # @return [Hash]
    def resubmit(workspace_id, business_name: nil, brn: nil, brn_type: nil,
                 brn_country: nil, entity_type: nil, doing_business_as: nil,
                 website: nil, address1: nil, address2: nil, city: nil,
                 state: nil, zip: nil, address_country: nil,
                 contact_first_name: nil, contact_last_name: nil,
                 contact_email: nil, contact_phone: nil, monthly_volume: nil,
                 use_case: nil, use_case_summary: nil, sample_messages: nil,
                 opt_in_workflow: nil, privacy_url: nil, terms_url: nil,
                 additional_information: nil, age_gated_content: nil,
                 ein_doc_path: nil, ein_doc: nil, ein_doc_filename: nil,
                 ein_doc_content_type: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      fields = build_upgrade_body(
        business_name: business_name, brn: brn, brn_type: brn_type,
        brn_country: brn_country, entity_type: entity_type,
        doing_business_as: doing_business_as, website: website,
        address1: address1, address2: address2, city: city, state: state,
        zip: zip, address_country: address_country,
        contact_first_name: contact_first_name,
        contact_last_name: contact_last_name, contact_email: contact_email,
        contact_phone: contact_phone, monthly_volume: monthly_volume,
        use_case: use_case, use_case_summary: use_case_summary,
        sample_messages: sample_messages, opt_in_workflow: opt_in_workflow,
        privacy_url: privacy_url, terms_url: terms_url,
        additional_information: additional_information,
        age_gated_content: age_gated_content
      )

      post_multipart_with_fields(
        "/workspaces/#{url_escape(workspace_id)}/upgrade/resubmit",
        fields,
        ein_doc_path: ein_doc_path,
        ein_doc: ein_doc,
        ein_doc_filename: ein_doc_filename,
        ein_doc_content_type: ein_doc_content_type
      )
    end

    # After a successful entity-upgrade approval, choose what happens to
    # the old toll-free number:
    #
    # - +"moved"+: keep it active under another workspace owned by the
    #   same user (requires +target_workspace_id+)
    # - +"released"+: return it to the carrier pool
    #
    # @param workspace_id [String]
    # @param disposition [String] +"moved"+ or +"released"+
    # @param target_workspace_id [String, nil] Required when +disposition+ is +"moved"+
    # @return [Hash]
    def set_disposition(workspace_id, disposition:, target_workspace_id: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      unless DISPOSITIONS.include?(disposition)
        raise ArgumentError, "disposition must be one of: #{DISPOSITIONS.join(", ")}"
      end
      if disposition == "moved" && (target_workspace_id.nil? || target_workspace_id.empty?)
        raise ArgumentError, "target_workspace_id is required when disposition is 'moved'"
      end

      body = { disposition: disposition }
      body[:targetOrgId] = target_workspace_id if target_workspace_id

      @client.post("/workspaces/#{url_escape(workspace_id)}/upgrade/disposition", body)
    end

    private

    def url_escape(value)
      URI.encode_www_form_component(value)
    end

    def build_upgrade_body(business_name:, brn:, brn_type:, brn_country:,
                           entity_type:, doing_business_as:, website:,
                           address1:, address2:, city:, state:, zip:,
                           address_country:, contact_first_name:,
                           contact_last_name:, contact_email:, contact_phone:,
                           monthly_volume:, use_case:, use_case_summary:,
                           sample_messages:, opt_in_workflow:, privacy_url:,
                           terms_url:, additional_information:,
                           age_gated_content:)
      body = {}
      body[:businessName] = business_name unless business_name.nil?
      body[:brn] = brn unless brn.nil?
      body[:brnType] = brn_type unless brn_type.nil?
      body[:brnCountry] = brn_country unless brn_country.nil?
      body[:entityType] = entity_type unless entity_type.nil?
      body[:doingBusinessAs] = doing_business_as unless doing_business_as.nil?
      body[:website] = website unless website.nil?
      body[:address1] = address1 unless address1.nil?
      body[:address2] = address2 unless address2.nil?
      body[:city] = city unless city.nil?
      body[:state] = state unless state.nil?
      body[:zip] = zip unless zip.nil?
      body[:addressCountry] = address_country unless address_country.nil?
      body[:contactFirstName] = contact_first_name unless contact_first_name.nil?
      body[:contactLastName] = contact_last_name unless contact_last_name.nil?
      body[:contactEmail] = contact_email unless contact_email.nil?
      body[:contactPhone] = contact_phone unless contact_phone.nil?
      body[:monthlyVolume] = monthly_volume unless monthly_volume.nil?
      body[:useCase] = use_case unless use_case.nil?
      body[:useCaseSummary] = use_case_summary unless use_case_summary.nil?
      body[:sampleMessages] = sample_messages unless sample_messages.nil?
      body[:optInWorkflow] = opt_in_workflow unless opt_in_workflow.nil?
      body[:privacyUrl] = privacy_url unless privacy_url.nil?
      body[:termsUrl] = terms_url unless terms_url.nil?
      body[:additionalInformation] = additional_information unless additional_information.nil?
      body[:ageGatedContent] = age_gated_content unless age_gated_content.nil?
      body
    end

    # POST a multipart/form-data request with the given fields plus an
    # optional +einDoc+ file part. Mirrors the JSON-vs-multipart flexibility
    # the server expects: if no EIN doc is supplied and there are no fields,
    # we still send an empty multipart body (the server is configured for
    # +multer+ on these routes).
    def post_multipart_with_fields(path, fields, ein_doc_path:, ein_doc:,
                                   ein_doc_filename:, ein_doc_content_type:)
      if !ein_doc_path.nil? && !ein_doc.nil?
        raise ArgumentError, "Provide ein_doc_path OR ein_doc, not both"
      end

      file_bytes = nil
      filename = ein_doc_filename || "ein-doc.pdf"
      content_type = ein_doc_content_type || "application/pdf"

      if ein_doc_path
        raise ArgumentError, "File not found: #{ein_doc_path}" unless File.exist?(ein_doc_path)
        file_bytes = File.binread(ein_doc_path)
        filename = ein_doc_filename || File.basename(ein_doc_path)
      elsif ein_doc
        file_bytes = ein_doc.is_a?(String) ? ein_doc : ein_doc.read
      end

      boundary = "SendlyRuby#{SecureRandom.hex(16)}"
      body_parts = []

      fields.each do |k, v|
        next if v.nil?
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"#{k}\"\r\n\r\n"
        body_parts << (v == true || v == false ? v.to_s : v.to_s)
        body_parts << "\r\n"
      end

      if file_bytes
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"einDoc\"; filename=\"#{filename}\"\r\n"
        body_parts << "Content-Type: #{content_type}\r\n\r\n"
        body_parts << file_bytes
        body_parts << "\r\n"
      end

      body_parts << "--#{boundary}--\r\n"

      uri = URI.parse("#{@client.base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = @client.timeout

      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@client.api_key}"
      req["Accept"] = "application/json"
      req["User-Agent"] = "sendly-ruby/#{Sendly::VERSION}"
      req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
      req["X-Organization-Id"] = @client.organization_id if @client.organization_id
      req.body = body_parts.join

      begin
        response = http.request(req)
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise Sendly::TimeoutError, "Request timed out after #{@client.timeout} seconds"
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
        raise Sendly::NetworkError, "Connection failed: #{e.message}"
      end

      status = response.code.to_i
      body = response.body.nil? || response.body.empty? ? {} : (JSON.parse(response.body) rescue { "message" => response.body })

      return body if status >= 200 && status < 300

      raise Sendly::ErrorFactory.from_response(status, body)
    end
  end
end
