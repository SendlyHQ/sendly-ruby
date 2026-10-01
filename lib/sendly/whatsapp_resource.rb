# frozen_string_literal: true

module Sendly
  # A newly started WhatsApp signup. Hand +connect_url+ to a human — they
  # open it in a browser and log in with Facebook to link their WhatsApp
  # Business Account. Poll {WhatsAppSignupResource#get} with +id+ until the
  # status is +"active"+. +STATUSES+ keeps +"expired"+ for compatibility;
  # the API does not send it.
  #
  # A number added to an already-connected WhatsApp Business Account (a
  # +business_account_id+ passed to {WhatsAppSignupResource#create}) has no
  # +connect_url+: its status is +"verifying"+ while Meta sends the number a
  # code, and +phone_number+, +business_account_id+, +verification_method+
  # (+"sms"+ or +"voice"+) and +verification_attempts_remaining+ are set.
  # +updated_at+ is when the session last changed. The status can also be
  # +"failed"+, with the reason in +failure_reasons+ (for example
  # +["verification_start_failed"]+), when a concurrent request for the same
  # number failed the session before this call returned it. Submit the code
  # with {WhatsAppSignupResource#verify}. These readers are nil on a
  # Facebook signup.
  class WhatsAppSignupSession
    attr_reader :id, :connect_url, :status, :phone_number, :business_account_id,
                :failure_reasons, :updated_at, :verification_method,
                :verification_attempts_remaining

    STATUSES = %w[initiated registering verifying active failed expired].freeze

    def initialize(data)
      @id = data["id"]
      @connect_url = data["connectUrl"] || data["connect_url"]
      @status = data["status"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @business_account_id = data["businessAccountId"] || data["business_account_id"]
      @failure_reasons = data["failureReasons"] || data["failure_reasons"]
      @updated_at = data["updatedAt"] || data["updated_at"]
      @verification_method = data["verificationMethod"] || data["verification_method"]
      @verification_attempts_remaining =
        data["verificationAttemptsRemaining"] || data["verification_attempts_remaining"]
    end

    def active?
      status == "active"
    end

    def failed?
      status == "failed"
    end

    def verifying?
      status == "verifying"
    end

    def to_h
      {
        id: id, connect_url: connect_url, status: status, phone_number: phone_number,
        business_account_id: business_account_id, failure_reasons: failure_reasons,
        updated_at: updated_at, verification_method: verification_method,
        verification_attempts_remaining: verification_attempts_remaining
      }.compact
    end
  end

  # The status of a WhatsApp signup. +status+ is +"initiated"+,
  # +"registering"+ (WhatsApp is activating the number; activation usually
  # takes a few minutes but can take hours, and a session that hasn't
  # finished about 6 hours after it began fails with +registration_timeout+
  # and the fee is refunded), +"verifying"+ (a number being added to an
  # already-connected account, waiting for its code), +"active"+ or
  # +"failed"+. The API does not send +"expired"+,
  # so {#expired?} is never true; it stays for compatibility.
  # +business_account_id+ is set only while the status is +"verifying"+ or
  # +"active"+ (from the start for a number added by code); it is nil while
  # +"initiated"+ or +"registering"+ and after a failure.
  # +failure_reasons+ is set when the status is +"failed"+, with one code:
  # +setup_fee_payment_failed+, +signup_abandoned+, +meta_exchange_failed+,
  # +registration_failed+, +waba_already_connected+, +waba_mismatch+ (the
  # WhatsApp Business Account chosen in the Facebook step doesn't hold the
  # verified number), +registration_timeout+ (activation hadn't finished
  # about 6 hours after the session began), +phone_number_mismatch+,
  # +verification_start_failed+ (WhatsApp couldn't start verifying an added
  # number), +verification_failed+ (too many wrong codes) or
  # +verification_expired+ (a verifying session left untouched for an hour).
  # If the connection fails, the $19 fee is refunded automatically.
  #
  # While the status is +"verifying"+, +verification_method+ (+"sms"+ or
  # +"voice"+) and +verification_attempts_remaining+ are set, and on
  # {WhatsAppSignupResource#get} +verification_code+ is the code once Meta's
  # text has arrived on the number (nil until then). Until a code has been
  # submitted, it is the newest code that has arrived since the signup
  # started, so after a resend it still shows the earlier code until the new
  # one arrives. Once WhatsApp has checked a code, only a code that arrived
  # after the last submission or resend is returned. A submission answered
  # with 502 +whatsapp_verification_unavailable+ is not counted, so the same
  # unchecked code can come back, and submitting it again with
  # {WhatsAppSignupResource#verify} is safe. All three are nil in any other
  # status.
  class WhatsAppSignup
    attr_reader :id, :status, :phone_number, :business_account_id,
                :failure_reasons, :updated_at, :verification_method,
                :verification_attempts_remaining, :verification_code

    STATUSES = %w[initiated registering verifying active failed expired].freeze

    def initialize(data)
      @id = data["id"]
      @status = data["status"]
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @business_account_id = data["businessAccountId"] || data["business_account_id"]
      @failure_reasons = data["failureReasons"] || data["failure_reasons"]
      @updated_at = data["updatedAt"] || data["updated_at"]
      @verification_method = data["verificationMethod"] || data["verification_method"]
      @verification_attempts_remaining =
        data["verificationAttemptsRemaining"] || data["verification_attempts_remaining"]
      @verification_code = data["verificationCode"] || data["verification_code"]
    end

    def active?
      status == "active"
    end

    def failed?
      status == "failed"
    end

    def verifying?
      status == "verifying"
    end

    def expired?
      status == "expired"
    end

    def to_h
      {
        id: id, status: status, phone_number: phone_number,
        business_account_id: business_account_id,
        failure_reasons: failure_reasons, updated_at: updated_at,
        verification_method: verification_method,
        verification_attempts_remaining: verification_attempts_remaining,
        verification_code: verification_code
      }.compact
    end
  end

  # A number connected (or connecting) to WhatsApp. +display_name+ is the
  # name recipients see — chosen during the connect flow and reviewed by
  # Meta; nil until set. +quality_rating+ is Meta's rating (e.g. "GREEN"),
  # nil before the first rating. +business_account_id+ is the WhatsApp
  # Business Account the number belongs to (pass it to
  # {WhatsAppSignupResource#create} to add another number to it) and
  # +business_name+ that account's business name; both are nil while the
  # sender is +"pending"+. +calling_enabled+ says whether WhatsApp calling
  # is on (see {WhatsAppSendersResource#set_calling}), and
  # +outbound_calling_allowed+ is false for every +1 number (the US, Canada
  # and the rest of the North American numbering plan) and for +20 (Egypt),
  # +84 (Vietnam) and +234 (Nigeria) numbers, where Meta forbids
  # business-initiated calls.
  class WhatsAppSender
    attr_reader :phone_number, :display_name, :status, :quality_rating,
                :created_at, :business_account_id, :business_name,
                :calling_enabled, :outbound_calling_allowed

    STATUSES = %w[pending active suspended].freeze

    def initialize(data)
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @display_name = data["displayName"] || data["display_name"]
      @status = data["status"]
      @quality_rating = data["qualityRating"] || data["quality_rating"]
      @created_at = data["createdAt"] || data["created_at"]
      @business_account_id = data["businessAccountId"] || data["business_account_id"]
      @business_name = data["businessName"] || data["business_name"]
      @calling_enabled = data.key?("callingEnabled") ? data["callingEnabled"] : data["calling_enabled"]
      @outbound_calling_allowed =
        data.key?("outboundCallingAllowed") ? data["outboundCallingAllowed"] : data["outbound_calling_allowed"]
    end

    def calling_enabled?
      calling_enabled == true
    end

    def outbound_calling_allowed?
      outbound_calling_allowed == true
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
        status: status, quality_rating: quality_rating, created_at: created_at,
        business_account_id: business_account_id, business_name: business_name,
        calling_enabled: calling_enabled, outbound_calling_allowed: outbound_calling_allowed
      }.compact
    end
  end

  # A sender's WhatsApp business profile — what recipients see when they
  # open the sender's details in WhatsApp. Unset fields are nil.
  # +profile_photo_url+ cannot be set through
  # {WhatsAppSendersResource#update_profile}; upload the photo with
  # {WhatsAppSendersResource#upload_profile_photo} and remove it with
  # {WhatsAppSendersResource#delete_profile_photo}.
  class WhatsAppSenderProfile
    attr_reader :phone_number, :display_name, :profile_photo_url, :category,
                :about, :description, :email, :website, :address

    def initialize(data)
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @display_name = data["displayName"] || data["display_name"]
      @profile_photo_url = data["profilePhotoUrl"] || data["profile_photo_url"]
      @category = data["category"]
      @about = data["about"]
      @description = data["description"]
      @email = data["email"]
      @website = data["website"]
      @address = data["address"]
    end

    def to_h
      {
        phone_number: phone_number, display_name: display_name,
        profile_photo_url: profile_photo_url, category: category,
        about: about, description: description, email: email,
        website: website, address: address
      }.compact
    end
  end

  # A command shown to a customer who types "/" in a chat with the sender.
  # +command+ is the name without the leading slash.
  class WhatsAppCommand
    attr_reader :command, :description

    def initialize(data)
      @command = data["command"]
      @description = data["description"]
    end

    def to_h
      { command: command, description: description }.compact
    end
  end

  # A sender's conversational components. +ice_breakers+ are the tappable
  # suggestions shown when someone opens a chat with the business for the
  # first time; +commands+ ({WhatsAppCommand}) are shown when the customer
  # types "/". Both are empty lists when none are set.
  class WhatsAppConversationalComponents
    attr_reader :phone_number, :ice_breakers, :commands

    def initialize(data)
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @ice_breakers = data["iceBreakers"] || data["ice_breakers"] || []
      @commands = (data["commands"] || []).map { |c| WhatsAppCommand.new(c) }
    end

    def to_h
      {
        phone_number: phone_number, ice_breakers: ice_breakers,
        commands: commands.map(&:to_h)
      }.compact
    end
  end

  # Whether WhatsApp calling is on for a sender. +outbound_calling_allowed+
  # is false for every +1 number (the US, Canada and the rest of the North
  # American numbering plan) and for +20 (Egypt), +84 (Vietnam) and +234
  # (Nigeria) numbers, where Meta forbids business-initiated calls.
  class WhatsAppCallingSettings
    attr_reader :phone_number, :calling_enabled, :outbound_calling_allowed

    def initialize(data)
      @phone_number = data["phoneNumber"] || data["phone_number"]
      @calling_enabled = data.key?("callingEnabled") ? data["callingEnabled"] : data["calling_enabled"]
      @outbound_calling_allowed =
        data.key?("outboundCallingAllowed") ? data["outboundCallingAllowed"] : data["outbound_calling_allowed"]
    end

    def calling_enabled?
      calling_enabled == true
    end

    def outbound_calling_allowed?
      outbound_calling_allowed == true
    end

    def to_h
      {
        phone_number: phone_number, calling_enabled: calling_enabled,
        outbound_calling_allowed: outbound_calling_allowed
      }.compact
    end
  end

  # A WhatsApp message template. Meta reviews every template (usually
  # 24-48h) and may reclassify its category — the category on the record
  # is what drives per-message pricing. +rejection_reason+ is set when the
  # status is +"REJECTED"+; +warnings+ carries non-blocking submission
  # warnings on create responses. +STATUSES+ lists the common review
  # statuses; Meta may report others, which come through in uppercase.
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
  # closes (ISO 8601). After it closes this is the past expiry, with +open+
  # false. It is nil when Sendly has no window on record for the pair; a
  # free-form send may still go through then if WhatsApp reports an open
  # window, and otherwise fails with +whatsapp_window_closed+. The API
  # returns exactly +{ open, expiresAt }+.
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
  # (WhatsApp has no segment concept), +text+ is the caption for a media
  # send (pass it as +text+ with +media_urls+) and nil for template sends
  # and media sent without a caption, and +whatsapp+ carries the
  # channel-specific details. +credits_used+: free-form text or media
  # inside the 24-hour window costs 1 credit each for the first 1,000 per
  # sending number per calendar month (UTC), then the destination's utility
  # template price; countries without a listed price use the default
  # utility price of 12 credits. Templates are priced by category and
  # destination country; countries without a listed price use 33
  # (marketing), 12 (utility) and 12 (authentication) credits. A failed
  # send gives its slot back.
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
  # a human must complete in a browser. A number added to an account that
  # is already connected is verified with a code instead ({#verify}).
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
    # a live API key with the +whatsapp:write+ scope (a test key gets 403
    # +whatsapp_requires_live_key+) and, in a team workspace, an owner or
    # admin (+settings:write+). After the Facebook step the signup stays
    # +"registering"+ while WhatsApp activates the number. Activation usually
    # takes a few minutes but can take hours. If it hasn't finished about 6
    # hours after the session began, the session fails with
    # +registration_timeout+ and the fee is refunded. If the connection
    # fails, the $19 fee is refunded automatically; once the number has
    # connected there is no refund, and a later disconnect gets nothing
    # back.
    #
    # To add a number to a WhatsApp Business Account this workspace has
    # already connected, pass its +business_account_id+ (as shown on
    # {WhatsAppSender#business_account_id}). There is no Facebook step and no
    # +connect_url+: the same $19 fee is charged, Meta sends the number a
    # 6-digit code by text or voice call, and the session is +"verifying"+
    # until you submit the code with {#verify}. Calling again for a number
    # that is verifying returns the same session without charging again or
    # sending a second code; a verifying session older than 3 hours is
    # expired (and refunded) and a new one is started.
    #
    # @param phone_number [String] The number to connect, in E.164 format.
    #   Must be an active number in your workspace.
    # @param business_account_id [String, nil] The WhatsApp Business Account
    #   to add the number to. It must be connected in this workspace with at
    #   least one active number.
    # @param verification_method [String, nil] How Meta sends the code:
    #   +"sms"+ (the default) or +"voice"+. Only with +business_account_id+.
    # @param display_name [String, nil] The business name WhatsApp shows for
    #   the number (at most 512 characters). Defaults to the account's
    #   existing sender display name, then its business name. Only with
    #   +business_account_id+.
    # @return [WhatsAppSignupSession]
    # @raise [Sendly::ServerError] +whatsapp_unavailable+ (503) while
    #   WhatsApp connections are unavailable. Nothing is charged. Only
    #   signup returns it, with +retryAfter+ 3600 in the body
    #   (+e.response_body["retryAfter"]+) and a +Retry-After: 3600+ header.
    #   The client retries it like any 5xx before raising.
    # @raise [Sendly::RateLimitError] +whatsapp_signup_limit_reached+ (429)
    #   after 5 failed, charged signups in 24 hours. Not retried; try again
    #   the next day.
    # @raise [Sendly::NotFoundError] +whatsapp_business_account_not_found+
    #   (404) when +business_account_id+ isn't connected in this workspace
    #   with an active number.
    # @raise [Sendly::ValidationError] +display_name_required+ (400) when no
    #   display name is given and the account has none to reuse, and
    #   +whatsapp_verification_start_failed+ (422) when WhatsApp refused to
    #   verify the number: final, the session failed and the fee is refunded.
    # @raise [Sendly::APIError] 409 +whatsapp_signup_in_progress+ (a Facebook
    #   connection for the number is in flight; +e.response_body["id"]+ is
    #   that session), 409 +whatsapp_verification_in_progress+ (a Facebook
    #   signup for a number that is being added by code, with that session in
    #   +e.response_body["id"]+; or, with +business_account_id+, the number is
    #   still being added, so try again in a moment) or 409
    #   +whatsapp_already_enabled+.
    # @raise [Sendly::InsufficientCreditsError] 402 +payment_method_required+
    #   or +payment_failed+ when the $19 fee can't be charged.
    # @raise [Sendly::ServerError] +whatsapp_verification_start_failed+ (502)
    #   when WhatsApp couldn't start verifying the number: the session failed
    #   and its fee is refunded, so start again. With +business_account_id+,
    #   a 5xx is raised at once and never retried by the client, because
    #   each retry would start a new charged session (a timeout or dropped
    #   connection is never retried either). Without it the client retries a
    #   5xx before raising, as before.
    #
    # @example
    #   signup = client.whatsapp.signup.create(phone_number: "+15559876543")
    #   puts "Open #{signup.connect_url} and log in with Facebook"
    #
    # @example Add a number to an account you already connected
    #   signup = client.whatsapp.signup.create(
    #     phone_number: "+14155550124",
    #     business_account_id: "102290129340398"
    #   )
    #   puts signup.status  # "verifying"
    def create(phone_number:, business_account_id: nil, verification_method: nil, display_name: nil)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?
      if !business_account_id.nil? && business_account_id.to_s.strip.empty?
        raise ValidationError, "business_account_id must be a non-empty string"
      end

      body = { phoneNumber: phone_number }
      body[:businessAccountId] = business_account_id.to_s unless business_account_id.nil?
      body[:verificationMethod] = verification_method unless verification_method.nil?
      body[:displayName] = display_name unless display_name.nil?

      by_code = !business_account_id.nil? && !business_account_id.to_s.empty?
      response = @client.post("/whatsapp/signup", body, retry_server_errors: !by_code)
      WhatsAppSignupSession.new(response)
    end

    # Submit the 6-digit code Meta sent to a number being added to a
    # connected account (a +"verifying"+ signup). Spaces and dashes are
    # ignored. On success the number is connected and the
    # +whatsapp_account.connected+ webhook fires. A signup that is already
    # +"active"+ comes back unchanged. The code can also be read from
    # {WhatsAppSignup#verification_code} once Meta's text arrives on the
    # number. Requires a live API key with the +whatsapp:write+ scope and, in
    # a team workspace, an owner or admin (+settings:write+).
    #
    # @param id [String] The signup's id
    # @param code [String] The 6-digit code
    # @return [WhatsAppSignup] The signup, +"active"+ on success
    # @raise [Sendly::ValidationError] +invalid_verification_code+ (400) when
    #   the code isn't 6 digits, and +whatsapp_verification_code_invalid+
    #   (422) for a wrong code, with the attempts left in
    #   +e.response_body["attemptsRemaining"]+
    # @raise [Sendly::APIError] 409 +whatsapp_verification_failed+ after 5
    #   wrong codes (the session failed, the fee is refunded and
    #   +whatsapp_account.failed+ fires), 409 +whatsapp_verification_busy+
    #   while another code for the number is being checked (try again), or
    #   409 +signup_not_active+ when the signup isn't waiting for a code or is
    #   older than 3 hours
    # @raise [Sendly::NotFoundError] +signup_not_found+ (404)
    # @raise [Sendly::ServerError] 502 +whatsapp_verification_unavailable+
    #   (WhatsApp couldn't check the code; the attempt isn't counted) or 502
    #   +whatsapp_activation_pending+ (the code was accepted but connecting
    #   the number didn't finish; check back shortly with {#get}). A 5xx, a
    #   timeout or a dropped connection is raised at once and never retried
    #   by the client: each submission
    #   uses one of the 5 attempts, and after +whatsapp_activation_pending+
    #   WhatsApp has already accepted the code.
    #
    # @example
    #   signup = client.whatsapp.signup.verify(signup.id, code: "482913")
    #   puts signup.status  # "active"
    def verify(id, code:)
      raise ValidationError, "id is required" if id.nil? || id.to_s.empty?
      raise ValidationError, "code is required" if code.nil? || code.to_s.empty?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.post("/whatsapp/signup/#{encoded_id}/verify", { code: code }, retry_server_errors: false)
      WhatsAppSignup.new(response)
    end

    # Ask Meta to send a new code to a number being added to a connected
    # account. Codes can be requested at most every 30 seconds, counted from
    # the signup's last change (a code submission included). A signup that
    # is already +"active"+ comes back unchanged. Requires a live API key with
    # the +whatsapp:write+ scope and, in a team workspace, an owner or admin
    # (+settings:write+).
    #
    # @param id [String] The signup's id
    # @param verification_method [String, nil] +"sms"+ (the default) or
    #   +"voice"+
    # @return [WhatsAppSignup]
    # @raise [Sendly::RateLimitError] +whatsapp_verification_resend_too_soon+
    #   (429), raised at once with the seconds to wait in +e.retry_after+
    # @raise [Sendly::ValidationError] +whatsapp_verification_resend_failed+
    #   (422) when WhatsApp wouldn't send another code yet
    # @raise [Sendly::APIError] 409 +signup_not_active+ when the signup isn't
    #   waiting for a code or is older than 3 hours
    # @raise [Sendly::NotFoundError] +signup_not_found+ (404)
    # @raise [Sendly::ServerError] +whatsapp_verification_resend_failed+
    #   (502) when WhatsApp couldn't be reached. The client retries a 5xx
    #   before raising.
    #
    # @example
    #   client.whatsapp.signup.resend(signup.id, verification_method: "voice")
    def resend(id, verification_method: nil)
      raise ValidationError, "id is required" if id.nil? || id.to_s.empty?

      body = {}
      body[:verificationMethod] = verification_method unless verification_method.nil?

      encoded_id = URI.encode_www_form_component(id)
      response = @client.post("/whatsapp/signup/#{encoded_id}/resend", body)
      WhatsAppSignup.new(response)
    end

    # Get the status of a WhatsApp signup. Needs the +whatsapp:read+ scope;
    # test keys work. While a number is +"verifying"+ the signup carries
    # {WhatsAppSignup#verification_code} once Meta's text has arrived.
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

  # List the numbers connected (or connecting) to WhatsApp, and manage
  # their business profiles, profile photos, conversational components and
  # WhatsApp calling.
  class WhatsAppSendersResource
    def initialize(client)
      @client = client
    end

    # List your WhatsApp senders, newest first. An empty list means no
    # number is connected yet — start one with
    # {WhatsAppSignupResource#create}. Needs the +whatsapp:read+ scope; test
    # keys work.
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

    # Get a sender's WhatsApp business profile.
    #
    # The business profile is what recipients see when they open the
    # sender's details in WhatsApp: display name, photo, category, about
    # line, description, and contact details. The sender must be +"active"+
    # (connected to WhatsApp). Needs the +whatsapp:read+ scope; test keys
    # work.
    #
    # @param phone_number [String] Your WhatsApp-connected sending number,
    #   in E.164 format
    # @return [WhatsAppSenderProfile]
    # @raise [Sendly::NotFoundError] If the number isn't connected to WhatsApp
    #
    # @example
    #   profile = client.whatsapp.senders.get_profile("+15559876543")
    #   puts profile.display_name
    #   puts profile.about
    def get_profile(phone_number)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?

      encoded_number = URI.encode_www_form_component(phone_number)
      response = @client.get("/whatsapp/senders/#{encoded_number}/profile")
      WhatsAppSenderProfile.new(response)
    end

    # Update a sender's WhatsApp business profile.
    #
    # Pass only the fields to change; omitted fields keep their current
    # value. +about+ is limited to 139 characters and +description+ to 512.
    # +display_name+ changes are reviewed by Meta before they take effect.
    # The profile photo cannot be set through this method; use
    # {#upload_profile_photo}. Requires a live
    # API key with the +whatsapp:write+ scope and, in a team workspace, an
    # owner or admin (+settings:write+).
    #
    # @param phone_number [String] Your WhatsApp-connected sending number,
    #   in E.164 format
    # @param display_name [String, nil] The business name recipients see
    # @param about [String, nil] Short profile line (max 139 characters)
    # @param description [String, nil] Longer business description (max 512 characters)
    # @param category [String, nil] Business category shown on the profile
    # @param email [String, nil] Contact email shown on the profile
    # @param website [String, nil] Website shown on the profile
    # @param address [String, nil] Business address shown on the profile
    # @return [WhatsAppSenderProfile] The updated profile
    # @raise [Sendly::ValidationError] If no field is given, or a field is too long
    # @raise [Sendly::NotFoundError] If the number isn't connected to WhatsApp
    #
    # @example
    #   client.whatsapp.senders.update_profile("+15559876543",
    #     about: "Fresh roasted coffee, delivered.",
    #     website: "https://acme.example"
    #   )
    def update_profile(phone_number, display_name: nil, about: nil, description: nil,
                       category: nil, email: nil, website: nil, address: nil)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?

      body = {}
      body[:displayName] = display_name unless display_name.nil?
      body[:about] = about unless about.nil?
      body[:description] = description unless description.nil?
      body[:category] = category unless category.nil?
      body[:email] = email unless email.nil?
      body[:website] = website unless website.nil?
      body[:address] = address unless address.nil?
      raise ValidationError, "Provide at least one profile field to update" if body.empty?

      encoded_number = URI.encode_www_form_component(phone_number)
      response = @client.patch("/whatsapp/senders/#{encoded_number}/profile", body)
      WhatsAppSenderProfile.new(response)
    end

    # Upload a sender's WhatsApp profile photo, replacing the current one.
    #
    # The photo must be a JPEG or PNG (checked by its bytes, not by
    # +content_type+) of at most 5 MB. WhatsApp wants it square and at least
    # 192 pixels wide (640 recommended). Free. Requires a live API key with
    # the +whatsapp:write+ scope and, in a team workspace, an owner or admin
    # (+settings:write+).
    #
    # @param phone_number [String] Your WhatsApp-connected sending number,
    #   in E.164 format
    # @param file [String, IO] A file path or an IO holding the image
    # @param content_type [String] MIME type sent with the file
    # @param filename [String] Name sent with the file
    # @return [WhatsAppSenderProfile] The profile with its new photo
    # @raise [Sendly::ValidationError] +whatsapp_profile_photo_invalid+ (400)
    #   when the file isn't a JPEG or PNG, or +file_required+ (400)
    # @raise [Sendly::APIError] +whatsapp_profile_photo_too_large+ with
    #   +status_code+ 413 when the photo is over 5 MB
    # @raise [Sendly::NotFoundError] +whatsapp_sender_not_connected+ (404)
    # @raise [Sendly::ServerError] +whatsapp_profile_update_failed+ (502)
    #   when WhatsApp refused the image or couldn't be reached. A 5xx, a
    #   timeout or a dropped connection is raised at once and never retried
    #   by the client; check the image is
    #   square and at least 192 pixels wide before trying again.
    #
    # @example
    #   client.whatsapp.senders.upload_profile_photo("+14155550123", "logo.png",
    #     content_type: "image/png", filename: "logo.png")
    def upload_profile_photo(phone_number, file, content_type: "image/jpeg", filename: "profile.jpg")
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?
      raise ValidationError, "file is required" if file.nil?

      encoded_number = URI.encode_www_form_component(phone_number)
      response = @client.post_multipart("/whatsapp/senders/#{encoded_number}/profile/photo", file,
                                        content_type: content_type, filename: filename,
                                        retry_server_errors: false)
      WhatsAppSenderProfile.new(response)
    end

    # Remove a sender's WhatsApp profile photo. Requires a live API key with
    # the +whatsapp:write+ scope and, in a team workspace, an owner or admin
    # (+settings:write+).
    #
    # @param phone_number [String] Your WhatsApp-connected sending number,
    #   in E.164 format
    # @return [WhatsAppSenderProfile] The profile, normally with
    #   +profile_photo_url+ nil
    # @raise [Sendly::NotFoundError] +whatsapp_sender_not_connected+ (404)
    # @raise [Sendly::ServerError] +whatsapp_profile_update_failed+ (502).
    #   The client retries a 5xx before raising.
    #
    # @example
    #   client.whatsapp.senders.delete_profile_photo("+14155550123")
    def delete_profile_photo(phone_number)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?

      encoded_number = URI.encode_www_form_component(phone_number)
      response = @client.delete("/whatsapp/senders/#{encoded_number}/profile/photo")
      WhatsAppSenderProfile.new(response)
    end

    # Get a sender's conversational components: the ice breakers shown when
    # someone opens a chat with the business for the first time, and the
    # commands shown when the customer types "/". Needs the +whatsapp:read+
    # scope; test keys work.
    #
    # @param phone_number [String] Your WhatsApp-connected sending number,
    #   in E.164 format
    # @return [WhatsAppConversationalComponents]
    # @raise [Sendly::NotFoundError] +whatsapp_sender_not_connected+ (404)
    # @raise [Sendly::ServerError]
    #   +whatsapp_conversational_components_fetch_failed+ (502). The client
    #   retries a 5xx before raising.
    #
    # @example
    #   components = client.whatsapp.senders.get_conversational_components("+14155550123")
    #   components.commands.each { |c| puts "/#{c.command}: #{c.description}" }
    def get_conversational_components(phone_number)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?

      encoded_number = URI.encode_www_form_component(phone_number)
      response = @client.get("/whatsapp/senders/#{encoded_number}/conversational_components")
      WhatsAppConversationalComponents.new(response)
    end

    # Replace a sender's ice breakers, commands, or both.
    #
    # Each list you pass replaces the stored one, and +[]+ clears it; a list
    # you leave out is kept. Ice breakers: at most 4, each 1-80 characters,
    # no duplicates. Commands: at most 30, each a hash with +:command+
    # (letters, digits and underscores, 1-32 characters; a leading "/" is
    # dropped) and +:description+ (1-256 characters), no duplicate commands.
    # The {WhatsAppCommand} objects a read returns can be passed back. Free.
    # Requires a live API key with the +whatsapp:write+ scope and, in a team
    # workspace, an owner or admin (+settings:write+).
    #
    # @param phone_number [String] Your WhatsApp-connected sending number,
    #   in E.164 format
    # @param ice_breakers [Array<String>, nil] The new ice breakers
    # @param commands [Array<Hash, WhatsAppCommand>, nil] The new commands
    # @return [WhatsAppConversationalComponents] The stored components
    # @raise [Sendly::ValidationError] If neither list is given, or
    #   +invalid_request+ (400) with a message naming the problem
    # @raise [Sendly::NotFoundError] +whatsapp_sender_not_connected+ (404)
    # @raise [Sendly::ServerError]
    #   +whatsapp_conversational_components_update_failed+ (502). The client
    #   retries a 5xx before raising.
    #
    # @example
    #   client.whatsapp.senders.update_conversational_components("+14155550123",
    #     ice_breakers: ["Track my order", "Opening hours"],
    #     commands: [{ command: "menu", description: "See today's menu" }]
    #   )
    def update_conversational_components(phone_number, ice_breakers: nil, commands: nil)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?

      body = {}
      body[:iceBreakers] = ice_breakers unless ice_breakers.nil?
      body[:commands] = commands.map { |c| c.is_a?(WhatsAppCommand) ? c.to_h : c } unless commands.nil?
      raise ValidationError, "Provide ice_breakers, commands, or both" if body.empty?

      encoded_number = URI.encode_www_form_component(phone_number)
      response = @client.patch("/whatsapp/senders/#{encoded_number}/conversational_components", body)
      WhatsAppConversationalComponents.new(response)
    end

    # Switch WhatsApp calling on or off for a sender. Free.
    #
    # Once it is on, a WhatsApp user calling the number rings exactly like
    # a phone call (in the dashboard or with your AI agent, per the number's
    # voice settings), billed at the normal inbound rate. Turning it on
    # needs voice switched on for the number first. There is no API for
    # placing WhatsApp calls. Requires a live API key with the
    # +whatsapp:write+ scope and, in a team workspace, an owner or admin
    # (+settings:write+).
    #
    # @param phone_number [String] Your WhatsApp-connected sending number,
    #   in E.164 format
    # @param enabled [Boolean] true to switch calling on, false to switch it off
    # @return [WhatsAppCallingSettings]
    # @raise [Sendly::APIError] +voice_not_enabled+ with +status_code+ 409
    #   when voice isn't on for the number
    # @raise [Sendly::ValidationError] +whatsapp_calling_unavailable+ (422)
    #   when Meta refused: calling needs the account at the 2,000
    #   recipients a day messaging limit and an approved display name
    # @raise [Sendly::NotFoundError] +whatsapp_sender_not_connected+ (404)
    # @raise [Sendly::ServerError] +whatsapp_calling_update_failed+ (502).
    #   The client retries a 5xx before raising.
    #
    # @example
    #   settings = client.whatsapp.senders.set_calling("+14155550123", enabled: true)
    #   puts settings.calling_enabled?
    def set_calling(phone_number, enabled:)
      raise ValidationError, "phone_number is required" if phone_number.nil? || phone_number.to_s.empty?

      encoded_number = URI.encode_www_form_component(phone_number)
      response = @client.patch("/whatsapp/senders/#{encoded_number}/calling", { enabled: enabled })
      WhatsAppCallingSettings.new(response)
    end
  end

  # Manage Meta-reviewed message templates.
  class WhatsAppTemplatesResource
    def initialize(client)
      @client = client
    end

    # List your WhatsApp templates. Needs the +whatsapp:read+ scope; test
    # keys work.
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
    # is +"APPROVED"+. Requires a live API key with the +whatsapp:write+
    # scope and, in a team workspace, an owner, admin or member
    # (+templates:write+). A marketing template without an opt-out button is
    # still accepted, with a warning.
    #
    # @param sender [String] The WhatsApp-connected sending number this
    #   template belongs to, in E.164 format
    # @param name [String] Template name: lowercase letters, digits, and
    #   underscores (e.g. "order_shipped")
    # @param language [String] Template language code (e.g. "en_US")
    # @param category [String] "AUTHENTICATION", "UTILITY", or "MARKETING"
    #   (the server uppercases it). Required, with no default; it drives Meta
    #   review rules and pricing and can't be changed later
    # @param body [String] Body text. Use {{1}}, {{2}}, ... for variables;
    #   every placeholder needs an example value in +examples+
    # @param header [String, nil] Optional text header. Fixed text only: a
    #   header containing {{n}} is refused with
    #   +template_header_variable_unsupported+
    # @param footer [String, nil] Optional footer line
    # @param buttons [Array<Hash>, nil] Optional buttons, each with :type
    #   ("url", "quick_reply", or "otp"), :text, and for url buttons a :url
    #   (may contain a {{1}} placeholder) plus :example values for review
    # @param examples [Hash, nil] Example values for body placeholders,
    #   keyed by placeholder number: { "1" => "Acme Inc", "2" => "#4821" }.
    #   Required when the body has variables.
    # @return [WhatsAppTemplate] The created template (status "PENDING"),
    #   with any submission warnings
    # @raise [Sendly::NotFoundError] +whatsapp_sender_not_connected+ (404) if
    #   the sender isn't connected to WhatsApp; this is checked first
    # @raise [Sendly::ValidationError] If the API refuses the template with a
    #   400 +template_*+ code (in +e.response_body["error"]+) and a readable
    #   message: +template_category_invalid+ (category missing or not one of
    #   the three), +template_authentication_otp_button_required+,
    #   +template_authentication_no_links+ (a link in the body or a URL
    #   button on an authentication template) or
    #   +template_header_variable_unsupported+
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
    # template goes back to "PENDING" review. The category can't be
    # changed. Requires a live API key with the +whatsapp:write+ scope and,
    # in a team workspace, an owner, admin or member (+templates:write+).
    #
    # @param id [String] The template's id
    # @param body [String, nil] Replacement body text
    # @param header [String, nil] Replacement text header; it can't contain
    #   {{n}} variables (+template_header_variable_unsupported+)
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
    # rejected template, prefer {#update}. Requires a live API key with the
    # +whatsapp:write+ scope and, in a team workspace, an owner, admin or
    # member (+templates:write+).
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

  # WhatsApp resource — connect senders, manage their business profiles and
  # templates, and check 24-hour windows.
  #
  # WhatsApp is a first-class Sendly channel: connect a number you own,
  # create Meta-reviewed message templates, and send via
  # +client.messages.send(channel: "whatsapp", ...)+.
  #
  # Connecting a number is a one-time $19 setup (no monthly fee). The first
  # number always ends with a human step: {WhatsAppSignupResource#create}
  # returns a +connect_url+ that a person must open in a browser and log in
  # with Facebook to link their WhatsApp Business Account. More numbers can
  # then be added to that account with a code Meta sends to the number
  # (+business_account_id:+ on create, then {WhatsAppSignupResource#verify}).
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
  # Pricing: free-form text or media inside the 24-hour window costs 1
  # credit each for the first 1,000 per sending number per calendar month
  # (UTC), then the destination's utility template price; countries without
  # a listed price use the default utility price of 12 credits. Templates
  # are priced by category and destination country; countries without a
  # listed price use 33 (marketing), 12 (utility) and 12 (authentication)
  # credits. A failed send gives its slot back.
  #
  # Scopes and keys: sends go through +messages.send(channel: "whatsapp")+
  # and need +sms:send+, not +whatsapp:write+, and a live key. Reads (signup
  # status, templates, the window, senders and sender profiles) need
  # +whatsapp:read+ and accept test keys. Signup, template create/edit/delete
  # and profile edits need +whatsapp:write+ and a live key (otherwise 403
  # +whatsapp_requires_live_key+). In a team workspace, connecting and
  # profile edits need an owner or admin (+settings:write+), and template
  # writes need an owner, admin or member (+templates:write+); a missing
  # role returns 403 +insufficient_permissions+. Reading conversational
  # components needs +whatsapp:read+ too and accepts test keys. The profile
  # photo, conversational component and calling changes, and submitting or
  # resending a verification code, need the same as a profile edit.
  #
  # WhatsApp is enabled per person: the user who owns the API key, not the
  # workspace. While it is off, sends return 403 +whatsapp_not_enabled+ and
  # every method on this resource gets 404 +not_found+.
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

    # @return [WhatsAppSendersResource] List connected numbers and manage
    #   their business profiles, photos, conversational components and calling
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
    # inbound message). Outside a window, send an approved template. Needs
    # the +whatsapp:read+ scope; test keys work.
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
