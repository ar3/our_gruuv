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

    it 'allows blank phone number' do
      person.unique_textable_phone_number = ''
      expect(person).to be_valid
    end

    it 'allows nil phone number' do
      person.unique_textable_phone_number = nil
      expect(person).to be_valid
    end

    it 'validates phone number uniqueness' do
      existing_person = create(:person, unique_textable_phone_number: '+1234567890')
      person.unique_textable_phone_number = '+1234567890'
      expect(person).not_to be_valid
      expect(person.errors[:unique_textable_phone_number]).to include('has already been taken')
    end
  end

  describe 'phone number normalization' do
    it 'converts empty string to nil before save' do
      person.unique_textable_phone_number = ''
      person.save!
      expect(person.reload.unique_textable_phone_number).to be_nil
    end

    it 'converts whitespace-only string to nil before save' do
      person.unique_textable_phone_number = '   '
      person.save!
      expect(person.reload.unique_textable_phone_number).to be_nil
    end

    it 'preserves valid phone numbers' do
      person.unique_textable_phone_number = '+1234567890'
      person.save!
      expect(person.reload.unique_textable_phone_number).to eq('+1234567890')
    end

    it 'preserves nil phone numbers' do
      person.unique_textable_phone_number = nil
      person.save!
      expect(person.reload.unique_textable_phone_number).to be_nil
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

  describe 'employment tenure associations' do
    let(:person) { create(:person) }
    let(:company) { create(:organization, :company) }
    let!(:employment_tenure) { create(:employment_tenure, person: person, company: company) }

    it 'can access employment tenures through company association' do
      # This test ensures we use the right association name
      expect(person.employment_tenures.where(company: company)).to include(employment_tenure)
    end

    it 'can check active employment tenure in organization' do
      # This test ensures the method works with company association
      expect(person.active_employment_tenure_in?(company)).to be true
    end

    it 'prevents using incorrect association names' do
      # This test catches the exact error we encountered
      expect {
        person.employment_tenures.where(organization: company).count
      }.to raise_error(ActiveRecord::StatementInvalid, /column employment_tenures.organization does not exist/)
    end
  end

  describe 'huddle participation methods' do
    let(:person) { create(:person) }
    let(:huddle_playbook) { create(:huddle_playbook, special_session_name: 'Daily Standup') }
    let(:huddle) { create(:huddle, huddle_playbook: huddle_playbook) }
    let!(:huddle_participant) { create(:huddle_participant, person: person, huddle: huddle) }
    let!(:huddle_feedback) { create(:huddle_feedback, person: person, huddle: huddle) }

    describe '#huddle_playbook_stats' do
      it 'groups huddle participations by playbook' do
        stats = person.huddle_playbook_stats
        expect(stats).to have_key(huddle_playbook)
        expect(stats[huddle_playbook]).to include(huddle_participant)
      end

      it 'includes huddle and playbook associations' do
        stats = person.huddle_playbook_stats
        playbook_participations = stats[huddle_playbook]
        expect(playbook_participations.first.huddle).to eq(huddle)
        expect(playbook_participations.first.huddle.huddle_playbook).to eq(huddle_playbook)
      end
    end

    describe '#total_huddle_participations' do
      it 'returns total count of huddle participations' do
        expect(person.total_huddle_participations).to eq(1)
      end
    end

    describe '#total_huddle_playbooks' do
      it 'returns total count of distinct playbooks' do
        expect(person.total_huddle_playbooks).to eq(1)
      end

      it 'handles multiple playbooks correctly' do
        second_playbook = create(:huddle_playbook, special_session_name: 'Weekly Retro')
        second_huddle = create(:huddle, huddle_playbook: second_playbook)
        create(:huddle_participant, person: person, huddle: second_huddle)
        
        expect(person.total_huddle_playbooks).to eq(2)
      end
    end

    describe '#total_feedback_given' do
      it 'returns count of participations with feedback' do
        expect(person.total_feedback_given).to eq(1)
      end
    end

    describe '#has_huddle_participation?' do
      it 'returns true when person has participations' do
        expect(person.has_huddle_participation?).to be true
      end

      it 'returns false when person has no participations' do
        person_without_participations = create(:person)
        expect(person_without_participations.has_huddle_participation?).to be false
      end
    end

    describe '#has_given_feedback_for_huddle?' do
      it 'returns true when person has given feedback for a specific huddle' do
        expect(person.has_given_feedback_for_huddle?(huddle)).to be true
      end

      it 'returns false when person has not given feedback for a specific huddle' do
        other_huddle = create(:huddle)
        expect(person.has_given_feedback_for_huddle?(other_huddle)).to be false
      end
    end

    describe '#huddle_stats_for_playbook' do
      it 'returns comprehensive stats for a specific playbook' do
        stats = person.huddle_stats_for_playbook(huddle_playbook)
        
        expect(stats[:total_huddles_held]).to eq(1)
        expect(stats[:participations_count]).to eq(1)
        expect(stats[:participation_percentage]).to eq(100.0)
        expect(stats[:feedback_count]).to eq(1)
        expect(stats[:average_rating]).to be > 0
      end

      it 'handles playbook with no huddles' do
        empty_playbook = create(:huddle_playbook)
        stats = person.huddle_stats_for_playbook(empty_playbook)
        
        expect(stats[:total_huddles_held]).to eq(0)
        expect(stats[:participations_count]).to eq(0)
        expect(stats[:participation_percentage]).to eq(0)
        expect(stats[:feedback_count]).to eq(0)
        expect(stats[:average_rating]).to eq(0)
      end
    end
  end
end 