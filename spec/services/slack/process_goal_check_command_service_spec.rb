require 'rails_helper'

RSpec.describe Slack::ProcessGoalCheckCommandService, type: :service do
  let(:organization) { create(:organization, :company, :with_slack_config) }
  let(:user_id) { 'U123456' }
  let(:trigger_id) { '123.456.789' }
  let(:command_info) { { command: '/og', user_id: user_id, trigger_id: trigger_id } }
  
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  
  let(:service) do
    described_class.new(
      organization: organization,
      user_id: user_id,
      trigger_id: trigger_id,
      command_info: command_info
    )
  end

  before do
    create(:teammate_identity, teammate: teammate, provider: 'slack', uid: user_id)
  end

  describe '#call' do
    context 'when teammate is not found' do
      before do
        TeammateIdentity.where(teammate_id: teammate.id).destroy_all
      end

      it 'returns error message' do
        result = service.call
        expect(result.ok?).to be false
        expect(result.error).to include("not found in OurGruuv")
      end
    end

    context 'when teammate has no goals' do
      it 'returns error message with goals URL' do
        result = service.call
        expect(result.ok?).to be false
        expect(result.error).to include("don't have any goals available for check-in")
        expect(result.error).to include("/goals")
      end
    end

    context 'when teammate has goals' do
      let!(:goal1) do
        create(:goal,
               :qualitative_key_result,
               owner: teammate,
               creator: teammate,
               company: organization,
               title: 'First Goal',
               started_at: 1.day.ago,
               completed_at: nil)
      end
      let!(:goal2) do
        create(:goal,
               :qualitative_key_result,
               owner: teammate,
               creator: teammate,
               company: organization,
               title: 'Second Goal',
               started_at: 1.day.ago,
               completed_at: nil)
      end

      let(:mock_slack_service) { instance_double(SlackService) }
      let(:mock_client) { instance_double(Slack::Web::Client) }

      before do
        allow(SlackService).to receive(:new).with(organization).and_return(mock_slack_service)
        allow(mock_slack_service).to receive(:open_modal).and_return({ success: true })
      end

      it 'opens modal successfully' do
        result = service.call
        expect(result.ok?).to be true
        expect(result.value).to include("Opening goal check-in form")
      end

      it 'includes both goals in the modal' do
        expect(mock_slack_service).to receive(:open_modal) do |trigger_id, view|
          goal_options = view[:blocks].find { |b| b[:block_id] == 'goal_selection' }
            .dig(:element, :options)
          
          goal_titles = goal_options.map { |opt| opt[:text][:text] }
          expect(goal_titles).to include('First Goal')
          expect(goal_titles).to include('Second Goal')
          
          { success: true }
        end
        
        service.call
      end

      it 'includes current week range in modal text' do
        week_start = Date.current.beginning_of_week(:monday)
        week_end = Date.current.end_of_week(:sunday)
        
        expect(mock_slack_service).to receive(:open_modal) do |trigger_id, view|
          section_text = view[:blocks].first[:text][:text]
          expect(section_text).to include(week_start.strftime('%b %d'))
          expect(section_text).to include(week_end.strftime('%b %d, %Y'))
          
          { success: true }
        end
        
        service.call
      end

      context 'when modal opening fails' do
        before do
          allow(mock_slack_service).to receive(:open_modal).and_return({ success: false, error: 'Invalid trigger_id' })
        end

        it 'returns error message' do
          result = service.call
          expect(result.ok?).to be false
          expect(result.error).to include("Failed to open check-in form")
        end
      end
    end

    context 'when goal title is too long' do
      let!(:long_goal) do
        create(:goal,
               :qualitative_key_result,
               owner: teammate,
               creator: teammate,
               company: organization,
               title: 'A' * 100,
               started_at: 1.day.ago,
               completed_at: nil)
      end

      let(:mock_slack_service) { instance_double(SlackService) }

      before do
        allow(SlackService).to receive(:new).with(organization).and_return(mock_slack_service)
        allow(mock_slack_service).to receive(:open_modal).and_return({ success: true })
      end

      it 'truncates long goal titles' do
        expect(mock_slack_service).to receive(:open_modal) do |trigger_id, view|
          goal_options = view[:blocks].find { |b| b[:block_id] == 'goal_selection' }
            .dig(:element, :options)
          
          goal_text = goal_options.first[:text][:text]
          expect(goal_text.length).to be <= 75
          expect(goal_text).to end_with('...')
          
          { success: true }
        end
        
        service.call
      end
    end
  end
end

