require 'rails_helper'

RSpec.describe Slack::CreateObservationFromMessageService, type: :service do
  let(:organization) { create(:organization, :company, :with_slack_config) }
  let(:observer_person) { create(:person) }
  let(:observee_person) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer_person, organization: organization) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: organization) }
  let(:observer_slack_id) { 'U123456' }
  let(:observee_slack_id) { 'U789012' }
  let(:team_id) { 'T123456' }
  let(:channel_id) { 'C123456' }
  let(:message_ts) { '1234567890.123456' }
  let(:notes) { 'This is a test note' }
  let(:permalink) { 'https://slack.com/archives/C123456/p1234567890123456' }
  let(:message_text) { "Hello from Slack.\nThis is line two." }
  
  let(:service) do
    described_class.new(
      organization: organization,
      team_id: team_id,
      channel_id: channel_id,
      message_ts: message_ts,
      message_user_id: observee_slack_id,
      triggering_user_id: observer_slack_id,
      notes: notes
    )
  end

  let(:mock_slack_service) { instance_double(SlackService) }

  before do
    allow(SlackService).to receive(:new).with(organization).and_return(mock_slack_service)
    allow(mock_slack_service).to receive(:get_message_permalink).and_return({ success: true, permalink: permalink })
    allow(mock_slack_service).to receive(:get_message).and_return({ success: true, text: message_text })
    allow(mock_slack_service).to receive(:store_slack_response)
  end

  describe '#call' do
    context 'when observer is found' do
      before do
        create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: observer_slack_id)
      end

      context 'when observee is found' do
        before do
          create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
        end

        it 'creates a draft observation with notes, permalink, and quoted message content' do
          result = service.call

          expect(result.ok?).to be true
          observation = result.value
          expect(observation).to be_persisted
          expect(observation.observer).to eq(observer_person)
          expect(observation.company.id).to eq(organization.id)
          expect(observation.story).to include(notes)
          expect(observation.story).to include("==========")
          expect(observation.story).to include("Link to message: #{permalink}")
          expect(observation.story).to include("> Hello from Slack.")
          expect(observation.story).to include("> This is line two.")
          expect(observation.privacy_level).to eq('observed_and_managers')
          expect(observation.published_at).to be_nil
          expect(observation.draft?).to be true
        end

        it 'adds observee to the observation' do
          result = service.call

          expect(result.ok?).to be true
          observation = result.value
          expect(observation.observees.count).to eq(1)
          expect(observation.observees.first.teammate.id).to eq(observee_teammate.id)
        end

        it 'logs to DebugResponse' do
          expect(mock_slack_service).to receive(:store_slack_response).with(
            'create_observation_from_message',
            hash_including(status: 'success', observation_id: kind_of(Integer)),
            hash_including(observation_url: kind_of(String))
          )

          service.call
        end
      end

      context 'when observee is not found' do
        it 'creates observation without observee' do
          result = service.call

          expect(result.ok?).to be true
          observation = result.value
          expect(observation.observees.count).to eq(0)
          expect(observation.story).to include(notes)
          expect(observation.story).to include("Link to message: #{permalink}")
          expect(observation.story).to include("> Hello from Slack.")
        end
      end

      context 'when notes are empty' do
        let(:notes) { '' }

        it 'creates observation with permalink and quoted message in story' do
          result = service.call

          expect(result.ok?).to be true
          observation = result.value
          expect(observation.story).to include("==========")
          expect(observation.story).to include("Link to message: #{permalink}")
          expect(observation.story).to include("> Hello from Slack.")
          expect(observation.story).to include("> This is line two.")
        end
      end

      context 'when get_message fails' do
        before do
          allow(mock_slack_service).to receive(:get_message).and_return({ success: false, error: 'Channel not found' })
        end

        it 'still creates observation with link only (no quoted message content)' do
          result = service.call

          expect(result.ok?).to be true
          observation = result.value
          expect(observation).to be_persisted
          expect(observation.story).to include(notes)
          expect(observation.story).to include("==========")
          expect(observation.story).to include("Link to message: #{permalink}")
          expect(observation.story).not_to include("> Hello from Slack.")
        end
      end

      context 'when permalink fetch fails' do
        before do
          allow(mock_slack_service).to receive(:get_message_permalink).and_return({ success: false, error: 'Channel not found' })
        end

        it 'returns error result' do
          result = service.call

          expect(result.ok?).to be false
          expect(result.error).to include('Failed to get Slack message permalink')
        end

        it 'logs error to DebugResponse' do
          expect(mock_slack_service).to receive(:store_slack_response).with(
            'create_observation_from_message',
            hash_including(status: 'failed', reason: 'Permalink not found'),
            hash_including(error: kind_of(String))
          )

          service.call
        end
      end
    end

    context 'when observer is not found' do
      it 'returns error result' do
        result = service.call

        expect(result.ok?).to be false
        expect(result.error).to include('Observer (triggering user) not found')
      end

      it 'logs error to DebugResponse' do
        expect(mock_slack_service).to receive(:store_slack_response).with(
          'create_observation_from_message',
          hash_including(status: 'failed', reason: 'Observer not found'),
          hash_including(error: kind_of(String))
        )

        service.call
      end
    end

    context 'when observation save fails' do
      before do
        create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: observer_slack_id)
        allow_any_instance_of(Observation).to receive(:save).and_return(false)
        allow_any_instance_of(Observation).to receive(:errors).and_return(
          double(full_messages: ['Validation error'])
        )
      end

      it 'returns error result with validation errors' do
        result = service.call

        expect(result.ok?).to be false
        expect(result.error).to include('Failed to create observation')
        expect(result.error).to include('Validation error')
      end
    end

    context 'when exception occurs' do
      before do
        create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: observer_slack_id)
        allow_any_instance_of(Observation).to receive(:save).and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns error result' do
        result = service.call

        expect(result.ok?).to be false
        expect(result.error).to include('Unexpected error creating observation')
      end

      it 'logs exception to DebugResponse' do
        expect(mock_slack_service).to receive(:store_slack_response).with(
          'create_observation_from_message',
          hash_including(status: 'failed', exception: 'StandardError'),
          hash_including(error: kind_of(String), backtrace: kind_of(Array))
        )

        service.call
      end
    end
  end
end

