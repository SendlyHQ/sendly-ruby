# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::ConversationsResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:conversations) { client.conversations }

  def suggest_replies_response(overrides = {})
    {
      'suggestions' => [
        { 'text' => 'Thanks for reaching out! How can I help?', 'tone' => 'friendly' },
        { 'text' => 'We received your message and will respond shortly.', 'tone' => 'professional' }
      ],
      'basedOnMessageId' => 'msg_inbound_1',
      'model' => 'claude-sonnet-4-5-20250929'
    }.merge(overrides)
  end

  describe '#suggest_replies' do
    it 'posts to the suggest-replies endpoint and returns a SuggestRepliesResponse' do
      stub_request_with_auth(:post, '/conversations/conv_abc123/suggest-replies',
                             response_body: suggest_replies_response)

      result = conversations.suggest_replies('conv_abc123')

      expect(result).to be_a(Sendly::SuggestRepliesResponse)
      expect(result.count).to eq(2)
      expect(result.based_on_message_id).to eq('msg_inbound_1')
      expect(result.model).to eq('claude-sonnet-4-5-20250929')

      first = result.first
      expect(first).to be_a(Sendly::SuggestedReply)
      expect(first.text).to eq('Thanks for reaching out! How can I help?')
      expect(first.tone).to eq('friendly')
    end

    it 'is enumerable over its suggestions' do
      stub_request_with_auth(:post, '/conversations/conv_abc123/suggest-replies',
                             response_body: suggest_replies_response)

      result = conversations.suggest_replies('conv_abc123')
      tones = result.map(&:tone)

      expect(tones).to eq(%w[friendly professional])
    end

    it 'URL-encodes the conversation id' do
      stub = stub_request(:post, "#{base_url}/conversations/conv%2Fweird/suggest-replies")
        .with(headers: { 'Authorization' => "Bearer #{valid_api_key}" })
        .to_return(status: 200, body: suggest_replies_response.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      conversations.suggest_replies('conv/weird')
      expect(stub).to have_been_requested
    end

    it 'handles an empty suggestions list' do
      stub_request_with_auth(:post, '/conversations/conv_abc123/suggest-replies',
                             response_body: { 'suggestions' => [] })

      result = conversations.suggest_replies('conv_abc123')
      expect(result).to be_empty
      expect(result.count).to eq(0)
    end

    it 'raises ValidationError when id is nil' do
      expect { conversations.suggest_replies(nil) }
        .to raise_error(Sendly::ValidationError, /Conversation ID is required/)
    end

    it 'raises ValidationError when id is empty' do
      expect { conversations.suggest_replies('') }
        .to raise_error(Sendly::ValidationError, /Conversation ID is required/)
    end
  end
end
