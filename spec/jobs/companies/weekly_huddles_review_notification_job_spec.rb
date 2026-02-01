require 'rails_helper'

RSpec.describe Companies::WeeklyHuddlesReviewNotificationJob, type: :job do
  let(:company) { create(:organization, :company) }
  let(:slack_config) { create(:slack_configuration, organization: company) }
  let(:slack_channel) { create(:third_party_object, organization: company, third_party_source: 'slack', third_party_object_type: 'channel') }
  let(:association) { create(:third_party_object_association, third_party_object: slack_channel, associatable: company, association_type: 'huddle_review_notification_channel') }

  before do
    slack_config
    slack_channel
    association
  end

  describe 'basic functionality' do
    it 'can be instantiated and run' do
      job = described_class.new
      expect(job).to be_a(Companies::WeeklyHuddlesReviewNotificationJob)
      
      # Test that the job can be performed without errors
      expect { job.perform(company.id) }.not_to raise_error
    end

    it 'has the required methods' do
      job = described_class.new
      expect(job).to respond_to(:perform)
    end
  end

  describe '#perform' do
    context 'when company has Slack configured and notification channel set' do
      it 'sends a Slack message with feedback stats' do
        # Create some test feedback for the past week
        huddle1 = create(:huddle, team: create(:team, company: company), started_at: 1.week.ago)
        huddle2 = create(:huddle, team: create(:team, company: company), started_at: 1.week.ago)
        person1 = create(:person)
        person2 = create(:person)
        teammate1 = create(:teammate, person: person1, organization: company)
        teammate2 = create(:teammate, person: person2, organization: company)
        
        create(:huddle_feedback, huddle: huddle1, teammate: teammate1, created_at: 1.week.ago)
        create(:huddle_feedback, huddle: huddle2, teammate: teammate2, created_at: 1.week.ago)

        # Test the job directly
        job = described_class.new
        expect { job.perform(company.id) }.not_to raise_error

        # Check that a notification was created
        notification = Notification.where(notification_type: 'huddle_summary').last
        expect(notification).to be_present
        expect(notification.notification_type).to eq('huddle_summary')
        expect(notification.metadata['channel']).to eq(slack_channel.third_party_id)
      end

      it 'updates existing notification if one exists for the current week' do
        # Create some test feedback for the past week
        huddle1 = create(:huddle, team: create(:team, company: company), started_at: 1.week.ago)
        huddle2 = create(:huddle, team: create(:team, company: company), started_at: 1.week.ago)
        person1 = create(:person)
        person2 = create(:person)
        teammate1 = create(:teammate, person: person1, organization: company)
        teammate2 = create(:teammate, person: person2, organization: company)
        create(:huddle_feedback, huddle: huddle1, teammate: teammate1, created_at: 1.week.ago)
        create(:huddle_feedback, huddle: huddle2, teammate: teammate2, created_at: 1.week.ago)

        # Create an existing notification for this week
        week_start = Date.current.beginning_of_week(:monday)
        existing_notification = Notification.create!(
          notifiable: company,
          notification_type: 'huddle_summary',
          status: 'sent_successfully',
          metadata: { 
            channel: slack_channel.third_party_id,
            notifiable_type: 'Company',
            notifiable_id: company.id
          },
          rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Old message' } }],
          fallback_text: 'Old message',
          created_at: week_start + 1.day
        )

        # Run the job
        job = described_class.new
        expect { job.perform(company.id) }.not_to raise_error

        # Check that a new notification was created and linked to the original
        new_notification = Notification.where(notification_type: 'huddle_summary').last
        expect(new_notification).to be_present
        expect(new_notification.original_message_id).to eq(existing_notification.id)
        expect(new_notification.fallback_text).to include('2 huddles')
        expect(new_notification.fallback_text).to include('pieces of positive and constructive feedback')
        expect(Notification.where(notification_type: 'huddle_summary').count).to eq(2)
      end
    end

    context 'when company does not have Slack configured' do
      before { slack_config.destroy }

      it 'does not send a Slack message' do
        slack_service = instance_double(SlackService)
        allow(SlackService).to receive(:new).and_return(slack_service)
        allow(slack_service).to receive(:post_message)

        described_class.perform_now(company.id)

        expect(slack_service).not_to have_received(:post_message)
      end
    end

    context 'when company does not have notification channel set' do
      before { association.destroy }

      it 'does not send a Slack message' do
        slack_service = instance_double(SlackService)
        allow(SlackService).to receive(:new).and_return(slack_service)
        allow(slack_service).to receive(:post_message)

        described_class.perform_now(company.id)

        expect(slack_service).not_to have_received(:post_message)
      end
    end
  end

  describe 'message content' do
    it 'includes correct feedback statistics' do
      # Create test data for the past week
      huddle1 = create(:huddle, team: create(:team, company: company), started_at: 1.week.ago)
      huddle2 = create(:huddle, team: create(:team, company: company), started_at: 1.week.ago)
      huddle3 = create(:huddle, team: create(:team, company: company), started_at: 1.week.ago)
      person1 = create(:person)
      person2 = create(:person)
      teammate1 = create(:teammate, person: person1, organization: company)
      teammate2 = create(:teammate, person: person2, organization: company)
      
      # Create feedback for the past week (not current week)
      create(:huddle_feedback, huddle: huddle1, teammate: teammate1, created_at: 1.week.ago)
      create(:huddle_feedback, huddle: huddle2, teammate: teammate1, created_at: 1.week.ago)
      create(:huddle_feedback, huddle: huddle3, teammate: teammate2, created_at: 1.week.ago)

      # Test the job directly
      job = described_class.new
      expect { job.perform(company.id) }.not_to raise_error

      # Check that a notification was created with the correct content
      notification = Notification.last
      expect(notification).to be_present
      expect(notification.notification_type).to eq('huddle_summary')
      expect(notification.fallback_text).to include('3 huddles')
      expect(notification.fallback_text).to include('pieces of positive and constructive feedback')
      expect(notification.metadata['channel']).to eq(slack_channel.third_party_id)
    end
  end
end 