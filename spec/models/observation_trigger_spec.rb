require 'rails_helper'

RSpec.describe ObservationTrigger, type: :model do
  describe 'associations' do
    it { should have_many(:observations).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:trigger_source) }
    it { should validate_presence_of(:trigger_type) }
  end

  describe '#formatted_trigger_data' do
    let(:trigger) { create(:observation_trigger, trigger_data: trigger_data) }

    context 'with simple key-value pairs' do
      let(:trigger_data) do
        {
          command: '/og',
          text: 'feedback Great work!',
          user_id: 'U123456',
          channel_id: 'C123456'
        }
      end

      it 'formats data as markdown' do
        formatted = trigger.formatted_trigger_data
        expect(formatted).to include('**Command**: /og')
        expect(formatted).to include('**Text**: feedback Great work!')
        expect(formatted).to include('**User**: U123456')
        expect(formatted).to include('**Channel**: C123456')
      end
    end

    context 'with nested data' do
      let(:trigger_data) do
        {
          command: '/og',
          metadata: {
            team_id: 'T123456',
            timestamp: Time.parse('2025-01-01 12:00:00')
          }
        }
      end

      it 'formats nested data' do
        formatted = trigger.formatted_trigger_data
        expect(formatted).to include('**Command**: /og')
        expect(formatted).to include('Team: T123456')
      end
    end

    context 'with date/time values' do
      let(:trigger_data) do
        {
          created_at: Time.parse('2025-01-01 12:00:00'),
          date: Date.parse('2025-01-01')
        }
      end

      it 'formats dates and times' do
        formatted = trigger.formatted_trigger_data
        expect(formatted).to include('January 01, 2025 at 12:00 PM')
        expect(formatted).to include('January 01, 2025')
      end
    end

    context 'with empty data' do
      let(:trigger_data) { {} }

      it 'returns a message' do
        expect(trigger.formatted_trigger_data).to eq('No trigger data')
      end
    end
  end

  describe '#display_text' do
    it 'formats trigger source and type' do
      trigger = create(:observation_trigger, trigger_source: 'slack', trigger_type: 'slack_command')
      expect(trigger.display_text).to eq("Slack's Slack command")
    end
  end
end

