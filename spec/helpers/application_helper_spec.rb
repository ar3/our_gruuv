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

      it 'formats time in Eastern Time' do
        formatted = helper.format_time_in_user_timezone(time, person)
        expect(formatted).to include('EDT') # Eastern Daylight Time
        expect(formatted).to include('10:30 AM') # 14:30 UTC = 10:30 AM EDT
      end
    end

    context 'when no user provided and current_person not available' do
      it 'formats time in Eastern Time' do
        formatted = helper.format_time_in_user_timezone(time)
        expect(formatted).to include('EDT') # Eastern Daylight Time
        expect(formatted).to include('10:30 AM') # 14:30 UTC = 10:30 AM EDT
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

    context 'with custom format' do
      it 'formats time with custom format string' do
        formatted = helper.format_time_in_user_timezone(time, person, format: '%m/%d/%Y %I:%M %p')
        expect(formatted).to match(/\d{2}\/\d{2}\/\d{4} \d{1,2}:\d{2} [AP]M/)
        expect(formatted).to include('10:30 AM')
      end

      it 'formats date-only with custom format' do
        formatted = helper.format_time_in_user_timezone(time, person, format: '%B %d, %Y')
        expect(formatted).to include('July 21, 2025')
        expect(formatted).not_to include('AM')
        expect(formatted).not_to include('PM')
      end
    end

    context 'with nil time' do
      it 'returns empty string' do
        formatted = helper.format_time_in_user_timezone(nil, person)
        expect(formatted).to eq('')
      end
    end
  end

  describe '#format_date_in_user_timezone' do
    let(:time) { Time.zone.parse('2025-07-21 14:30:00 UTC') }
    let(:person) { build(:person, timezone: 'Eastern Time (US & Canada)') }

    context 'with default format' do
      it 'formats date in user timezone' do
        formatted = helper.format_date_in_user_timezone(time, person)
        expect(formatted).to include('July 21, 2025')
        expect(formatted).not_to include('AM')
        expect(formatted).not_to include('PM')
      end
    end

    context 'with custom format' do
      it 'formats date with custom format string' do
        formatted = helper.format_date_in_user_timezone(time, person, format: '%m/%d/%Y')
        expect(formatted).to match(/\d{2}\/\d{2}\/\d{4}/)
        expect(formatted).to include('07/21/2025')
      end

      it 'formats date with abbreviated month format' do
        formatted = helper.format_date_in_user_timezone(time, person, format: '%b %d, %Y')
        expect(formatted).to include('Jul 21, 2025')
      end
    end

    context 'with different timezones' do
      it 'formats date correctly across timezone boundaries' do
        # Time that's 11:30 PM EST on Jan 1, which is Jan 2 in PST
        late_night_time = Time.zone.parse('2025-01-02 04:30:00 UTC') # 11:30 PM EST Jan 1
        person.timezone = 'Pacific Time (US & Canada)'
        formatted = helper.format_date_in_user_timezone(late_night_time, person, format: '%B %d, %Y')
        expect(formatted).to match(/January \d{1,2}, 2025/) # Should show Jan 1 in PST (8:30 PM)
        expect(formatted).to include('2025')
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