require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#format_time_in_user_timezone' do
    let(:time) { Time.zone.parse('2025-07-21 14:30:00 UTC') }
    let(:person) { build(:person, timezone: 'Eastern Time (US & Canada)') }

    context 'when user has timezone set' do
      it 'formats time in user timezone' do
        formatted = helper.format_time_in_user_timezone(time, person)
        expect(formatted).to include('EDT') # Eastern Daylight Time
        expect(formatted).to include('10:30 AM') # 14:30 UTC = 10:30 AM EDT
      end
    end

    context 'when user has no timezone' do
      let(:person) { build(:person, timezone: nil) }

      it 'formats time in UTC' do
        formatted = helper.format_time_in_user_timezone(time, person)
        expect(formatted).to include('UTC')
        expect(formatted).to include('2:30 PM') # 14:30 UTC
      end
    end

    context 'when no user provided and current_person not available' do
      it 'formats time in UTC' do
        formatted = helper.format_time_in_user_timezone(time)
        expect(formatted).to include('UTC')
        expect(formatted).to include('2:30 PM') # 14:30 UTC
      end
    end

    context 'with different timezones' do
      it 'formats time in Pacific timezone' do
        person.timezone = 'Pacific Time (US & Canada)'
        formatted = helper.format_time_in_user_timezone(time, person)
        expect(formatted).to include('PDT') # Pacific Daylight Time
        expect(formatted).to include('7:30 AM') # 14:30 UTC = 7:30 AM PDT
      end

      it 'formats time in Central timezone' do
        person.timezone = 'Central Time (US & Canada)'
        formatted = helper.format_time_in_user_timezone(time, person)
        expect(formatted).to include('CDT') # Central Daylight Time
        expect(formatted).to include('9:30 AM') # 14:30 UTC = 9:30 AM CDT
      end
    end
  end

  describe '#available_timezones' do
    it 'returns array of timezone options' do
      timezones = helper.available_timezones
      expect(timezones).to be_an(Array)
      expect(timezones.first).to be_an(Array)
      expect(timezones.first.length).to eq(2)
      
      # Check that common timezones are included
      timezone_names = timezones.map(&:first)
      expect(timezone_names).to include('Eastern Time (US & Canada)')
      expect(timezone_names).to include('Pacific Time (US & Canada)')
      expect(timezone_names).to include('Central Time (US & Canada)')
      expect(timezone_names).to include('UTC')
    end
  end
end 