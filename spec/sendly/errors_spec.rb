# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Sendly Error Classes' do
  describe Sendly::Error do
    it 'is a StandardError subclass' do
      expect(Sendly::Error.ancestors).to include(StandardError)
    end

    it 'initializes with message' do
      error = Sendly::Error.new('Test error')
      expect(error.message).to eq('Test error')
    end

    it 'stores error code' do
      error = Sendly::Error.new('Test error', code: 'TEST_ERROR')
      expect(error.code).to eq('TEST_ERROR')
    end

    it 'stores error details' do
      details = { field: 'phone', issue: 'invalid format' }
      error = Sendly::Error.new('Test error', details: details)
      expect(error.details).to eq(details)
    end

    it 'stores HTTP status code' do
      error = Sendly::Error.new('Test error', status_code: 400)
      expect(error.status_code).to eq(400)
    end

    it 'accepts all parameters together' do
      error = Sendly::Error.new(
        'Test error',
        code: 'TEST_ERROR',
        details: { foo: 'bar' },
        status_code: 400
      )
      expect(error.message).to eq('Test error')
      expect(error.code).to eq('TEST_ERROR')
      expect(error.details).to eq({ foo: 'bar' })
      expect(error.status_code).to eq(400)
    end

    it 'allows nil parameters' do
      error = Sendly::Error.new
      expect(error.code).to be_nil
      expect(error.details).to be_nil
      expect(error.status_code).to be_nil
    end
  end

  describe Sendly::AuthenticationError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::AuthenticationError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::AuthenticationError.new
      expect(error.message).to eq('Invalid or missing API key')
    end

    it 'accepts custom message' do
      error = Sendly::AuthenticationError.new('Custom auth error')
      expect(error.message).to eq('Custom auth error')
    end

    it 'has AUTHENTICATION_ERROR code' do
      error = Sendly::AuthenticationError.new
      expect(error.code).to eq('AUTHENTICATION_ERROR')
    end

    it 'has 401 status code' do
      error = Sendly::AuthenticationError.new
      expect(error.status_code).to eq(401)
    end
  end

  describe Sendly::RateLimitError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::RateLimitError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::RateLimitError.new
      expect(error.message).to eq('Rate limit exceeded')
    end

    it 'accepts custom message' do
      error = Sendly::RateLimitError.new('Custom rate limit error')
      expect(error.message).to eq('Custom rate limit error')
    end

    it 'has RATE_LIMIT_EXCEEDED code' do
      error = Sendly::RateLimitError.new
      expect(error.code).to eq('RATE_LIMIT_EXCEEDED')
    end

    it 'has 429 status code' do
      error = Sendly::RateLimitError.new
      expect(error.status_code).to eq(429)
    end

    it 'stores retry_after value' do
      error = Sendly::RateLimitError.new('Rate limited', retry_after: 60)
      expect(error.retry_after).to eq(60)
    end

    it 'allows nil retry_after' do
      error = Sendly::RateLimitError.new
      expect(error.retry_after).to be_nil
    end
  end

  describe Sendly::InsufficientCreditsError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::InsufficientCreditsError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::InsufficientCreditsError.new
      expect(error.message).to eq('Insufficient credits')
    end

    it 'accepts custom message' do
      error = Sendly::InsufficientCreditsError.new('You need more credits')
      expect(error.message).to eq('You need more credits')
    end

    it 'has INSUFFICIENT_CREDITS code' do
      error = Sendly::InsufficientCreditsError.new
      expect(error.code).to eq('INSUFFICIENT_CREDITS')
    end

    it 'has 402 status code' do
      error = Sendly::InsufficientCreditsError.new
      expect(error.status_code).to eq(402)
    end
  end

  describe Sendly::ValidationError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::ValidationError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::ValidationError.new
      expect(error.message).to eq('Validation failed')
    end

    it 'accepts custom message' do
      error = Sendly::ValidationError.new('Invalid phone number')
      expect(error.message).to eq('Invalid phone number')
    end

    it 'has VALIDATION_ERROR code' do
      error = Sendly::ValidationError.new
      expect(error.code).to eq('VALIDATION_ERROR')
    end

    it 'has 400 status code' do
      error = Sendly::ValidationError.new
      expect(error.status_code).to eq(400)
    end

    it 'stores field_errors' do
      field_errors = { phone: 'Invalid format', text: 'Too long' }
      error = Sendly::ValidationError.new('Validation failed', field_errors: field_errors)
      expect(error.field_errors).to eq(field_errors)
    end

    it 'stores details' do
      details = { info: 'Additional validation info' }
      error = Sendly::ValidationError.new('Validation failed', details: details)
      expect(error.details).to eq(details)
    end

    it 'allows nil field_errors and details' do
      error = Sendly::ValidationError.new
      expect(error.field_errors).to be_nil
      expect(error.details).to be_nil
    end
  end

  describe Sendly::NotFoundError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::NotFoundError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::NotFoundError.new
      expect(error.message).to eq('Resource not found')
    end

    it 'accepts custom message' do
      error = Sendly::NotFoundError.new('Message not found')
      expect(error.message).to eq('Message not found')
    end

    it 'has NOT_FOUND code' do
      error = Sendly::NotFoundError.new
      expect(error.code).to eq('NOT_FOUND')
    end

    it 'has 404 status code' do
      error = Sendly::NotFoundError.new
      expect(error.status_code).to eq(404)
    end
  end

  describe Sendly::NetworkError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::NetworkError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::NetworkError.new
      expect(error.message).to eq('Network error occurred')
    end

    it 'accepts custom message' do
      error = Sendly::NetworkError.new('Connection failed')
      expect(error.message).to eq('Connection failed')
    end

    it 'has NETWORK_ERROR code' do
      error = Sendly::NetworkError.new
      expect(error.code).to eq('NETWORK_ERROR')
    end
  end

  describe Sendly::TimeoutError do
    it 'inherits from Sendly::NetworkError' do
      expect(Sendly::TimeoutError.ancestors).to include(Sendly::NetworkError)
      expect(Sendly::TimeoutError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::TimeoutError.new
      expect(error.message).to eq('Request timed out')
    end

    it 'accepts custom message' do
      error = Sendly::TimeoutError.new('Connection timed out after 30s')
      expect(error.message).to eq('Connection timed out after 30s')
    end

    it 'has TIMEOUT_ERROR code' do
      error = Sendly::TimeoutError.new
      expect(error.code).to eq('TIMEOUT_ERROR')
    end
  end

  describe Sendly::APIError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::APIError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::APIError.new
      expect(error.message).to eq('An unexpected error occurred')
    end

    it 'accepts custom message' do
      error = Sendly::APIError.new('Something went wrong')
      expect(error.message).to eq('Something went wrong')
    end

    it 'has API_ERROR code by default' do
      error = Sendly::APIError.new
      expect(error.code).to eq('API_ERROR')
    end

    it 'accepts custom code' do
      error = Sendly::APIError.new('Error', code: 'CUSTOM_ERROR')
      expect(error.code).to eq('CUSTOM_ERROR')
    end

    it 'accepts status code' do
      error = Sendly::APIError.new('Error', status_code: 418)
      expect(error.status_code).to eq(418)
    end

    it 'accepts details' do
      details = { reason: 'Teapot' }
      error = Sendly::APIError.new('Error', details: details)
      expect(error.details).to eq(details)
    end
  end

  describe Sendly::ServerError do
    it 'inherits from Sendly::Error' do
      expect(Sendly::ServerError.ancestors).to include(Sendly::Error)
    end

    it 'has default message' do
      error = Sendly::ServerError.new
      expect(error.message).to eq('Server error occurred')
    end

    it 'accepts custom message' do
      error = Sendly::ServerError.new('Internal server error')
      expect(error.message).to eq('Internal server error')
    end

    it 'has SERVER_ERROR code' do
      error = Sendly::ServerError.new
      expect(error.code).to eq('SERVER_ERROR')
    end

    it 'has 500 status code by default' do
      error = Sendly::ServerError.new
      expect(error.status_code).to eq(500)
    end

    it 'accepts custom status code' do
      error = Sendly::ServerError.new('Bad Gateway', status_code: 502)
      expect(error.status_code).to eq(502)
    end
  end

  describe Sendly::ErrorFactory do
    describe '.from_response' do
      context 'HTTP 400 - Validation error' do
        it 'creates ValidationError' do
          error = Sendly::ErrorFactory.from_response(400, { 'message' => 'Invalid input' })
          expect(error).to be_a(Sendly::ValidationError)
          expect(error.message).to eq('Invalid input')
        end

        it 'includes details' do
          body = { 'message' => 'Validation failed', 'details' => { 'phone' => 'invalid' } }
          error = Sendly::ErrorFactory.from_response(400, body)
          expect(error.details).to eq({ 'phone' => 'invalid' })
        end
      end

      context 'HTTP 422 - Validation error' do
        it 'creates ValidationError' do
          error = Sendly::ErrorFactory.from_response(422, { 'message' => 'Unprocessable entity' })
          expect(error).to be_a(Sendly::ValidationError)
          expect(error.message).to eq('Unprocessable entity')
        end
      end

      context 'HTTP 401 - Authentication error' do
        it 'creates AuthenticationError' do
          error = Sendly::ErrorFactory.from_response(401, { 'message' => 'Invalid API key' })
          expect(error).to be_a(Sendly::AuthenticationError)
          expect(error.message).to eq('Invalid API key')
        end

        it 'uses error field as fallback' do
          error = Sendly::ErrorFactory.from_response(401, { 'error' => 'Unauthorized' })
          expect(error.message).to eq('Unauthorized')
        end

        it 'uses default message if no message provided' do
          error = Sendly::ErrorFactory.from_response(401, {})
          expect(error.message).to eq('Unknown error')
        end
      end

      context 'HTTP 402 - Insufficient credits' do
        it 'creates InsufficientCreditsError' do
          error = Sendly::ErrorFactory.from_response(402, { 'message' => 'No credits remaining' })
          expect(error).to be_a(Sendly::InsufficientCreditsError)
          expect(error.message).to eq('No credits remaining')
        end
      end

      context 'HTTP 404 - Not found' do
        it 'creates NotFoundError' do
          error = Sendly::ErrorFactory.from_response(404, { 'message' => 'Message not found' })
          expect(error).to be_a(Sendly::NotFoundError)
          expect(error.message).to eq('Message not found')
        end
      end

      context 'HTTP 429 - Rate limit' do
        it 'creates RateLimitError' do
          error = Sendly::ErrorFactory.from_response(429, { 'message' => 'Too many requests' })
          expect(error).to be_a(Sendly::RateLimitError)
          expect(error.message).to eq('Too many requests')
        end

        it 'extracts retry_after from response' do
          body = { 'message' => 'Rate limited', 'retry_after' => 60 }
          error = Sendly::ErrorFactory.from_response(429, body)
          expect(error.retry_after).to eq(60)
        end

        it 'extracts retryAfter (camelCase) from response' do
          body = { 'message' => 'Rate limited', 'retryAfter' => 0.01 }
          error = Sendly::ErrorFactory.from_response(429, body)
          expect(error.retry_after).to eq(0.01)
        end

        it 'handles missing retry_after' do
          error = Sendly::ErrorFactory.from_response(429, { 'message' => 'Rate limited' })
          expect(error.retry_after).to be_nil
        end
      end

      context 'HTTP 500 - Server error' do
        it 'creates ServerError' do
          error = Sendly::ErrorFactory.from_response(500, { 'message' => 'Internal server error' })
          expect(error).to be_a(Sendly::ServerError)
          expect(error.message).to eq('Internal server error')
          expect(error.status_code).to eq(500)
        end
      end

      context 'HTTP 502 - Bad Gateway' do
        it 'creates ServerError with correct status' do
          error = Sendly::ErrorFactory.from_response(502, { 'message' => 'Bad gateway' })
          expect(error).to be_a(Sendly::ServerError)
          expect(error.status_code).to eq(502)
        end
      end

      context 'HTTP 503 - Service Unavailable' do
        it 'creates ServerError' do
          error = Sendly::ErrorFactory.from_response(503, { 'message' => 'Service unavailable' })
          expect(error).to be_a(Sendly::ServerError)
          expect(error.status_code).to eq(503)
        end
      end

      context 'HTTP 504 - Gateway Timeout' do
        it 'creates ServerError' do
          error = Sendly::ErrorFactory.from_response(504, { 'message' => 'Gateway timeout' })
          expect(error).to be_a(Sendly::ServerError)
          expect(error.status_code).to eq(504)
        end
      end

      context 'Unknown status codes' do
        it 'creates APIError for unknown 4xx status' do
          error = Sendly::ErrorFactory.from_response(418, { 'message' => "I'm a teapot" })
          expect(error).to be_a(Sendly::APIError)
          expect(error.message).to eq("I'm a teapot")
          expect(error.status_code).to eq(418)
        end

        it 'creates APIError for 3xx status' do
          error = Sendly::ErrorFactory.from_response(301, { 'message' => 'Moved permanently' })
          expect(error).to be_a(Sendly::APIError)
          expect(error.status_code).to eq(301)
        end

        it 'includes error code from response' do
          body = { 'message' => 'Custom error', 'code' => 'CUSTOM_CODE' }
          error = Sendly::ErrorFactory.from_response(418, body)
          expect(error.code).to eq('CUSTOM_CODE')
        end

        it 'includes details from response' do
          body = { 'message' => 'Error', 'details' => { 'info' => 'Additional info' } }
          error = Sendly::ErrorFactory.from_response(418, body)
          expect(error.details).to eq({ 'info' => 'Additional info' })
        end
      end

      context 'Edge cases' do
        it 'handles empty response body' do
          error = Sendly::ErrorFactory.from_response(500, {})
          expect(error).to be_a(Sendly::ServerError)
          expect(error.message).to eq('Unknown error')
        end

        it 'handles nil message' do
          error = Sendly::ErrorFactory.from_response(400, { 'message' => nil })
          expect(error.message).to eq('Unknown error')
        end

        it 'prefers message over error field' do
          body = { 'message' => 'From message', 'error' => 'From error' }
          error = Sendly::ErrorFactory.from_response(400, body)
          expect(error.message).to eq('From message')
        end

        it 'uses error field if message is missing' do
          error = Sendly::ErrorFactory.from_response(400, { 'error' => 'From error field' })
          expect(error.message).to eq('From error field')
        end
      end
    end
  end
end
