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

  describe '#each' do
    def conversation_page(from, count, total:, offset:)
      {
        'data' => (from...(from + count)).map { |i| { 'id' => "conv_#{i}", 'phoneNumber' => '+15551234567', 'status' => 'active' } },
        'pagination' => { 'total' => total, 'limit' => 100, 'offset' => offset, 'hasMore' => offset + count < total }
      }
    end

    it 'advances by the rows returned when batch_size is over the API limit of 100' do
      first = stub_request_with_auth(:get, '/conversations?limit=100&offset=0',
                                     response_body: conversation_page(0, 100, total: 150, offset: 0))
      second = stub_request_with_auth(:get, '/conversations?limit=100&offset=100',
                                      response_body: conversation_page(100, 50, total: 150, offset: 100))

      ids = conversations.each(batch_size: 200).map(&:id)

      expect(ids.length).to eq(150)
      expect(ids.uniq.length).to eq(150)
      expect(first).to have_been_requested.once
      expect(second).to have_been_requested.once
      expect(a_request(:get, "#{base_url}/conversations?limit=100&offset=200")).not_to have_been_made
    end

    it 'stops at an empty page even when the API says there are more' do
      stub = stub_request_with_auth(:get, '/conversations?limit=100&offset=0',
                                    response_body: conversation_page(0, 0, total: 5, offset: 0))
             .then.to_return(status: 200, body: conversation_page(0, 1, total: 1, offset: 0).to_json)

      ids = conversations.each.map(&:id)

      expect(ids).to be_empty
      expect(stub).to have_been_requested.once
    end
  end

  describe '#reply' do
    def sent_message(overrides = {})
      message_response('id' => 'msg_reply', 'direction' => 'outbound').merge(overrides)
    end

    it 'sends a media-only reply' do
      stub = stub_request(:post, "#{base_url}/conversations/conv_1/messages")
             .with(body: { mediaUrls: ['https://cdn.example.com/x.jpg'] }.to_json)
             .to_return(status: 200, body: sent_message('mediaUrls' => ['https://cdn.example.com/x.jpg']).to_json,
                        headers: { 'Content-Type' => 'application/json' })

      message = conversations.reply('conv_1', media_urls: ['https://cdn.example.com/x.jpg'])

      expect(stub).to have_been_requested
      expect(message).to be_a(Sendly::Message)
      expect(message.id).to eq('msg_reply')
    end

    it 'still sends a text reply as before' do
      stub = stub_request(:post, "#{base_url}/conversations/conv_1/messages")
             .with(body: { text: 'Thanks!' }.to_json)
             .to_return(status: 200, body: sent_message.to_json, headers: { 'Content-Type' => 'application/json' })

      conversations.reply('conv_1', text: 'Thanks!')

      expect(stub).to have_been_requested
    end

    it 'raises ValidationError when there is neither text nor media' do
      expect { conversations.reply('conv_1') }.to raise_error(Sendly::ValidationError)
      expect { conversations.reply('conv_1', text: '', media_urls: []) }.to raise_error(Sendly::ValidationError)
    end
  end
end
