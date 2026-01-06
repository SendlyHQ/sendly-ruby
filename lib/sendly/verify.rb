# frozen_string_literal: true

module Sendly
  class Verification
    attr_reader :id, :status, :phone, :delivery_status, :attempts, :max_attempts,
                :channel, :expires_at, :verified_at, :created_at, :sandbox,
                :app_name, :template_id, :profile_id, :metadata

    STATUSES = %w[pending verified expired failed].freeze
    CHANNELS = %w[sms whatsapp email].freeze

    def initialize(data)
      @id = data["id"]
      @status = data["status"]
      @phone = data["phone"]
      @delivery_status = data["deliveryStatus"] || data["delivery_status"]
      @attempts = data["attempts"] || 0
      @max_attempts = data["maxAttempts"] || data["max_attempts"] || 3
      @channel = data["channel"] || "sms"
      @expires_at = parse_time(data["expiresAt"] || data["expires_at"])
      @verified_at = parse_time(data["verifiedAt"] || data["verified_at"])
      @created_at = parse_time(data["createdAt"] || data["created_at"])
      @sandbox = data["sandbox"] || false
      @app_name = data["appName"] || data["app_name"]
      @template_id = data["templateId"] || data["template_id"]
      @profile_id = data["profileId"] || data["profile_id"]
      @metadata = data["metadata"] || {}
    end

    def pending?
      status == "pending"
    end

    def verified?
      status == "verified"
    end

    def expired?
      status == "expired"
    end

    def failed?
      status == "failed"
    end

    def to_h
      {
        id: id, status: status, phone: phone, delivery_status: delivery_status,
        attempts: attempts, max_attempts: max_attempts, channel: channel,
        expires_at: expires_at&.iso8601, verified_at: verified_at&.iso8601,
        created_at: created_at&.iso8601, sandbox: sandbox, app_name: app_name,
        template_id: template_id, profile_id: profile_id, metadata: metadata
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

  class SendVerificationResponse
    attr_reader :verification, :code

    def initialize(data)
      @verification = Verification.new(data["verification"])
      @code = data["code"]
    end
  end

  class CheckVerificationResponse
    attr_reader :valid, :status, :verification

    def initialize(data)
      @valid = data["valid"]
      @status = data["status"]
      @verification = data["verification"] ? Verification.new(data["verification"]) : nil
    end

    def valid?
      valid
    end
  end

  class VerifySession
    attr_reader :id, :url, :status, :success_url, :cancel_url, :brand_name,
                :brand_color, :phone, :verification_id, :token, :metadata,
                :expires_at, :created_at

    def initialize(data)
      @id = data["id"]
      @url = data["url"]
      @status = data["status"]
      @success_url = data["success_url"]
      @cancel_url = data["cancel_url"]
      @brand_name = data["brand_name"]
      @brand_color = data["brand_color"]
      @phone = data["phone"]
      @verification_id = data["verification_id"]
      @token = data["token"]
      @metadata = data["metadata"] || {}
      @expires_at = data["expires_at"]
      @created_at = data["created_at"]
    end

    def to_h
      {
        id: id, url: url, status: status, success_url: success_url,
        cancel_url: cancel_url, brand_name: brand_name, brand_color: brand_color,
        phone: phone, verification_id: verification_id, token: token,
        metadata: metadata, expires_at: expires_at, created_at: created_at
      }.compact
    end
  end

  class ValidateSessionResponse
    attr_reader :valid, :session_id, :phone, :verified_at, :metadata

    def initialize(data)
      @valid = data["valid"]
      @session_id = data["session_id"]
      @phone = data["phone"]
      @verified_at = data["verified_at"]
      @metadata = data["metadata"] || {}
    end

    def valid?
      valid
    end
  end

  class SessionsResource
    def initialize(client)
      @client = client
    end

    def create(success_url:, cancel_url: nil, brand_name: nil, brand_color: nil, metadata: nil)
      body = { success_url: success_url }
      body[:cancel_url] = cancel_url if cancel_url
      body[:brand_name] = brand_name if brand_name
      body[:brand_color] = brand_color if brand_color
      body[:metadata] = metadata if metadata

      response = @client.post("/verify/sessions", body)
      VerifySession.new(response)
    end

    def validate(token:)
      response = @client.post("/verify/sessions/validate", { token: token })
      ValidateSessionResponse.new(response)
    end
  end

  class VerifyResource
    attr_reader :sessions

    def initialize(client)
      @client = client
      @sessions = SessionsResource.new(client)
    end

    def send(phone:, channel: nil, code_length: nil, expires_in: nil, max_attempts: nil,
             template_id: nil, profile_id: nil, app_name: nil, locale: nil, metadata: nil)
      body = { phone: phone }
      body[:channel] = channel if channel
      body[:codeLength] = code_length if code_length
      body[:expiresIn] = expires_in if expires_in
      body[:maxAttempts] = max_attempts if max_attempts
      body[:templateId] = template_id if template_id
      body[:profileId] = profile_id if profile_id
      body[:appName] = app_name if app_name
      body[:locale] = locale if locale
      body[:metadata] = metadata if metadata

      response = @client.post("/verify", body)
      SendVerificationResponse.new(response)
    end

    def resend(id)
      response = @client.post("/verify/#{id}/resend")
      SendVerificationResponse.new(response)
    end

    def check(id, code:)
      response = @client.post("/verify/#{id}/check", { code: code })
      CheckVerificationResponse.new(response)
    end

    def get(id)
      response = @client.get("/verify/#{id}")
      Verification.new(response)
    end

    def list(limit: nil, status: nil, phone: nil)
      params = {}
      params[:limit] = limit if limit
      params[:status] = status if status
      params[:phone] = phone if phone

      response = @client.get("/verify", params)
      verifications = (response["verifications"] || []).map { |v| Verification.new(v) }
      { verifications: verifications, pagination: response["pagination"] }
    end
  end
end
