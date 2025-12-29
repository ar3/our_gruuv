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
  
  let(:service) do
    described_class.new(
      organization: organization,
      user_id: observer_slack_id,
      channel_id: channel_id,
      text: text
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

