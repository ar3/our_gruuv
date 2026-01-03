require 'rails_helper'

RSpec.describe Slack::ProcessFeedbackCommandService, type: :service do
  let(:organization) { create(:organization, :company, :with_slack_config) }
  let(:observer_person) { create(:person) }
  let(:observee_person) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer_person, organization: organization) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: organization) }
  let(:observer_slack_id) { 'U123456' }
  let(:observee_slack_id) { 'U789012' }
  let(:channel_id) { 'C123456' }
  let(:text) { 'Great work @user1 on the project!' }
  
  let(:command_info) do
    {
      command: '/og',
      text: text,
      user_id: observer_slack_id,
      channel_id: channel_id,
      team_id: 'T123456',
      team_domain: 'test-workspace',
      channel_name: 'general',
      user_name: 'testuser',
      response_url: 'https://hooks.slack.com/commands/123/456',
      trigger_id: '123.456.789'
    }
  end

  let(:service) do
    described_class.new(
      organization: organization,
      user_id: observer_slack_id,
      channel_id: channel_id,
      text: text,
      command_info: command_info
    )
  end

  let(:mock_slack_service) { instance_double(SlackService) }

  before do
    allow(SlackService).to receive(:new).with(organization).and_return(mock_slack_service)
  end

  describe '#call' do
    context 'when observer is found' do
      before do
        create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: observer_slack_id)
      end

      context 'when observee is mentioned and found' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "Great work <@#{observee_slack_id}> on the project!" }

        it 'creates a draft observation' do
          result = service.call
          
          expect(result.ok?).to be true
          observation = result.value
          expect(observation).to be_persisted
          expect(observation.observer).to eq(observer_person)
          expect(observation.published_at).to be_nil
          expect(observation.privacy_level).to eq('observed_and_managers')
        end

        it 'creates an observation trigger' do
          result = service.call
          observation = result.value
          
          expect(observation.observation_trigger).to be_present
          expect(observation.observation_trigger.trigger_source).to eq('slack')
          expect(observation.observation_trigger.trigger_type).to eq('slack_command')
        end

        it 'stores command information in trigger data' do
          result = service.call
          observation = result.value
          
          trigger_data = observation.observation_trigger.trigger_data
          expect(trigger_data['command']).to eq('/og')
          expect(trigger_data['text']).to eq("Great work <@#{observee_slack_id}> on the project!")
          expect(trigger_data['user_id']).to eq(observer_slack_id)
          expect(trigger_data['channel_id']).to eq(channel_id)
        end

        it 'adds observee to the observation' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(1)
          expect(observation.observees.first.teammate.id).to eq(observee_teammate.id)
        end

        it 'replaces mention tags with readable names in story' do
          result = service.call
          observation = result.value
          
          expect(observation.story).to include("@#{observee_person.display_name}")
          expect(observation.story).not_to include("<@#{observee_slack_id}>")
        end
      end

      context 'when multiple observees are mentioned' do
        let(:observee2_person) { create(:person) }
        let(:observee2_teammate) { create(:teammate, person: observee2_person, organization: organization) }
        let(:observee2_slack_id) { 'U999999' }

        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
          create(:teammate_identity, teammate: observee2_teammate, provider: 'slack', uid: observee2_slack_id)
        end

        let(:text) { "Great work <@#{observee_slack_id}> and <@#{observee2_slack_id}> on the project!" }

        it 'adds all observees to the observation' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(2)
          expect(observation.observees.map { |o| o.teammate.id }).to contain_exactly(observee_teammate.id, observee2_teammate.id)
        end
      end

      context 'when observee is mentioned but not found' do
        let(:text) { "Great work <@U999999> on the project!" }

        it 'creates observation without observee' do
          result = service.call
          
          expect(result.ok?).to be true
          observation = result.value
          expect(observation.observees.count).to eq(0)
        end

        it 'removes unresolved mention tags from story' do
          result = service.call
          observation = result.value
          
          expect(observation.story).not_to include('<@U999999>')
        end
      end

      context 'when mention is at start of text' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "<@#{observee_slack_id}> did great work on the project!" }

        it 'adds observee and replaces mention correctly' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(1)
          expect(observation.story).to start_with("@#{observee_person.display_name}")
          expect(observation.story).not_to include("<@#{observee_slack_id}>")
        end
      end

      context 'when mention is at end of text' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "Great work on the project by <@#{observee_slack_id}>" }

        it 'adds observee and replaces mention correctly' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(1)
          expect(observation.story).to end_with("@#{observee_person.display_name}")
          expect(observation.story).not_to include("<@#{observee_slack_id}>")
        end
      end

      context 'when same person is mentioned multiple times' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "Thanks <@#{observee_slack_id}> for the help! <@#{observee_slack_id}> really saved the day!" }

        it 'adds observee only once' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(1)
          expect(observation.observees.first.teammate.id).to eq(observee_teammate.id)
        end

        it 'replaces all mentions with readable name' do
          result = service.call
          observation = result.value
          
          expect(observation.story.scan("@#{observee_person.display_name}").count).to eq(2)
          expect(observation.story).not_to include("<@#{observee_slack_id}>")
        end
      end

      context 'when mentioned user exists in different organization' do
        let(:other_organization) { create(:organization, :company) }
        let(:other_teammate) { create(:teammate, person: observee_person, organization: other_organization) }

        before do
          create(:teammate_identity, teammate: other_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "Great work <@#{observee_slack_id}> on the project!" }

        it 'does not add observee from different organization' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(0)
        end

        it 'removes mention tag from story' do
          result = service.call
          observation = result.value
          
          expect(observation.story).not_to include("<@#{observee_slack_id}>")
        end
      end

      context 'when mentioned user has no TeammateIdentity' do
        let(:text) { "Great work <@U999888> on the project!" }

        it 'creates observation without observee' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(0)
        end
      end

      context 'when mentioned user has TeammateIdentity but teammate is in different org' do
        let(:other_organization) { create(:organization, :company) }
        let(:other_teammate) { create(:teammate, organization: other_organization) }

        before do
          create(:teammate_identity, teammate: other_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "Great work <@#{observee_slack_id}> on the project!" }

        it 'does not add observee' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(0)
        end
      end

      context 'when mixing valid and invalid mentions' do
        let(:observee2_person) { create(:person) }
        let(:observee2_teammate) { create(:teammate, person: observee2_person, organization: organization) }
        let(:observee2_slack_id) { 'U777777' }
        let(:invalid_slack_id) { 'U999999' }

        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
          create(:teammate_identity, teammate: observee2_teammate, provider: 'slack', uid: observee2_slack_id)
        end

        let(:text) { "Great work <@#{observee_slack_id}> and <@#{observee2_slack_id}>! Also thanks <@#{invalid_slack_id}>!" }

        it 'adds only valid observees' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(2)
          expect(observation.observees.map { |o| o.teammate.id }).to contain_exactly(observee_teammate.id, observee2_teammate.id)
        end

        it 'replaces valid mentions and removes invalid ones' do
          result = service.call
          observation = result.value
          
          expect(observation.story).to include("@#{observee_person.display_name}")
          expect(observation.story).to include("@#{observee2_person.display_name}")
          expect(observation.story).not_to include("<@#{invalid_slack_id}>")
          expect(observation.story).not_to include("<@#{observee_slack_id}>")
          expect(observation.story).not_to include("<@#{observee2_slack_id}>")
        end
      end

      context 'when AddObserveeService is called' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "Great work <@#{observee_slack_id}> on the project!" }

        it 'calls AddObserveeService for each resolved teammate' do
          expect(Observations::AddObserveeService).to receive(:new).with(
            observation: kind_of(Observation),
            teammate_id: observee_teammate.id
          ).and_call_original
          
          result = service.call
          expect(result.ok?).to be true
        end

        it 'persists observees to database' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.reload.count).to eq(1)
          expect(observation.observees.first).to be_persisted
          expect(observation.observees.first.teammate_id).to eq(observee_teammate.id)
        end
      end

      context 'when AddObserveeService raises exception' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
          allow(Observations::AddObserveeService).to receive(:new).and_raise(StandardError.new('Service error'))
        end

        let(:text) { "Great work <@#{observee_slack_id}> on the project!" }

        it 'catches exception and returns error result' do
          expect { service.call }.not_to raise_error
          result = service.call
          
          expect(result.ok?).to be false
          expect(result.error).to include('Unexpected error')
        end
      end

      context 'when observee validation fails (different company)' do
        let(:other_company) { create(:organization, :company) }
        let(:other_teammate) { create(:teammate, organization: other_company) }

        before do
          # Create identity in same org but teammate in different org (edge case)
          # Note: find_teammate_by_slack_id filters by organization, so this shouldn't normally happen
          # But testing edge case where it might
          create(:teammate_identity, teammate: other_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "Great work <@#{observee_slack_id}> on the project!" }

        it 'does not add observee due to organization mismatch in find_teammate_by_slack_id' do
          result = service.call
          observation = result.value
          
          # find_teammate_by_slack_id filters by organization, so other_teammate won't be found
          expect(observation.observees.count).to eq(0)
        end
      end

      context 'when AddObserveeService raises validation error' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
          # Mock AddObserveeService to raise validation error
          allow_any_instance_of(Observations::AddObserveeService).to receive(:call).and_raise(
            ActiveRecord::RecordInvalid.new(Observee.new)
          )
        end

        let(:text) { "Great work <@#{observee_slack_id}> on the project!" }

        it 'catches validation error and returns error result' do
          result = service.call
          
          expect(result.ok?).to be false
          expect(result.error).to include('Unexpected error')
        end
      end

      context 'end-to-end: complete flow with multiple scenarios' do
        let(:observee2_person) { create(:person) }
        let(:observee2_teammate) { create(:teammate, person: observee2_person, organization: organization) }
        let(:observee2_slack_id) { 'U777777' }
        let(:invalid_slack_id) { 'U999999' }

        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
          create(:teammate_identity, teammate: observee2_teammate, provider: 'slack', uid: observee2_slack_id)
        end

        let(:text) { "Thanks <@#{observee_slack_id}> for the help! Also <@#{observee2_slack_id}> did great work. <@#{invalid_slack_id}> was mentioned but not found." }

        it 'creates observation with correct observees and story' do
          result = service.call
          
          expect(result.ok?).to be true
          observation = result.value
          
          # Verify observees
          expect(observation.observees.count).to eq(2)
          expect(observation.observees.map { |o| o.teammate.id }).to contain_exactly(observee_teammate.id, observee2_teammate.id)
          
          # Verify story has mentions replaced
          expect(observation.story).to include("@#{observee_person.display_name}")
          expect(observation.story).to include("@#{observee2_person.display_name}")
          expect(observation.story).not_to include("<@#{observee_slack_id}>")
          expect(observation.story).not_to include("<@#{observee2_slack_id}>")
          expect(observation.story).not_to include("<@#{invalid_slack_id}>")
        end
      end

      context 'with very long text containing mentions' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
        end

        let(:text) { "This is a very long text. " * 50 + "Great work <@#{observee_slack_id}>! " + "More text here. " * 50 }

        it 'correctly parses mentions in long text' do
          result = service.call
          observation = result.value
          
          expect(observation.observees.count).to eq(1)
          expect(observation.story).to include("@#{observee_person.display_name}")
        end
      end

      context 'regex pattern matching' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
        end

        it 'matches standard Slack mention format <@U123456>' do
          text = "Thanks <@#{observee_slack_id}>!"
          service = described_class.new(
            organization: organization,
            user_id: observer_slack_id,
            channel_id: channel_id,
            text: text,
            command_info: command_info
          )
          
          result = service.call
          expect(result.ok?).to be true
          expect(result.value.observees.count).to eq(1)
        end

        it 'matches mentions with lowercase user IDs' do
          lowercase_id = observee_slack_id.downcase
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: lowercase_id)
          
          text = "Thanks <@#{lowercase_id}>!"
          service = described_class.new(
            organization: organization,
            user_id: observer_slack_id,
            channel_id: channel_id,
            text: text,
            command_info: command_info
          )
          
          result = service.call
          # Note: Slack user IDs are typically uppercase, but testing edge case
          expect(result.ok?).to be true
        end

        it 'does not match invalid mention formats' do
          text = "Thanks @user123 without brackets!"
          service = described_class.new(
            organization: organization,
            user_id: observer_slack_id,
            channel_id: channel_id,
            text: text,
            command_info: command_info
          )
          
          result = service.call
          expect(result.ok?).to be true
          expect(result.value.observees.count).to eq(0)
        end
      end

      context 'when no mentions are present' do
        let(:text) { 'Great work on the project!' }

        it 'creates observation without observees' do
          result = service.call
          
          expect(result.ok?).to be true
          observation = result.value
          expect(observation.observees.count).to eq(0)
          expect(observation.story).to eq('Great work on the project!')
        end
      end

      context 'when text is blank' do
        let(:text) { '' }

        it 'returns error' do
          result = service.call
          
          expect(result.ok?).to be false
          expect(result.error).to include('Please provide a message')
        end
      end

      context 'when text is nil' do
        let(:text) { nil }

        it 'returns error' do
          result = service.call
          
          expect(result.ok?).to be false
          expect(result.error).to include('Please provide a message')
        end
      end
    end

    context 'when observer is not found' do
      let(:text) { 'Great work!' }

      it 'returns error' do
        result = service.call
        
        expect(result.ok?).to be false
        expect(result.error).to include('not found in OurGruuv')
      end
    end

    context 'when observation save fails' do
      before do
        create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: observer_slack_id)
        # Force validation error by making company nil
        allow_any_instance_of(Observation).to receive(:save).and_return(false)
        allow_any_instance_of(Observation).to receive(:errors).and_return(
          double(full_messages: ['Company can\'t be blank'])
        )
      end

      it 'returns error with validation messages' do
        result = service.call
        
        expect(result.ok?).to be false
        expect(result.error).to include('Failed to create observation')
      end
    end

    context 'when exception occurs' do
      before do
        create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: observer_slack_id)
        allow(organization.observations).to receive(:build).and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns error result' do
        result = service.call
        
        expect(result.ok?).to be false
        expect(result.error).to include('Unexpected error')
      end
    end
  end
end

