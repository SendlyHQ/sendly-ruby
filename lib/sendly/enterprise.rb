# frozen_string_literal: true

module Sendly
  class EnterpriseWorkspacesSubResource
    def initialize(client)
      @client = client
    end

    def create(name:, description: nil)
      raise ArgumentError, "Workspace name is required" if name.nil? || name.strip.empty?

      body = { name: name }
      body[:description] = description if description

      @client.post("/enterprise/workspaces", body)
    end

    def list
      @client.get("/enterprise/workspaces")
    end

    def get(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/enterprise/workspaces/#{workspace_id}")
    end

    def delete(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.delete("/enterprise/workspaces/#{workspace_id}")
    end

    def submit_verification(workspace_id, business_name:, business_type:, ein:, address:, city:, state:, zip:, use_case:, sample_messages:, monthly_volume: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      body = {
        business_name: business_name,
        business_type: business_type,
        ein: ein,
        address: address,
        city: city,
        state: state,
        zip: zip,
        use_case: use_case,
        sample_messages: sample_messages
      }
      body[:monthly_volume] = monthly_volume if monthly_volume

      @client.post("/enterprise/workspaces/#{workspace_id}/verification/submit", body)
    end

    def inherit_verification(workspace_id, source_workspace_id:)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Source workspace ID is required" if source_workspace_id.nil? || source_workspace_id.empty?

      @client.post("/enterprise/workspaces/#{workspace_id}/verification/inherit", {
        source_workspace_id: source_workspace_id
      })
    end

    def get_verification(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/enterprise/workspaces/#{workspace_id}/verification")
    end

    def transfer_credits(workspace_id, source_workspace_id:, amount:)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Source workspace ID is required" if source_workspace_id.nil? || source_workspace_id.empty?
      raise ArgumentError, "Amount must be a positive number" if !amount.is_a?(Integer) || amount <= 0

      @client.post("/enterprise/workspaces/#{workspace_id}/transfer-credits", {
        source_workspace_id: source_workspace_id,
        amount: amount
      })
    end

    def get_credits(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/enterprise/workspaces/#{workspace_id}/credits")
    end

    def create_key(workspace_id, name: nil, type: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      body = {}
      body[:name] = name if name
      body[:type] = type if type

      @client.post("/enterprise/workspaces/#{workspace_id}/keys", body)
    end

    def list_keys(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/enterprise/workspaces/#{workspace_id}/keys")
    end

    def revoke_key(workspace_id, key_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Key ID is required" if key_id.nil? || key_id.empty?

      @client.delete("/enterprise/workspaces/#{workspace_id}/keys/#{key_id}")
    end

    def list_opt_in_pages(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/enterprise/workspaces/#{workspace_id}/opt-in-pages")
    end

    def create_opt_in_page(workspace_id, business_name:, use_case: nil, use_case_summary: nil, sample_messages: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Business name is required" if business_name.nil? || business_name.strip.empty?

      body = { businessName: business_name }
      body[:useCase] = use_case if use_case
      body[:useCaseSummary] = use_case_summary if use_case_summary
      body[:sampleMessages] = sample_messages if sample_messages

      @client.post("/enterprise/workspaces/#{workspace_id}/opt-in-pages", body)
    end

    def update_opt_in_page(workspace_id, page_id, logo_url: nil, header_color: nil, button_color: nil, custom_headline: nil, custom_benefits: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Page ID is required" if page_id.nil? || page_id.empty?

      body = {}
      body[:logoUrl] = logo_url unless logo_url.nil?
      body[:headerColor] = header_color unless header_color.nil?
      body[:buttonColor] = button_color unless button_color.nil?
      body[:customHeadline] = custom_headline unless custom_headline.nil?
      body[:customBenefits] = custom_benefits unless custom_benefits.nil?

      @client.patch("/enterprise/workspaces/#{workspace_id}/opt-in-pages/#{page_id}", body)
    end

    def delete_opt_in_page(workspace_id, page_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Page ID is required" if page_id.nil? || page_id.empty?

      @client.delete("/enterprise/workspaces/#{workspace_id}/opt-in-pages/#{page_id}")
    end

    def set_webhook(workspace_id, url:, events: nil, description: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Webhook URL is required" if url.nil? || url.empty?

      body = { url: url }
      body[:events] = events if events
      body[:description] = description if description

      @client.put("/enterprise/workspaces/#{workspace_id}/webhooks", body)
    end

    def list_webhooks(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/enterprise/workspaces/#{workspace_id}/webhooks")
    end

    def delete_webhooks(workspace_id, webhook_id: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      path = "/enterprise/workspaces/#{workspace_id}/webhooks"
      path += "?webhookId=#{webhook_id}" if webhook_id

      @client.delete(path)
    end

    def test_webhook(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.post("/enterprise/workspaces/#{workspace_id}/webhooks/test")
    end

    def suspend(workspace_id, reason: nil)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      body = {}
      body[:reason] = reason if reason

      @client.post("/enterprise/workspaces/#{workspace_id}/suspend", body)
    end

    def resume(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.post("/enterprise/workspaces/#{workspace_id}/resume")
    end

    def provision_bulk(workspaces)
      raise ArgumentError, "Workspaces array is required" if workspaces.nil? || !workspaces.is_a?(Array) || workspaces.empty?
      raise ArgumentError, "Maximum 50 workspaces per bulk provision" if workspaces.length > 50

      @client.post("/enterprise/workspaces/provision/bulk", { workspaces: workspaces })
    end

    def set_custom_domain(workspace_id, page_id, domain:)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Page ID is required" if page_id.nil? || page_id.empty?
      raise ArgumentError, "Domain is required" if domain.nil? || domain.empty?

      @client.put("/enterprise/workspaces/#{workspace_id}/pages/#{page_id}/domain", { domain: domain })
    end

    def send_invitation(workspace_id, email:, role:)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Email is required" if email.nil? || email.empty?
      raise ArgumentError, "Role is required" if role.nil? || role.empty?

      @client.post("/enterprise/workspaces/#{workspace_id}/invitations", {
        email: email,
        role: role
      })
    end

    def list_invitations(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/enterprise/workspaces/#{workspace_id}/invitations")
    end

    def cancel_invitation(workspace_id, invite_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?
      raise ArgumentError, "Invite ID is required" if invite_id.nil? || invite_id.empty?

      @client.delete("/enterprise/workspaces/#{workspace_id}/invitations/#{invite_id}")
    end

    def get_quota(workspace_id)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.get("/enterprise/workspaces/#{workspace_id}/quota")
    end

    def set_quota(workspace_id, monthly_message_quota:)
      raise ArgumentError, "Workspace ID is required" if workspace_id.nil? || workspace_id.empty?

      @client.put("/enterprise/workspaces/#{workspace_id}/quota", {
        monthlyMessageQuota: monthly_message_quota
      })
    end
  end

  class EnterpriseWebhooksSubResource
    def initialize(client)
      @client = client
    end

    def set(url:)
      raise ArgumentError, "Webhook URL is required" if url.nil? || url.empty?

      @client.post("/enterprise/webhooks", { url: url })
    end

    def get
      @client.get("/enterprise/webhooks")
    end

    def delete
      @client.delete("/enterprise/webhooks")
    end

    def test
      @client.post("/enterprise/webhooks/test")
    end

    def rotate_secret
      @client.post("/enterprise/webhooks/rotate-secret")
    end
  end

  class EnterpriseAnalyticsSubResource
    def initialize(client)
      @client = client
    end

    def overview
      @client.get("/enterprise/analytics/overview")
    end

    def messages(period: nil, workspace_id: nil)
      params = {}
      params[:period] = period if period
      params[:workspaceId] = workspace_id if workspace_id

      @client.get("/enterprise/analytics/messages", params)
    end

    def delivery
      @client.get("/enterprise/analytics/delivery")
    end

    def credits(period: nil)
      params = {}
      params[:period] = period if period

      @client.get("/enterprise/analytics/credits", params)
    end
  end

  class EnterpriseSettingsSubResource
    def initialize(client)
      @client = client
    end

    def get_auto_top_up
      @client.get("/enterprise/settings/auto-top-up")
    end

    def update_auto_top_up(enabled:, threshold:, amount:, source_workspace_id: nil)
      body = {
        enabled: enabled,
        threshold: threshold,
        amount: amount
      }
      body[:sourceWorkspaceId] = source_workspace_id if source_workspace_id

      @client.put("/enterprise/settings/auto-top-up", body)
    end
  end

  class EnterpriseBillingSubResource
    def initialize(client)
      @client = client
    end

    def get_breakdown(period: nil, page: nil, limit: nil)
      params = {}
      params[:period] = period if period
      params[:page] = page if page
      params[:limit] = limit if limit

      @client.get("/enterprise/billing/workspace-breakdown", params)
    end
  end

  class EnterpriseCreditsSubResource
    def initialize(client)
      @client = client
    end

    def get
      @client.get("/enterprise/credits")
    end

    def deposit(amount:, description: nil)
      raise ArgumentError, "Amount must be a positive number" if !amount.is_a?(Integer) || amount <= 0

      body = { amount: amount }
      body[:description] = description if description

      @client.post("/enterprise/credits/deposit", body)
    end
  end

  class EnterpriseResource
    attr_reader :workspaces, :webhooks, :analytics, :settings, :billing, :credits

    def initialize(client)
      @client = client
      @workspaces = EnterpriseWorkspacesSubResource.new(client)
      @webhooks = EnterpriseWebhooksSubResource.new(client)
      @analytics = EnterpriseAnalyticsSubResource.new(client)
      @settings = EnterpriseSettingsSubResource.new(client)
      @billing = EnterpriseBillingSubResource.new(client)
      @credits = EnterpriseCreditsSubResource.new(client)
    end

    def get_account
      @client.get("/enterprise/account")
    end

    def provision(name:, source_workspace_id: nil, inherit_with_new_number: nil, verification: nil, credit_amount: nil, credit_source_workspace_id: nil, key_name: nil, key_type: nil, webhook_url: nil, generate_opt_in_page: nil)
      raise ArgumentError, "Workspace name is required" if name.nil? || name.strip.empty?

      body = { name: name }
      body[:sourceWorkspaceId] = source_workspace_id if source_workspace_id
      body[:inheritWithNewNumber] = true if inherit_with_new_number
      body[:verification] = verification if verification
      body[:creditAmount] = credit_amount if credit_amount
      body[:creditSourceWorkspaceId] = credit_source_workspace_id if credit_source_workspace_id
      body[:keyName] = key_name if key_name
      body[:keyType] = key_type if key_type
      body[:webhookUrl] = webhook_url if webhook_url
      body[:generateOptInPage] = generate_opt_in_page unless generate_opt_in_page.nil?

      @client.post("/enterprise/workspaces/provision", body)
    end

    def generate_business_page(business_name:, use_case: nil, use_case_summary: nil, contact_email: nil, contact_phone: nil, business_address: nil, social_url: nil)
      raise ArgumentError, "Business name is required" if business_name.nil? || business_name.strip.empty?

      body = { businessName: business_name }
      body[:useCase] = use_case if use_case
      body[:useCaseSummary] = use_case_summary if use_case_summary
      body[:contactEmail] = contact_email if contact_email
      body[:contactPhone] = contact_phone if contact_phone
      body[:businessAddress] = business_address if business_address
      body[:socialUrl] = social_url if social_url

      @client.post("/verification/business-page/generate", body)
    end
  end
end
