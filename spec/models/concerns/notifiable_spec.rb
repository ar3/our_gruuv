require 'rails_helper'

# Create a test model class for the Notifiable concern
class TestNotifiableModel < ApplicationRecord
  self.table_name = 'people' # Use existing table for testing
  include Notifiable
  
  def company
    @company ||= Organization.first || Organization.create!(name: 'Test Company')
  end
end

RSpec.describe Notifiable, type: :concern do
  let(:test_model) { TestNotifiableModel.create!(first_name: 'Test', last_name: 'User') }

  describe 'associations' do
    it 'has many notifications' do
      expect(test_model).to respond_to(:notifications)
    end
  end

  describe '#successful_notifications' do
    before do
      # Create test notifications
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        metadata: {}
      )
      
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_summary',
        status: 'sent_successfully',
        message_id: '456',
        metadata: {}
      )
      
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'send_failed',
        message_id: '789',
        metadata: {}
      )
    end

    it 'returns only successful notifications' do
      successful = test_model.successful_notifications
      expect(successful.count).to eq(2)
      expect(successful.all? { |n| n.status == 'sent_successfully' }).to be true
    end

    it 'filters by sub_type when provided' do
      filtered = test_model.successful_notifications(sub_type: 'huddle_announcement')
      expect(filtered.count).to eq(1)
      expect(filtered.first.notification_type).to eq('huddle_announcement')
    end

    it 'orders by created_at' do
      notifications = test_model.successful_notifications
      expect(notifications.first.created_at).to be <= notifications.last.created_at
    end
  end

  describe '#last_successful_notification' do
    before do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        metadata: {}
      )
      
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '456',
        metadata: {}
      )
    end

    it 'returns the most recent successful notification' do
      last_notification = test_model.last_successful_notification(sub_type: 'huddle_announcement')
      expect(last_notification.message_id).to eq('456')
    end

    it 'returns nil when no successful notifications exist' do
      result = test_model.last_successful_notification(sub_type: 'nonexistent')
      expect(result).to be_nil
    end
  end

  describe '#posted_to_slack?' do
    it 'returns true when successful notifications exist' do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        metadata: {}
      )
      
      expect(test_model.posted_to_slack?(sub_type: 'huddle_announcement')).to be true
    end

    it 'returns false when no successful notifications exist' do
      expect(test_model.posted_to_slack?).to be false
    end

    it 'returns false when only failed notifications exist' do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'send_failed',
        message_id: '123',
        metadata: {}
      )
      
      expect(test_model.posted_to_slack?(sub_type: 'huddle_announcement')).to be false
    end
  end

  describe '#original_notifications' do
    let!(:original_notification) do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        metadata: {}
      )
    end

    before do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '456',
        original_message_id: original_notification.id,
        metadata: {}
      )
    end

    it 'returns only notifications without original_message_id' do
      originals = test_model.original_notifications
      expect(originals.count).to eq(1)
      expect(originals.first.original_message_id).to be_nil
    end
  end

  describe '#notification_edits' do
    let!(:original_notification) do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        metadata: {}
      )
    end

    before do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '456',
        original_message_id: original_notification.id,
        metadata: {}
      )
    end

    it 'returns only notifications with original_message_id' do
      edits = test_model.notification_edits
      expect(edits.count).to eq(1)
      expect(edits.first.original_message_id).to eq(original_notification.id)
    end
  end

  describe '#has_notification_edits?' do
    it 'returns true when edits exist' do
      original_notification = Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        metadata: {}
      )
      
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '456',
        original_message_id: original_notification.id,
        metadata: {}
      )
      
      expect(test_model.has_notification_edits?).to be true
    end

    it 'returns false when no edits exist' do
      expect(test_model.has_notification_edits?).to be false
    end
  end

  describe '#latest_notification_version' do
    let!(:original_notification) do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        metadata: {}
      )
    end

    let!(:edit_notification) do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123', # Same message_id
        original_message_id: original_notification.id,
        metadata: {}
      )
    end

    it 'returns the latest edit when edits exist' do
      latest = test_model.latest_notification_version(sub_type: 'huddle_announcement')
      expect(latest).to eq(edit_notification)
    end

    it 'returns the original when no edits exist' do
      # Remove the edit
      edit_notification.destroy
      
      latest = test_model.latest_notification_version(sub_type: 'huddle_announcement')
      expect(latest).to eq(original_notification)
    end

    it 'returns nil when no notifications exist' do
      result = test_model.latest_notification_version(sub_type: 'nonexistent')
      expect(result).to be_nil
    end
  end

  describe '#notification_history' do
    let!(:original_notification) do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        metadata: {}
      )
    end

    let!(:edit_notification) do
      Notification.create!(
        notifiable: test_model,
        notification_type: 'huddle_announcement',
        status: 'sent_successfully',
        message_id: '123',
        original_message_id: original_notification.id,
        metadata: {}
      )
    end

    it 'returns the full history including original and edits' do
      history = test_model.notification_history(sub_type: 'huddle_announcement')
      expect(history.count).to eq(2)
      expect(history).to include(original_notification, edit_notification)
    end

    it 'orders by created_at' do
      history = test_model.notification_history(sub_type: 'huddle_announcement')
      expect(history.first.created_at).to be <= history.last.created_at
    end

    it 'returns empty array when no notifications exist' do
      history = test_model.notification_history(sub_type: 'nonexistent')
      expect(history).to eq([])
    end
  end

  describe '#post_to_slack!' do
    it 'raises NotImplementedError' do
      expect { test_model.post_to_slack! }.to raise_error(NotImplementedError)
    end
  end

  describe '#can_post_to_slack?' do
    it 'returns true when model has company' do
      expect(test_model.can_post_to_slack?).to be true
    end

    it 'returns false when model does not have company' do
      allow(test_model).to receive(:company).and_return(nil)
      expect(test_model.can_post_to_slack?).to be false
    end
  end

  describe '#slack_notification_context' do
    it 'returns basic context with notifiable info' do
      context = test_model.slack_notification_context
      expect(context[:notifiable_type]).to eq(test_model.class.name)
      expect(context[:notifiable_id]).to eq(test_model.id)
    end
  end
end