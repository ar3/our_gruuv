require 'rails_helper'

RSpec.describe Person, type: :model do
  let(:person) { build(:person) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(person).to be_valid
    end

    it 'requires an email' do
      person.email = nil
      expect(person).not_to be_valid
      expect(person.errors[:email]).to include("can't be blank")
    end

    it 'validates email format' do
      person.email = 'invalid-email'
      expect(person).not_to be_valid
      expect(person.errors[:email]).to include('is invalid')
    end

    it 'automatically fixes invalid timezones' do
      person.timezone = 'Invalid/Timezone'
      expect(person).to be_valid
      expect(person.timezone).to eq('Eastern Time (US & Canada)')
    end

    it 'allows valid timezones' do
      person.timezone = 'Eastern Time (US & Canada)'
      expect(person).to be_valid
    end

    it 'allows blank timezone' do
      person.timezone = ''
      expect(person).to be_valid
    end
  end

  describe '#timezone_or_default' do
    it 'returns the timezone when set' do
      person.timezone = 'Pacific Time (US & Canada)'
      expect(person.timezone_or_default).to eq('Pacific Time (US & Canada)')
    end

    it 'returns Eastern Time when timezone is blank' do
      person.timezone = ''
      expect(person.timezone_or_default).to eq('Eastern Time (US & Canada)')
    end

    it 'returns Eastern Time when timezone is nil' do
      person.timezone = nil
      expect(person.timezone_or_default).to eq('Eastern Time (US & Canada)')
    end
  end

  describe '#format_time_in_user_timezone' do
    let(:time) { Time.zone.parse('2025-07-21 14:30:00 UTC') }

    context 'when timezone is set' do
      before do
        person.timezone = 'Eastern Time (US & Canada)'
      end

      it 'formats time in user timezone' do
        formatted = person.format_time_in_user_timezone(time)
        expect(formatted).to include('EDT') # Eastern Daylight Time
        expect(formatted).to include('10:30 AM') # 14:30 UTC = 10:30 AM EDT
      end
    end

    context 'when timezone is not set' do
      before do
        person.timezone = nil
      end

      it 'formats time in Eastern Time' do
        formatted = person.format_time_in_user_timezone(time)
        expect(formatted).to include('EDT') # Eastern Daylight Time
        expect(formatted).to include('10:30 AM') # 14:30 UTC = 10:30 AM EDT
      end
    end

    context 'with different timezones' do
      it 'formats time in Pacific timezone' do
        person.timezone = 'Pacific Time (US & Canada)'
        formatted = person.format_time_in_user_timezone(time)
        expect(formatted).to include('PDT') # Pacific Daylight Time
        expect(formatted).to include('7:30 AM') # 14:30 UTC = 7:30 AM PDT
      end

      it 'formats time in Central timezone' do
        person.timezone = 'Central Time (US & Canada)'
        formatted = person.format_time_in_user_timezone(time)
        expect(formatted).to include('CDT') # Central Daylight Time
        expect(formatted).to include('9:30 AM') # 14:30 UTC = 9:30 AM CDT
      end
    end
  end

  describe '#display_name' do
    context 'with full name' do
      before do
        person.first_name = 'John'
        person.last_name = 'Doe'
      end

      it 'returns full name' do
        expect(person.display_name).to eq('John Doe')
      end
    end

    context 'with only email' do
      before do
        person.first_name = nil
        person.last_name = nil
        person.email = 'john@example.com'
      end

      it 'returns email' do
        expect(person.display_name).to eq('john@example.com')
      end
    end
  end

  describe 'full name parsing' do
    it 'parses single name as first name' do
      person.first_name = nil
      person.last_name = nil
      person.middle_name = nil
      person.full_name = 'John'
      expect(person.first_name).to eq('John')
      expect(person.last_name).to be_nil
    end

    it 'parses two names as first and last' do
      person.first_name = nil
      person.last_name = nil
      person.middle_name = nil
      person.full_name = 'John Doe'
      expect(person.first_name).to eq('John')
      expect(person.last_name).to eq('Doe')
    end

    it 'parses three names as first, middle, last' do
      person.first_name = nil
      person.last_name = nil
      person.middle_name = nil
      person.full_name = 'John Michael Doe'
      expect(person.first_name).to eq('John')
      expect(person.middle_name).to eq('Michael')
      expect(person.last_name).to eq('Doe')
    end

    it 'parses four names with first, middle, last' do
      person.first_name = nil
      person.last_name = nil
      person.middle_name = nil
      person.full_name = 'John Michael van Doe'
      expect(person.first_name).to eq('John')
      expect(person.middle_name).to eq('Michael van')
      expect(person.last_name).to eq('Doe')
    end
  end
end 