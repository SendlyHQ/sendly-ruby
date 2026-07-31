# frozen_string_literal: true

module Sendly
  # A newly started WhatsApp signup. Hand +connect_url+ to a human — they
  # open it in a browser and log in with Facebook to link their WhatsApp
  # Business Account. Poll {WhatsAppSignupResource#get} with +id+ until the
  # status is +"active"+.
  class WhatsAppSignupSession
    attr_reader :id, :connect_url, :status

    STATUSES = %w[initiated registering active failed expired].freeze

    def initialize(data)
      @id = data["id"]
      @connect_url = data["connectUrl"] || data["connect_url"]
      @status = data["status"]
    end

    def active?
      status == "active"
    end

    def failed?
      status == "failed"
    end

    def to_h
      { id: id, connect_url: connect_url, status: status }.compact
    end
  end

  # The status of a WhatsApp signup. +business_account_id+ is nil until the
  # human completes the connect step; +failure_reasons+ is set when the
  # status is +"failed"+.
  class WhatsAppSignup
    attr_reader :id, :status, :phone_number, :business_account_id,
                :failure_reasons, :updated_at

    STATUSES = %w[initiated registering active failed expired].freeze

    def initialize(data)
      @id = data["id"]
      @status = data["status"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @business_account_id = data["businessAccountId"] || data["business_account_id"]
      @failure_reasons = data["failureReasons"] || data["failure_reasons"]
      @updated_at = data["updatedAt"] || data["updated_at"]
    end

    def active?
      status == "active"
    end

    def failed?
      status == "failed"
    end

    def expired?
      status == "expired"
    end

    def to_h
      {
        id: id, status: status, phone_number: phone_number,
        business_account_id: business_account_id,
        failure_reasons: failure_reasons, updated_at: updated_at
      }.compact
    end
  end

  # A number connected (or connecting) to WhatsApp. +display_name+ is the
  # name recipients see — chosen during the connect flow and reviewed by
  # Meta; nil until set. +quality_rating+ is Meta's rating (e.g. "GREEN"),
  # nil before the first rating.
  class WhatsAppSender
    attr_reader :phone_number, :display_name, :status, :quality_rating,
                :created_at

    STATUSES = %w[pending active suspended].freeze

    def initialize(data)
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @display_name = data["displayName"] || data["display_name"]
      @status = data["status"]
      @quality_rating = data["qualityRating"] || data["quality_rating"]
      @created_at = data["createdAt"] || data["created_at"]
    end

    def pending?
      status == "pending"
    end

    def active?
      status == "active"
    end

    def suspended?
      status == "suspended"
    end

    def to_h
      {
        phone_number: phone_number, display_name: display_name,
        status: status, quality_rating: quality_rating, created_at: created_at
      }.compact
    end
  end

  # A WhatsApp message template. Meta reviews every template (usually
  # 24-48h) and may reclassify its category — the category on the record
  # is what drives per-message pricing. +rejection_reason+ is set when the
  # status is +"REJECTED"+; +warnings+ carries non-blocking submission
  # warnings on create responses.
  class WhatsAppTemplate
    attr_reader :id, :name, :language, :category, :status, :quality_rating,
                :rejection_reason, :created_at, :updated_at, :warnings

    STATUSES = %w[PENDING APPROVED REJECTED PAUSED DISABLED].freeze
    CATEGORIES = %w[AUTHENTICATION UTILITY MARKETING].freeze

    def initialize(data)
      @id = data["id"]
      @name = data["name"]
      @language = data["language"]
      @category = data["category"]
      @status = data["status"]
      @quality_rating = data["qualityRating"] || data["quality_rating"]
      @rejection_reason = data["rejectionReason"] || data["rejection_reason"]
      @created_at = data["createdAt"] || data["created_at"]
      @updated_at = data["updatedAt"] || data["updated_at"]
      @warnings = data["warnings"]
    end

    def pending?
      status == "PENDING"
    end

    def approved?
      status == "APPROVED"
    end

    def rejected?
      status == "REJECTED"
    end

    def to_h
      {
        id: id, name: name, language: language, category: category,
        status: status, quality_rating: quality_rating,
        rejection_reason: rejection_reason, created_at: created_at,
        updated_at: updated_at, warnings: warnings
      }.compact
    end
  end

  # Confirmation that a template was deleted.
  class WhatsAppTemplateDeletion
    attr_reader :id, :deleted

    def initialize(data)
      @id = data["id"]
      @deleted = data["deleted"] || false
    end

    def deleted?
      deleted
    end

    def to_h
      { id: id, deleted: deleted }.compact
    end
  end

  # Whether a 24-hour customer-service window is open between one of your
  # WhatsApp senders and a recipient. +expires_at+ is when the window
  # closes (ISO 8601), nil when no window is open.
  class WhatsAppWindow
    attr_reader :open, :expires_at

    def initialize(data)
      @open = data["open"] || false
      @expires_at = data["expiresAt"] || data["expires_at"]
    end

    def open?
      open
    end

    def to_h
      { open: open, expires_at: expires_at }.compact
    end
  end

  # WhatsApp-specific details on a sent message. +kind+ is what was sent
  # ("text", "media", or "template"); +template+ carries the sent
  # template's name, language, and billed category on template sends;
  # +message_id+ is the WhatsApp message id, nil until the first delivery
  # report lands.
  class WhatsAppMessageDetails
    attr_reader :kind, :template, :message_id

    KINDS = %w[text media template].freeze

    def initialize(data)
      @kind = data["kind"]
      if data["template"]
        @template = {
          name: data.dig("template", "name"),
          language: data.dig("template", "language"),
          category: data.dig("template", "category")
        }
      end
      @message_id = data["messageId"] || data["message_id"]
    end

    def to_h
      { kind: kind, template: template, message_id: message_id }.compact
    end
  end

  # A sent WhatsApp message. Unlike {Message}, +segments+ is always 1
  # (WhatsApp has no segment concept), +text+ is nil for template and media
  # sends, and +whatsapp+ carries the channel-specific details.
  class WhatsAppMessage
    attr_reader :id, :channel, :message_format, :to, :from, :text, :status,
                :segments, :credits_used, :whatsapp, :created_at, :metadata

    def initialize(data)
      @id = data["id"]
      @channel = data["channel"] || "whatsapp"
      @message_format = data["message_format"] || data["messageFormat"] || "whatsapp"
      @to = data["to"]
      @from = data["from"]
      @text = data["text"]
      @status = data["status"]
      @segments = data["segments"] || 1
      @credits_used = data["creditsUsed"] || data["credits_used"] || 0
      @whatsapp = data["whatsapp"] ? WhatsAppMessageDetails.new(data["whatsapp"]) : nil
      @created_at = data["createdAt"] || data["created_at"]
      @metadata = data["metadata"]
    end

    def delivered?
      status == "delivered"
    end

    def failed?
      status == "failed"
    end

    def to_h
      {
        id: id, channel: channel, message_format: message_format,
        to: to, from: from, text: text, status: status, segments: segments,
        credits_used: credits_used, whatsapp: whatsapp&.to_h,
        created_at: created_at, metadata: metadata
      }.compact
    end
  end

  # Connect numbers to WhatsApp. Starting a signup returns a +connect_url+
  # a human must complete in a browser.
  class WhatsAppSignupResource
    def initialize(client)
      @client = client
    end

    # Start connecting a number to WhatsApp.
    #
    # Charges a one-time $19 setup fee (no monthly fee) and returns a
    # +connect_url+. Completing the connection requires a human: hand the
    # URL to your user — they open it in a browser and log in with Facebook
    # to link their WhatsApp Business Account. Then poll {#get} until the
    # status is +"active"+.
    #
    # Calling again for a number with an in-flight signup returns the
    # existing signup (same +connect_url+) without charging again. Requires
    # a live API key.
    #
    # @param phone_number [String] The number to connect, in E.164 format.
    #   Must be an active number in your workspace.
    # @return [WhatsAppSignupSession]
    #
    # @example
    #   signup = client.whatsapp.signup.create(phone_number: "+15559876543")
    #   puts "Open #{signup.connect_url} and log in with Facebook"
    def create(phone_number:)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?

      response = @client.post("/whatsapp/signup", { phoneNumber: phone_number })
      WhatsAppSignupSession.new(response)
    end

    # Get the status of a WhatsApp signup.
    #
    # @param id [String] The signup's id
    # @return [WhatsAppSignup]
    # @raise [Sendly::NotFoundError] If no such signup exists in your workspace
    #
    # @example
    #   signup = client.whatsapp.signup.get("was_xxx")
    #   puts signup.failure_reasons if signup.failed?
    def get(id)
      raise ValidationError, "id is required" if id.nil? || id.to_s.empty?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.get("/whatsapp/signup/#{encoded_id}")
      WhatsAppSignup.new(response)
    end
  end

  # List the numbers connected (or connecting) to WhatsApp.
  class WhatsAppSendersResource
    def initialize(client)
      @client = client
    end

    # List your WhatsApp senders, newest first. An empty list means no
    # number is connected yet — start one with
    # {WhatsAppSignupResource#create}.
    #
    # @return [Hash] +{ senders: Array<WhatsAppSender> }+
    #
    # @example
    #   client.whatsapp.senders.list[:senders].each do |s|
    #     puts "#{s.phone_number} (#{s.display_name || 'no name yet'}) — #{s.status}"
    #   end
    def list
      response = @client.get("/whatsapp/senders")
      senders = (response["senders"] || []).map { |s| WhatsAppSender.new(s) }
      { senders: senders }
    end
  end

  # Manage Meta-reviewed message templates.
  class WhatsAppTemplatesResource
    def initialize(client)
      @client = client
    end

    # List your WhatsApp templates.
    #
    # @return [Hash] +{ templates: Array<WhatsAppTemplate> }+
    #
    # @example
    #   client.whatsapp.templates.list[:templates].each do |t|
    #     puts "#{t.name} (#{t.language}) — #{t.status}"
    #   end
    def list
      response = @client.get("/whatsapp/templates")
      templates = (response["templates"] || []).map { |t| WhatsAppTemplate.new(t) }
      { templates: templates }
    end

    # Create a template and submit it to Meta for review.
    #
    # Review usually takes 24-48h; the template is usable once its status
    # is +"APPROVED"+. Requires a live API key.
    #
    # @param sender [String] The WhatsApp-connected sending number this
    #   template belongs to, in E.164 format
    # @param name [String] Template name: lowercase letters, digits, and
    #   underscores (e.g. "order_shipped")
    # @param language [String] Template language code (e.g. "en_US")
    # @param category [String] "AUTHENTICATION", "UTILITY", or "MARKETING" —
    #   drives Meta review rules and pricing
    # @param body [String] Body text. Use {{1}}, {{2}}, ... for variables;
    #   every placeholder needs an example value in +examples+
    # @param header [String, nil] Optional text header
    # @param footer [String, nil] Optional footer line
    # @param buttons [Array<Hash>, nil] Optional buttons, each with :type
    #   ("url", "quick_reply", or "otp"), :text, and for url buttons a :url
    #   (may contain a {{1}} placeholder) plus :example values for review
    # @param examples [Hash, nil] Example values for body placeholders,
    #   keyed by placeholder number: { "1" => "Acme Inc", "2" => "#4821" }.
    #   Required when the body has variables.
    # @return [WhatsAppTemplate] The created template (status "PENDING"),
    #   with any submission warnings
    # @raise [Sendly::NotFoundError] If the sender isn't connected to WhatsApp
    #
    # @example
    #   template = client.whatsapp.templates.create(
    #     sender: "+15559876543",
    #     name: "order_shipped",
    #     language: "en_US",
    #     category: "UTILITY",
    #     body: "Hi {{1}}, your order {{2}} has shipped!",
    #     examples: { "1" => "Sam", "2" => "#4821" }
    #   )
    #   puts template.status  # "PENDING"
    def create(sender:, name:, language:, category:, body:,
               header: nil, footer: nil, buttons: nil, examples: nil)
      raise ValidationError, "sender is required" if sender.nil? || sender.to_s.empty?
      raise ValidationError, "name is required" if name.nil? || name.to_s.empty?
      raise ValidationError, "language is required" if language.nil? || language.to_s.empty?
      raise ValidationError, "category is required" if category.nil? || category.to_s.empty?
      raise ValidationError, "body is required" if body.nil? || body.to_s.empty?

      payload = {
        sender: sender,
        name: name,
        language: language,
        category: category,
        body: body
      }
      payload[:header] = header unless header.nil?
      payload[:footer] = footer unless footer.nil?
      payload[:buttons] = buttons if buttons
      payload[:examples] = examples if examples

      response = @client.post("/whatsapp/templates", payload)
      WhatsAppTemplate.new(response)
    end

    # Edit an APPROVED or REJECTED template and resubmit it for review.
    #
    # This is the recovery path for rejections: template names are locked
    # for ~30 days after deletion, so editing a rejected template (rather
    # than deleting and re-creating it) is the way to fix it. The updated
    # template goes back to "PENDING" review. Requires a live API key.
    #
    # @param id [String] The template's id
    # @param body [String, nil] Replacement body text
    # @param header [String, nil] Replacement text header
    # @param footer [String, nil] Replacement footer
    # @param buttons [Array<Hash>, nil] Replacement buttons
    # @param examples [Hash, nil] Replacement example values for body placeholders
    # @return [WhatsAppTemplate] The updated template (status "PENDING")
    # @raise [Sendly::NotFoundError] If no such template exists
    #
    # @example
    #   client.whatsapp.templates.update("wat_xxx",
    #     body: "Hi {{1}}, your order {{2}} is on its way!",
    #     examples: { "1" => "Sam", "2" => "#4821" }
    #   )
    def update(id, body: nil, header: nil, footer: nil, buttons: nil, examples: nil)
      raise ValidationError, "id is required" if id.nil? || id.to_s.empty?

      payload = {}
      payload[:body] = body unless body.nil?
      payload[:header] = header unless header.nil?
      payload[:footer] = footer unless footer.nil?
      payload[:buttons] = buttons unless buttons.nil?
      payload[:examples] = examples unless examples.nil?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.patch("/whatsapp/templates/#{encoded_id}", payload)
      WhatsAppTemplate.new(response)
    end

    # Delete a template.
    #
    # Meta locks a deleted template's name for ~30 days — re-creating it
    # fails with +template_name_locked+ until the lock lifts. To fix a
    # rejected template, prefer {#update}. Requires a live API key.
    #
    # @param id [String] The template's id
    # @return [WhatsAppTemplateDeletion]
    # @raise [Sendly::NotFoundError] If no such template exists
    #
    # @example
    #   client.whatsapp.templates.delete("wat_xxx")
    def delete(id)
      raise ValidationError, "id is required" if id.nil? || id.to_s.empty?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.delete("/whatsapp/templates/#{encoded_id}")
      WhatsAppTemplateDeletion.new(response)
    end
  end

  # WhatsApp resource — connect senders, manage templates, and check
  # 24-hour windows.
  #
  # WhatsApp is a first-class Sendly channel: connect a number you own,
  # create Meta-reviewed message templates, and send via
  # +client.messages.send(channel: "whatsapp", ...)+.
  #
  # Connecting a number is a one-time $19 setup (no monthly fee) and always
  # ends with a human step: {WhatsAppSignupResource#create} returns a
  # +connect_url+ that a person must open in a browser and log in with
  # Facebook to link their WhatsApp Business Account.
  #
  # Two ways to reach a recipient:
  #
  # - Inside a 24-hour window (the recipient messaged you in the last 24h):
  #   free-form text and media are allowed. Check with {#window}.
  # - Anytime: an approved template. Templates are reviewed by Meta
  #   (typically 24-48h) and categorized as authentication, utility, or
  #   marketing — pricing follows the category and destination country.
  #   Note: Meta has paused marketing template delivery to US (+1) numbers.
  #
  # @example Connect a number, create a template, then send
  #   # 1. Connect ($19 one-time; a human must open the connect URL)
  #   signup = client.whatsapp.signup.create(phone_number: "+15559876543")
  #   puts "Have your user open: #{signup.connect_url}"
  #
  #   # 2. Poll until active
  #   status = client.whatsapp.signup.get(signup.id)
  #
  #   # 3. Create a template (Meta reviews it, usually 24-48h)
  #   client.whatsapp.templates.create(
  #     sender: "+15559876543",
  #     name: "order_shipped",
  #     language: "en_US",
  #     category: "UTILITY",
  #     body: "Hi {{1}}, your order {{2}} has shipped!",
  #     examples: { "1" => "Sam", "2" => "#4821" }
  #   )
  #
  #   # 4. Send — free-form inside an open 24h window, template anytime
  #   window = client.whatsapp.window(from: "+15559876543", to: "+15551234567")
  class WhatsAppResource
    # @return [WhatsAppSignupResource] Connect numbers to WhatsApp
    attr_reader :signup

    # @return [WhatsAppSendersResource] List connected numbers
    attr_reader :senders

    # @return [WhatsAppTemplatesResource] Manage Meta-reviewed templates
    attr_reader :templates

    def initialize(client)
      @client = client
      @signup = WhatsAppSignupResource.new(client)
      @senders = WhatsAppSendersResource.new(client)
      @templates = WhatsAppTemplatesResource.new(client)
    end

    # Check whether a 24-hour customer-service window is open between one
    # of your WhatsApp senders and a recipient.
    #
    # Free-form text and media only deliver while a window is open (it
    # opens when the recipient messages you and lasts 24h from their last
    # inbound message). Outside a window, send an approved template.
    #
    # @param from [String] Your WhatsApp-connected sending number, in E.164 format
    # @param to [String] The recipient's number, in E.164 format
    # @return [WhatsAppWindow]
    #
    # @example
    #   window = client.whatsapp.window(from: "+15559876543", to: "+15551234567")
    #   unless window.open?
    #     # Use a template send instead of free-form text
    #   end
    def window(from:, to:)
      raise ValidationError, "from is required" if from.nil? || from.to_s.empty?
      raise ValidationError, "to is required" if to.nil? || to.to_s.empty?

      response = @client.get("/whatsapp/window", { from: from, to: to })
      WhatsAppWindow.new(response)
    end
  end
end
