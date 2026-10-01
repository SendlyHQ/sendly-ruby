# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sendly::CampaignsResource do
  let(:client) { Sendly::Client.new(api_key: valid_api_key) }
  let(:campaigns) { client.campaigns }

  def json_ok(body, status: 200)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  def campaign_row(overrides = {})
    {
      'id' => 'camp_1',
      'userId' => 'user_1',
      'organizationId' => 'org_1',
      'name' => 'Spring sale',
      'status' => 'completed',
      'messageText' => 'Hi',
      'fromSender' => nil,
      'targetType' => 'contact_list',
      'targetListId' => 'lst_1',
      'manualRecipients' => nil,
      'excludeOptedOut' => true,
      'sendNow' => false,
      'scheduledAt' => nil,
      'timezone' => 'America/New_York',
      'batchId' => 'batch_1',
      'totalRecipients' => 12,
      'estimatedCredits' => 24,
      'sentCount' => 12,
      'deliveredCount' => 10,
      'failedCount' => 2,
      'creditsUsed' => 24,
      'creditsRefunded' => 0,
      'createdAt' => '2026-09-25T09:00:00.000Z',
      'updatedAt' => '2026-09-25T10:01:00.000Z',
      'sentAt' => '2026-09-25T10:00:00.000Z',
      'completedAt' => '2026-09-25T10:01:00.000Z',
      'text' => 'Hi',
      'contact_list_ids' => ['lst_1'],
      'created_at' => '2026-09-25T09:00:00.000Z',
      'updated_at' => '2026-09-25T10:01:00.000Z'
    }.merge(overrides)
  end

  describe Sendly::Campaign do
    it 'reads the counts, dates and status of a sent campaign' do
      campaign = described_class.new(
        'id' => 'camp_1', 'status' => 'completed', 'totalRecipients' => 12,
        'sentAt' => '2026-09-25T10:00:00Z', 'messageText' => 'Hi', 'targetListId' => 'lst_1'
      )

      expect(campaign.sent?).to be true
      expect(campaign.completed?).to be true
      expect(campaign.recipient_count).to eq(12)
      expect(campaign.started_at).to eq(Time.parse('2026-09-25T10:00:00Z'))
      expect(campaign.text).to eq('Hi')
      expect(campaign.contact_list_ids).to eq(['lst_1'])
    end

    it 'lists completed among its statuses and keeps the old ones' do
      expect(described_class::STATUSES).to include('completed')
      expect(described_class::STATUSES).to include('draft', 'scheduled', 'sending', 'sent', 'paused', 'cancelled', 'failed')
    end

    it 'has no contact lists when the campaign targets none' do
      campaign = described_class.new('id' => 'camp_1', 'status' => 'draft', 'targetListId' => nil)

      expect(campaign.contact_list_ids).to eq([])
      expect(campaign.sent?).to be false
      expect(campaign.completed?).to be false
    end
  end

  describe '#get' do
    it 'reads the campaign the API returns' do
      stub_request(:get, "#{base_url}/campaigns/camp_1").to_return(json_ok(campaign_row))

      campaign = campaigns.get('camp_1')

      expect(campaign.recipient_count).to eq(12)
      expect(campaign.sent_count).to eq(12)
      expect(campaign.delivered_count).to eq(10)
      expect(campaign.failed_count).to eq(2)
      expect(campaign.credits_used).to eq(24)
      expect(campaign.started_at).to eq(Time.parse('2026-09-25T10:00:00.000Z'))
      expect(campaign.completed_at).to eq(Time.parse('2026-09-25T10:01:00.000Z'))
      expect(campaign.contact_list_ids).to eq(['lst_1'])
      expect(campaign).to be_sent
    end
  end

  describe '#preview' do
    it 'reads the per-country breakdown the API sends as byCountry' do
      by_country = { 'US' => { 'count' => 12, 'credits' => 24, 'allowed' => true } }
      stub_request(:get, "#{base_url}/campaigns/camp_1/preview").to_return(json_ok({
        'totalRecipients' => 12, 'estimatedCredits' => 24, 'optedOutCount' => 1, 'invalidCount' => 0,
        'invalidNumberCount' => 0, 'landlineCount' => 0, 'sampleRecipients' => [],
        'blockedCount' => 0, 'sendableCount' => 12, 'byCountry' => by_country, 'warnings' => [],
        'messagingProfile' => { 'canSendDomestic' => true },
        'recipientCount' => 12, 'currentBalance' => 100, 'hasEnoughCredits' => true
      }))

      preview = campaigns.preview('camp_1')

      expect(preview.recipient_count).to eq(12)
      expect(preview.estimated_credits).to eq(24)
      expect(preview.breakdown).to eq(by_country)
      expect(preview.enough_credits?).to be true
    end
  end

  describe '#send_campaign' do
    it 'returns the batch the campaign went out in' do
      stub = stub_request(:post, "#{base_url}/campaigns/camp_1/send").to_return(json_ok({
        'batchId' => 'batch_1', 'status' => 'completed', 'total' => 3, 'sent' => 3, 'failed' => 0,
        'retrying' => 0, 'optedOutSkipped' => 0, 'invalidSkipped' => 0,
        'creditsUsed' => 6, 'creditsRefunded' => 0,
        'messages' => [{ 'index' => 0, 'id' => 'msg_1', 'to' => '+15551234567', 'status' => 'sent' }]
      }))

      result = campaigns.send_campaign('camp_1')

      expect(stub).to have_been_requested
      expect(result).to be_a(Sendly::Campaign)
      expect(result).to be_a(Sendly::CampaignSendResult)
      expect(result.id).to eq('camp_1')
      expect(result.batch_id).to eq('batch_1')
      expect(result.status).to eq('completed')
      expect(result.recipient_count).to eq(3)
      expect(result.sent_count).to eq(3)
      expect(result.failed_count).to eq(0)
      expect(result.credits_used).to eq(6)
      expect(result.credits_refunded).to eq(0)
      expect(result.messages.first['id']).to eq('msg_1')
      expect(result.raw['batchId']).to eq('batch_1')
    end
  end
end
