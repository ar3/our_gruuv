require 'rails_helper'

RSpec.describe IncomingWebhook, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:observation) { create(:observation, company: organization) }

  describe 'associations' do
    it { should belong_to(:organization).optional }
    it { should belong_to(:resultable).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:provider) }
    it { should validate_presence_of(:event_type) }
    it { should validate_presence_of(:status) }
  end

  describe 'enums' do
    it 'defines status enum with correct values' do
      expect(IncomingWebhook.statuses).to eq({
        'unprocessed' => 'unprocessed',
        'processing' => 'processing',
        'processed' => 'processed',
        'failed' => 'failed'
      })
    end
  end

  describe 'scopes' do
    let!(:unprocessed_webhook) { create(:incoming_webhook, status: 'unprocessed') }
    let!(:processing_webhook) { create(:incoming_webhook, status: 'processing') }
    let!(:processed_webhook) { create(:incoming_webhook, status: 'processed') }
    let!(:failed_webhook) { create(:incoming_webhook, status: 'failed') }

    it 'filters by unprocessed status' do
      expect(IncomingWebhook.unprocessed).to include(unprocessed_webhook)
      expect(IncomingWebhook.unprocessed).not_to include(processing_webhook, processed_webhook, failed_webhook)
    end

    it 'filters by processing status' do
      expect(IncomingWebhook.processing).to include(processing_webhook)
      expect(IncomingWebhook.processing).not_to include(unprocessed_webhook, processed_webhook, failed_webhook)
    end

    it 'filters by processed status' do
      expect(IncomingWebhook.processed).to include(processed_webhook)
      expect(IncomingWebhook.processed).not_to include(unprocessed_webhook, processing_webhook, failed_webhook)
    end

    it 'filters by failed status' do
      expect(IncomingWebhook.failed).to include(failed_webhook)
      expect(IncomingWebhook.failed).not_to include(unprocessed_webhook, processing_webhook, processed_webhook)
    end
  end

  describe '#mark_processing!' do
    it 'updates status to processing' do
      webhook = create(:incoming_webhook, status: 'unprocessed')
      webhook.mark_processing!
      expect(webhook.reload.status).to eq('processing')
    end
  end

  describe '#mark_processed!' do
    it 'updates status to processed and sets processed_at' do
      webhook = create(:incoming_webhook, status: 'processing')
      webhook.mark_processed!
      expect(webhook.reload.status).to eq('processed')
      expect(webhook.processed_at).to be_present
    end
  end

  describe '#mark_failed!' do
    it 'updates status to failed and sets error_message and processed_at' do
      webhook = create(:incoming_webhook, status: 'processing')
      webhook.mark_failed!('Test error')
      expect(webhook.reload.status).to eq('failed')
      expect(webhook.error_message).to eq('Test error')
      expect(webhook.processed_at).to be_present
    end

    it 'allows nil error_message' do
      webhook = create(:incoming_webhook, status: 'processing')
      webhook.mark_failed!(nil)
      expect(webhook.reload.status).to eq('failed')
      expect(webhook.error_message).to be_nil
    end
  end

  describe 'polymorphic resultable association' do
    it 'can belong to an observation' do
      webhook = create(:incoming_webhook, resultable: observation)
      expect(webhook.resultable).to eq(observation)
      expect(webhook.resultable_type).to eq('Observation')
      expect(webhook.resultable_id).to eq(observation.id)
    end

    it 'can have nil resultable' do
      webhook = create(:incoming_webhook, resultable: nil)
      expect(webhook.resultable).to be_nil
    end
  end
end

