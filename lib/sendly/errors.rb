# frozen_string_literal: true

module Sendly
  # Base error class for all Sendly errors
  class Error < StandardError
    # @return [String, nil] Error code from the API
    attr_reader :code

    # @return [Hash, nil] Additional error details
    attr_reader :details

    # @return [Integer, nil] HTTP status code
    attr_reader :status_code

    def initialize(message = nil, code: nil, details: nil, status_code: nil)
      @code = code
      @details = details
      @status_code = status_code
      super(message)
    end
  end

  # Raised when the API key is invalid or missing
  class AuthenticationError < Error
    def initialize(message = "Invalid or missing API key")
      super(message, code: "AUTHENTICATION_ERROR", status_code: 401)
    end
  end

  # Raised when the rate limit is exceeded
  class RateLimitError < Error
    # @return [Integer, nil] Seconds to wait before retrying
    attr_reader :retry_after

    def initialize(message = "Rate limit exceeded", retry_after: nil)
      @retry_after = retry_after
      super(message, code: "RATE_LIMIT_EXCEEDED", status_code: 429)
    end
  end

  # Raised when the account has insufficient credits
  class InsufficientCreditsError < Error
    def initialize(message = "Insufficient credits")
      super(message, code: "INSUFFICIENT_CREDITS", status_code: 402)
    end
  end

  # Raised when the request contains invalid parameters
  class ValidationError < Error
    # @return [Hash, nil] Field-specific validation errors
    attr_reader :field_errors

    def initialize(message = "Validation failed", field_errors: nil, details: nil)
      @field_errors = field_errors
      super(message, code: "VALIDATION_ERROR", details: details, status_code: 400)
    end
  end

  # Raised when the requested resource is not found
  class NotFoundError < Error
    def initialize(message = "Resource not found")
      super(message, code: "NOT_FOUND", status_code: 404)
    end
  end

  # Raised when a network error occurs
  class NetworkError < Error
    def initialize(message = "Network error occurred")
      super(message, code: "NETWORK_ERROR")
    end
  end

  # Raised when a timeout occurs
  class TimeoutError < NetworkError
    def initialize(message = "Request timed out")
      super(message)
      @code = "TIMEOUT_ERROR"
    end
  end

  # Raised for unexpected API errors
  class APIError < Error
    def initialize(message = "An unexpected error occurred", status_code: nil, code: nil, details: nil)
      super(message, code: code || "API_ERROR", status_code: status_code, details: details)
    end
  end

  # Raised for server errors (5xx)
  class ServerError < Error
    def initialize(message = "Server error occurred", status_code: 500)
      super(message, code: "SERVER_ERROR", status_code: status_code)
    end
  end

  # Convert API response to appropriate error
  class ErrorFactory
    def self.from_response(status, body)
      message = body["message"] || body["error"] || "Unknown error"
      code = body["code"]
      details = body["details"]

      case status
      when 400, 422
        ValidationError.new(message, details: details)
      when 401
        AuthenticationError.new(message)
      when 402
        InsufficientCreditsError.new(message)
      when 404
        NotFoundError.new(message)
      when 429
        retry_after = body["retry_after"] || body["retryAfter"]
        RateLimitError.new(message, retry_after: retry_after)
      when 500..599
        ServerError.new(message, status_code: status)
      else
        APIError.new(message, status_code: status, code: code, details: details)
      end
    end
  end
end
