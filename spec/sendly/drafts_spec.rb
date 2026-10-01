# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::DraftsResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:drafts) { client.drafts }

  def draft(id)
    {
      'id' => id, 'conversationId' => 'conv_1', 'text' => 'Draft reply', 'status' => 'pending',
      'createdAt' => '2026-09-25T10:00:00.000Z'
    }
  end

  describe '#list' do
    it 'works out has_more from the total the API sends and the page it asked for' do
      stub_request_with_auth(:get, '/drafts?limit=2&offset=0',
                             response_body: { 'data' => [draft('drf_1'), draft('drf_2')],
                                              'pagination' => { 'total' => 5 } })

      list = drafts.list(limit: 2, offset: 0)

      expect(list.count).to eq(2)
      expect(list.total).to eq(5)
      expect(list.limit).to eq(2)
      expect(list.offset).to eq(0)
      expect(list.has_more).to be true
    end

    it 'has no more on the last page' do
      stub_request_with_auth(:get, '/drafts?limit=2&offset=4',
                             response_body: { 'data' => [draft('drf_5')], 'pagination' => { 'total' => 5 } })

      list = drafts.list(limit: 2, offset: 4)

      expect(list.offset).to eq(4)
      expect(list.has_more).to be false
    end

    it 'prefers pagination values the API sends' do
      stub_request_with_auth(:get, '/drafts',
                             response_body: { 'data' => [draft('drf_1')],
                                              'pagination' => { 'total' => 1, 'limit' => 50, 'offset' => 0,
                                                                 'hasMore' => false } })

      list = drafts.list

      expect(list.limit).to eq(50)
      expect(list.has_more).to be false
    end

    it 'reports the 50-row page the API returns when no limit is asked for' do
      rows = (1..50).map { |i| draft("drf_#{i}") }
      stub_request_with_auth(:get, '/drafts', response_body: { 'data' => rows, 'pagination' => { 'total' => 120 } })

      list = drafts.list

      expect(list.count).to eq(50)
      expect(list.limit).to eq(50)
      expect(list.offset).to eq(0)
      expect(list.has_more).to be true
    end

    it 'reports the 100-row cap the API puts on a larger limit' do
      rows = (1..100).map { |i| draft("drf_#{i}") }
      stub_request_with_auth(:get, '/drafts?limit=500',
                             response_body: { 'data' => rows, 'pagination' => { 'total' => 250 } })

      list = drafts.list(limit: 500)

      expect(list.count).to eq(100)
      expect(list.limit).to eq(100)
      expect(list.has_more).to be true
    end

    it 'reports the default page size for an empty limit, which the API ignores' do
      rows = (1..50).map { |i| draft("drf_#{i}") }
      stub_request_with_auth(:get, '/drafts?limit=', response_body: { 'data' => rows, 'pagination' => { 'total' => 120 } })

      expect(drafts.list(limit: '').limit).to eq(50)
    end

    it 'takes an offset given as a string, such as a request param' do
      stub_request_with_auth(:get, '/drafts?offset=4',
                             response_body: { 'data' => [draft('drf_5')], 'pagination' => { 'total' => 5 } })

      list = drafts.list(offset: '4')

      expect(list.offset).to eq(4)
      expect(list.has_more).to be false
    end

    it 'reports a limit given as a string as an Integer' do
      stub_request_with_auth(:get, '/drafts?limit=2',
                             response_body: { 'data' => [draft('drf_1'), draft('drf_2')],
                                              'pagination' => { 'total' => 5 } })

      list = drafts.list(limit: '2')

      expect(list.limit).to eq(2)
      expect(list.has_more).to be true
    end
  end

  describe Sendly::DraftList do
    it 'takes a response hash written without braces, as it did before' do
      list = Sendly::DraftList.new('data' => [draft('drf_1')], 'pagination' => { 'total' => 1 })

      expect(list.count).to eq(1)
      expect(list.total).to eq(1)
      expect(list.has_more).to be false
    end
  end
end
