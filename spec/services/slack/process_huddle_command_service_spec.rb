require 'rails_helper'

RSpec.describe Slack::ProcessHuddleCommandService, type: :service do
  let(:organization) { create(:organization, :company, :with_slack_config) }
  let(:user_id) { 'U123456' }
  let(:channel_id) { 'C123456' }
  let(:channel_name) { 'general' }
  let(:command_info) { { command: '/og', user_id: user_id, channel_id: channel_id } }
  
  let(:service) do
    described_class.new(
      organization: organization,
      user_id: user_id,
      channel_id: channel_id,
      command_info: command_info
    )
  end

  describe '#call' do
    context 'when channel is not found' do
      it 'returns error message' do
        result = service.call
        expect(result.ok?).to be false
        expect(result.error).to eq("No huddle configured for this channel.")
      end
    end

    context 'when channel exists but no playbook configured' do
      let!(:slack_channel) do
        create(:third_party_object, :slack_channel,
               organization: organization,
               third_party_id: channel_id,
               display_name: channel_name)
      end

      it 'returns error message' do
        result = service.call
        expect(result.ok?).to be false
        expect(result.error).to eq("No huddle configured for this channel.")
      end
    end

    context 'when playbook exists for channel' do
      let!(:slack_channel) do
        create(:third_party_object, :slack_channel,
               organization: organization,
               third_party_id: channel_id,
               display_name: channel_name)
      end
      let!(:playbook) do
        create(:team,
               organization: organization,
               slack_channel: "##{channel_name}")
      end

      context 'when no active huddle exists' do
        it 'creates a new huddle' do
          expect {
            result = service.call
            expect(result.ok?).to be true
          }.to change(Huddle, :count).by(1)
        end

        it 'creates huddle with correct attributes' do
          # Capture time before service call to account for time spent in jobs
          before_time = Time.current
          
          result = service.call
          expect(result.ok?).to be true
          
          huddle = Huddle.last
          expect(huddle.team).to eq(playbook)
          # Compare against time captured before service call, not current time after jobs run
          expect(huddle.started_at).to be_within(1.second).of(before_time)
          expect(huddle.expires_at).to be_within(1.second).of(24.hours.from_now(before_time))
        end

        it 'returns success message with full huddle URL' do
          result = service.call
          expect(result.ok?).to be true
          expect(result.value).to include("Huddle started successfully!")
          expect(result.value).to match(/https?:\/\/.+\/huddles\/\d+/)
        end

        it 'enqueues announcement and summary jobs' do
          expect(Huddles::PostAnnouncementJob).to receive(:perform_and_get_result).and_return({ success: true })
          expect(Huddles::PostSummaryJob).to receive(:perform_and_get_result).and_return({ success: true })
          
          service.call
        end
      end

      context 'when active huddle already exists' do
        let!(:existing_huddle) do
          create(:huddle,
                 team: playbook,
                 started_at: 1.hour.ago,
                 expires_at: 23.hours.from_now)
        end

        it 'does not create a new huddle' do
          expect {
            result = service.call
            expect(result.ok?).to be true
          }.not_to change(Huddle, :count)
        end

        it 'returns message with full existing huddle link' do
          result = service.call
          expect(result.ok?).to be true
          expect(result.value).to include("Huddle is already started with the link:")
          expect(result.value).to match(/https?:\/\/.+\/huddles\/#{existing_huddle.id}/)
        end
      end

      context 'when expired huddle exists' do
        let!(:expired_huddle) do
          create(:huddle,
                 team: playbook,
                 started_at: 2.days.ago,
                 expires_at: 1.day.ago)
        end

        it 'creates a new huddle' do
          expect {
            result = service.call
            expect(result.ok?).to be true
          }.to change(Huddle, :count).by(1)
        end
      end
    end


    context 'when organization is not found' do
      let(:service) do
        described_class.new(
          organization: nil,
          user_id: user_id,
          channel_id: channel_id,
          command_info: command_info
        )
      end

      it 'handles gracefully' do
        result = service.call
        # Should handle nil organization without error
        expect(result).to be_a(Result)
      end
    end

    context 'when huddle creation fails' do
      let!(:slack_channel) do
        create(:third_party_object, :slack_channel,
               organization: organization,
               third_party_id: channel_id,
               display_name: channel_name)
      end
      let!(:playbook) do
        create(:team,
               organization: organization,
               slack_channel: "##{channel_name}")
      end

      before do
        allow_any_instance_of(Huddle).to receive(:save).and_return(false)
        allow_any_instance_of(Huddle).to receive(:errors).and_return(
          double(full_messages: ['Validation failed'])
        )
      end

      it 'returns error message' do
        result = service.call
        expect(result.ok?).to be false
        expect(result.error).to include("Failed to create huddle")
      end
    end
  end
end

