# frozen_string_literal: true

module Sendly
  # A campaign. A sent campaign's status is +completed+. +recipient_count+
  # is the number of recipients it was sent to, or for a scheduled campaign
  # the number it will be sent to (0 for a draft). +started_at+ is when
  # sending began. +template_id+ is always +nil+: the API does not return it.
  class Campaign
    attr_reader :id, :name, :text, :template_id, :contact_list_ids, :status,
                :recipient_count, :sent_count, :delivered_count, :failed_count,
                :estimated_credits, :credits_used, :scheduled_at, :timezone,
                :started_at, :completed_at, :created_at, :updated_at

    # Campaign statuses. The API returns +draft+, +scheduled+, +sending+,
    # +completed+, +cancelled+ and +failed+; +sent+ and +paused+ are never
    # returned.
    STATUSES = %w[draft scheduled sending sent paused cancelled failed completed].freeze

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @text = data["text"] || data["messageText"]
      @template_id = data["template_id"] || data["templateId"]
      @contact_list_ids = data["contact_list_ids"] || data["contactListIds"] || [data["targetListId"]].compact
      @status = data["status"]
      @recipient_count = data["recipient_count"] || data["recipientCount"] || data["totalRecipients"] || 0
      @sent_count = data["sent_count"] || data["sentCount"] || 0
      @delivered_count = data["delivered_count"] || data["deliveredCount"] || 0
      @failed_count = data["failed_count"] || data["failedCount"] || 0
      @estimated_credits = data["estimated_credits"] || data["estimatedCredits"] || 0
      @credits_used = data["credits_used"] || data["creditsUsed"] || 0
      @scheduled_at = parse_time(data["scheduled_at"] || data["scheduledAt"])
      @timezone = data["timezone"]
      @started_at = parse_time(data["started_at"] || data["startedAt"] || data["sentAt"])
      @completed_at = parse_time(data["completed_at"] || data["completedAt"])
      @created_at = parse_time(data["created_at"] || data["createdAt"])
      @updated_at = parse_time(data["updated_at"] || data["updatedAt"])
    end

    def draft?
      status == "draft"
    end

    def scheduled?
      status == "scheduled"
    end

    def sending?
      status == "sending"
    end

    # @return [Boolean] Whether the campaign has been sent (status +completed+)
    def sent?
      %w[sent completed].include?(status)
    end

    # @return [Boolean] Whether the status is +completed+, which is what a sent campaign becomes
    def completed?
      status == "completed"
    end

    def cancelled?
      status == "cancelled"
    end

    def to_h
      {
        id: id, name: name, text: text, template_id: template_id,
        contact_list_ids: contact_list_ids, status: status,
        recipient_count: recipient_count, sent_count: sent_count,
        delivered_count: delivered_count, failed_count: failed_count,
        estimated_credits: estimated_credits, credits_used: credits_used,
        scheduled_at: scheduled_at&.iso8601, timezone: timezone,
        started_at: started_at&.iso8601, completed_at: completed_at&.iso8601,
        created_at: created_at&.iso8601, updated_at: updated_at&.iso8601
      }.compact
    end

    private

    def parse_time(value)
      return nil if value.nil?
      Time.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # A campaign's recipient count and cost estimate. +id+ and
  # +estimated_segments+ are not returned by the API (+nil+ and 0).
  # +breakdown+ is per country: +{ "US" => { "count", "credits", "allowed" } }+.
  class CampaignPreview
    attr_reader :id, :recipient_count, :estimated_segments, :estimated_credits,
                :current_balance, :has_enough_credits, :breakdown,
                :blocked_count, :sendable_count, :warnings, :messaging_profile

    def initialize(data)
      @id = data["id"]
      @recipient_count = data["recipient_count"] || data["recipientCount"] || 0
      @estimated_segments = data["estimated_segments"] || data["estimatedSegments"] || 0
      @estimated_credits = data["estimated_credits"] || data["estimatedCredits"] || 0
      @current_balance = data["current_balance"] || data["currentBalance"] || 0
      @has_enough_credits = data["has_enough_credits"] || data["hasEnoughCredits"] || false
      @breakdown = data["breakdown"] || data["byCountry"]
      @blocked_count = data["blocked_count"] || data["blockedCount"]
      @sendable_count = data["sendable_count"] || data["sendableCount"]
      @warnings = data["warnings"]
      @messaging_profile = data["messaging_profile"] || data["messagingProfile"]
    end

    def enough_credits?
      has_enough_credits
    end
  end

  # The result of {CampaignsResource#send_campaign}: the batch the campaign's
  # messages went out in. +id+ is the campaign's ID, +status+ the batch's
  # (+processing+, +completed+, +partial_failure+ or +failed+), and
  # +recipient_count+ the messages in the batch. Name, text and dates are not
  # part of the response; read the campaign with {CampaignsResource#get}.
  class CampaignSendResult < Campaign
    # @return [String] Batch the messages went out in; see {Sendly::Messages#get_batch}
    attr_reader :batch_id

    # @return [Integer] Credits returned for messages that failed
    attr_reader :credits_refunded

    # @return [Array<Hash>] Each message in the batch; empty while the batch is processing
    attr_reader :messages

    # @return [Hash] The raw parsed response
    attr_reader :raw

    def initialize(data, campaign_id = nil)
      super(data)
      @raw = data
      @id = campaign_id || data["id"]
      @batch_id = data["batchId"] || data["batch_id"]
      @recipient_count = data["total"] || @recipient_count
      @sent_count = data["sent"] || @sent_count
      @failed_count = data["failed"] || @failed_count
      @credits_refunded = data["creditsRefunded"] || data["credits_refunded"] || 0
      @messages = data["messages"] || []
    end
  end

  class CampaignsResource
    def initialize(client)
      @client = client
    end

    def create(name:, text:, contact_list_ids:, template_id: nil)
      body = {
        name: name,
        text: text,
        contactListIds: contact_list_ids
      }
      body[:templateId] = template_id if template_id

      response = @client.post("/campaigns", body)
      Campaign.new(response)
    end

    def list(limit: nil, offset: nil, status: nil)
      params = {}
      params[:limit] = limit if limit
      params[:offset] = offset if offset
      params[:status] = status if status

      response = @client.get("/campaigns", params)
      campaigns = (response["campaigns"] || []).map { |c| Campaign.new(c) }
      {
        campaigns: campaigns,
        total: response["total"],
        limit: response["limit"],
        offset: response["offset"]
      }
    end

    def get(id)
      response = @client.get("/campaigns/#{URI.encode_www_form_component(id)}")
      Campaign.new(response)
    end

    def update(id, name: nil, text: nil, template_id: nil, contact_list_ids: nil)
      body = {}
      body[:name] = name if name
      body[:text] = text if text
      body[:templateId] = template_id unless template_id.nil?
      body[:contactListIds] = contact_list_ids if contact_list_ids

      response = @client.patch("/campaigns/#{URI.encode_www_form_component(id)}", body)
      Campaign.new(response)
    end

    def delete(id)
      @client.delete("/campaigns/#{URI.encode_www_form_component(id)}")
    end

    def preview(id)
      response = @client.get("/campaigns/#{URI.encode_www_form_component(id)}/preview")
      CampaignPreview.new(response)
    end

    # Send a campaign now.
    #
    # @param id [String] Campaign ID
    # @return [Sendly::CampaignSendResult] The batch the campaign went out in
    def send_campaign(id)
      response = @client.post("/campaigns/#{URI.encode_www_form_component(id)}/send")
      CampaignSendResult.new(response, id)
    end

    def schedule(id, scheduled_at:, timezone: nil)
      body = { scheduledAt: scheduled_at }
      body[:timezone] = timezone if timezone

      response = @client.post("/campaigns/#{URI.encode_www_form_component(id)}/schedule", body)
      Campaign.new(response)
    end

    def cancel(id)
      response = @client.post("/campaigns/#{URI.encode_www_form_component(id)}/cancel")
      Campaign.new(response)
    end

    def clone(id)
      response = @client.post("/campaigns/#{URI.encode_www_form_component(id)}/clone")
      Campaign.new(response)
    end
  end
end
