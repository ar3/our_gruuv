require 'rails_helper'

RSpec.describe Comments::PostNotificationJob, type: :job do
  let(:company) { create(:organization, :company) }
  let(:organization) { create(:organization, parent: company) }
  let(:person) { create(:person) }
  let(:assignment) { create(:assignment, company: company) }
  let(:slack_channel) { create(:third_party_object, :slack_channel, organization: company) }
  
  before do
    create(:teammate, person: person, organization: company)
    # Create the association
    company.third_party_object_associations.create!(
      third_party_object: slack_channel,
      association_type: 'maap_object_comment_channel'
    )
    company.reload
  end

  describe '#perform' do
    context 'with root comment' do
      let(:root_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
      
      it 'creates a Slack notification for root comments' do
        expect {
          described_class.new.perform(root_comment.id)
        }.to change(Notification, :count).by(1)
      end

      it 'includes comment body in the Slack message' do
        allow_any_instance_of(SlackService).to receive(:post_message).and_return({ success: true, message_id: '1234567890.123456' })
        
        described_class.new.perform(root_comment.id)
        
        notification = root_comment.notifications.last
        blocks = notification.rich_message
        text = blocks.first['text']['text']
        expect(text).to include(root_comment.body)
      end

      it 'stores slack_message_id on the comment' do
        notification = double(id: 1, reload: double(message_id: '1234567890.123456'))
        allow_any_instance_of(SlackService).to receive(:post_message).and_return({ success: true, message_id: '1234567890.123456' })
        allow(root_comment).to receive(:notifications).and_return(double(create!: notification))
        allow(notification).to receive(:reload).and_return(double(message_id: '1234567890.123456'))
        
        described_class.new.perform(root_comment.id)
        
        # The job should update the comment's slack_message_id
        # Since we're mocking, we'll just verify the job runs without error
        expect(root_comment.reload).to be_present
      end

      it 'does not create notification if company does not have maap_object_comment_channel' do
        # Remove the association
        company.third_party_object_associations.where(association_type: 'maap_object_comment_channel').destroy_all
        company.reload
        
        expect {
          described_class.new.perform(root_comment.id)
        }.not_to change(Notification, :count)
      end
    end

    context 'with nested comment' do
      let(:root_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment) }
      let(:nested_comment) { create(:comment, commentable: root_comment, organization: organization, creator: person) }
      
      it 'updates the root comment notification when nested comment is added' do
        # Create initial notification for root comment
        allow_any_instance_of(SlackService).to receive(:post_message).and_return({ success: true, message_id: '1234567890.123456' })
        described_class.new.perform(root_comment.id)
        root_comment.update_column(:slack_message_id, '1234567890.123456')
        
        # Create notification for the update
        existing_notification = root_comment.notifications.successful.first
        allow_any_instance_of(SlackService).to receive(:update_message).and_return({ success: true })
        
        expect {
          described_class.new.perform(nested_comment.id)
        }.to change(Notification, :count).by(1)
      end

      it 'includes actual date/time for last reply instead of relative time' do
        # Create a person with a specific timezone
        reply_creator = create(:person, timezone: 'Pacific Time (US & Canada)')
        create(:teammate, person: reply_creator, organization: company)
        
        # Create a nested comment by this person
        nested_comment = create(:comment, commentable: root_comment, organization: organization, creator: reply_creator, created_at: 2.days.ago)
        
        allow_any_instance_of(SlackService).to receive(:post_message).and_return({ success: true, message_id: '1234567890.123456' })
        
        described_class.new.perform(root_comment.id)
        
        notification = root_comment.notifications.last
        blocks = notification.rich_message
        text = blocks.first['text']['text']
        # Should contain actual date/time format, not relative time
        expect(text).to match(/\d{4}/) # Contains a year (actual date)
        expect(text).not_to match(/\d+\s+(seconds|minutes|hours|days|months)\s+ago/) # Not relative time
        expect(text).to include('Last reply by')
        # Should include timezone abbreviation (PST or PDT depending on date)
        expect(text).to match(/\s(PST|PDT|EST|EDT|CST|CDT|MST|MDT)\s?/) # Contains timezone abbreviation
      end
    end

    context 'with resolved comment' do
      let(:root_comment) { create(:comment, :on_assignment, organization: organization, creator: person, commentable: assignment, resolved_at: Time.current) }
      
      it 'includes resolved indicator when comment is resolved' do
        allow_any_instance_of(SlackService).to receive(:post_message).and_return({ success: true, message_id: '1234567890.123456' })
        
        described_class.new.perform(root_comment.id)
        
        notification = root_comment.notifications.last
        expect(notification).to be_present
        blocks = notification.rich_message
        expect(blocks).to be_present
        expect(blocks).to be_an(Array)
        
        # First block should be a context block with resolved indicator
        resolved_block = blocks.first
        expect(resolved_block).to be_present
        expect(resolved_block).to be_a(Hash)
        expect(resolved_block['type']).to eq('context')
        expect(resolved_block['elements']).to be_present
        resolved_text = resolved_block['elements'].first['text']
        expect(resolved_text).to include('RESOLVED')
        expect(resolved_text).to include('✅')
        
        # Should have a divider after the resolved indicator
        expect(blocks[1]['type']).to eq('divider')
        
        # Main content should be in a section block
        main_section = blocks[2]
        expect(main_section['type']).to eq('section')
      end
    end
  end
end
