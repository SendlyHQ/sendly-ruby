# frozen_string_literal: true

module Sendly
  class Campaign
    attr_reader :id, :name, :text, :template_id, :contact_list_ids, :status,
                :recipient_count, :sent_count, :delivered_count, :failed_count,
                :estimated_credits, :credits_used, :scheduled_at, :timezone,
                :started_at, :completed_at, :created_at, :updated_at

    STATUSES = %w[draft scheduled sending sent paused cancelled failed].freeze

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @text = data["text"]
      @template_id = data["template_id"] || data["templateId"]
      @contact_list_ids = data["contact_list_ids"] || data["contactListIds"] || []
      @status = data["status"]
      @recipient_count = data["recipient_count"] || data["recipientCount"] || 0
      @sent_count = data["sent_count"] || data["sentCount"] || 0
      @delivered_count = data["delivered_count"] || data["deliveredCount"] || 0
      @failed_count = data["failed_count"] || data["failedCount"] || 0
      @estimated_credits = data["estimated_credits"] || data["estimatedCredits"] || 0
      @credits_used = data["credits_used"] || data["creditsUsed"] || 0
      @scheduled_at = parse_time(data["scheduled_at"] || data["scheduledAt"])
      @timezone = data["timezone"]
      @started_at = parse_time(data["started_at"] || data["startedAt"])
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

    def sent?
      status == "sent"
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

  class CampaignPreview
    attr_reader :id, :recipient_count, :estimated_segments, :estimated_credits,
                :current_balance, :has_enough_credits, :breakdown

    def initialize(data)
      @id = data["id"]
      @recipient_count = data["recipient_count"] || data["recipientCount"] || 0
      @estimated_segments = data["estimated_segments"] || data["estimatedSegments"] || 0
      @estimated_credits = data["estimated_credits"] || data["estimatedCredits"] || 0
      @current_balance = data["current_balance"] || data["currentBalance"] || 0
      @has_enough_credits = data["has_enough_credits"] || data["hasEnoughCredits"] || false
      @breakdown = data["breakdown"]
    end

    def enough_credits?
      has_enough_credits
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
      response = @client.get("/campaigns/#{id}")
      Campaign.new(response)
    end

    def update(id, name: nil, text: nil, template_id: nil, contact_list_ids: nil)
      body = {}
      body[:name] = name if name
      body[:text] = text if text
      body[:templateId] = template_id unless template_id.nil?
      body[:contactListIds] = contact_list_ids if contact_list_ids

      response = @client.patch("/campaigns/#{id}", body)
      Campaign.new(response)
    end

    def delete(id)
      @client.delete("/campaigns/#{id}")
    end

    def preview(id)
      response = @client.get("/campaigns/#{id}/preview")
      CampaignPreview.new(response)
    end

    def send_campaign(id)
      response = @client.post("/campaigns/#{id}/send")
      Campaign.new(response)
    end

    def schedule(id, scheduled_at:, timezone: nil)
      body = { scheduledAt: scheduled_at }
      body[:timezone] = timezone if timezone

      response = @client.post("/campaigns/#{id}/schedule", body)
      Campaign.new(response)
    end

    def cancel(id)
      response = @client.post("/campaigns/#{id}/cancel")
      Campaign.new(response)
    end

    def clone(id)
      response = @client.post("/campaigns/#{id}/clone")
      Campaign.new(response)
    end
  end
end
