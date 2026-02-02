require 'rails_helper'

RSpec.describe Huddle, type: :model do
  let(:company) { Organization.create!(name: 'Acme Corp') }
  let(:team) { create(:team, company: company, name: 'Engineering') }
  let(:huddle) { create(:huddle, team: team, started_at: Time.current) }

  describe 'associations' do
    it { should belong_to(:team) }
    it { should have_many(:huddle_participants).dependent(:destroy) }
    it { should have_many(:participants).through(:huddle_participants).source(:teammate) }
    it { should have_many(:huddle_feedbacks).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:started_at) }
    it { should validate_presence_of(:team) }

    describe 'unique team per day' do
      it 'allows multiple huddles for different teams on the same day' do
        other_team = create(:team, company: company, name: 'Design')
        other_huddle = Huddle.create!(team: other_team, started_at: Time.current)

        expect(huddle).to be_valid
      end

      it 'prevents duplicate huddles with the same team within 24 hours' do
        # Ensure the existing huddle exists
        expect(huddle).to be_persisted

        # Try to create another huddle with the same team within 24 hours
        duplicate_huddle = Huddle.new(
          started_at: Time.current + 12.hours, # Within 24 hours
          team: huddle.team
        )
        expect(duplicate_huddle).not_to be_valid
        expect(duplicate_huddle.errors[:base]).to include('A huddle for this team already exists within 24 hours')
      end

      it 'allows huddles with the same team after 24 hours' do
        # Ensure the existing huddle exists
        expect(huddle).to be_persisted

        # Try to create another huddle with the same team after 24 hours
        future_huddle = Huddle.new(
          started_at: Time.current + 25.hours, # After 24 hours
          team: huddle.team
        )
        expect(future_huddle).to be_valid
      end

      it 'allows huddles for different teams within 24 hours' do
        # Ensure the existing huddle exists
        expect(huddle).to be_persisted

        # Create a different team
        different_team = create(:team, company: company, name: 'Design')

        # Try to create another huddle with a different team within 24 hours
        different_huddle = Huddle.new(
          started_at: Time.current + 12.hours, # Within 24 hours
          team: different_team
        )
        expect(different_huddle).to be_valid
      end

      it 'allows huddles for the same team on different days' do
        tomorrow_huddle = Huddle.new(team: team, started_at: 1.day.from_now)
        expect(tomorrow_huddle).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:old_huddle) { Huddle.create!(team: team, started_at: 25.hours.ago, expires_at: 1.hour.ago) }
    let!(:recent_huddle) { Huddle.create!(team: create(:team, company: company), started_at: 1.hour.ago) }

    describe '.active' do
      it 'returns huddles that expire in the future' do
        expect(Huddle.active).to include(recent_huddle)
        expect(Huddle.active).not_to include(old_huddle)
      end
    end

    describe '.recent' do
      it 'returns huddles ordered by started_at desc' do
        expect(Huddle.recent.first).to eq(recent_huddle)
        expect(Huddle.recent.last).to eq(old_huddle)
      end
    end
  end

  describe '#display_name' do
    it 'returns company name, team name, and date' do
      expect(huddle.display_name).to include('Acme Corp')
      expect(huddle.display_name).to include('Engineering')
      expect(huddle.display_name).to include(Time.current.strftime('%B %d, %Y'))
    end
  end

  describe '#team' do
    it 'returns the team' do
      expect(huddle.team).to eq(team)
    end
  end

  describe '#company' do
    it 'returns the company from the team' do
      expect(huddle.company).to eq(company)
    end
  end

  describe '#slug' do
    it 'returns a URL-friendly slug' do
      expect(huddle.slug).to eq("acme-corp_engineering_#{Time.current.strftime('%Y-%m-%d')}")
    end
  end

  describe '#closed?' do
    context 'with no feedback' do
      it 'returns false' do
        expect(huddle.closed?).to be false
      end
    end

    context 'with feedback from today' do
      before do
        person = Person.create!(email: 'test@example.com', full_name: 'Test User', unique_textable_phone_number: '+12345678900')
        teammate = create(:teammate, person: person, organization: huddle.company)
        HuddleFeedback.create!(
          huddle: huddle,
          teammate: teammate,
          informed_rating: 5,
          connected_rating: 5,
          goals_rating: 5,
          valuable_rating: 5
        )
      end

      it 'returns false' do
        expect(huddle.closed?).to be false
      end
    end

    context 'with feedback from expired huddle' do
      let(:expired_huddle) { Huddle.create!(team: team, started_at: 25.hours.ago, expires_at: 1.hour.ago) }

      before do
        person = Person.create!(email: 'test@example.com', full_name: 'Test User', unique_textable_phone_number: '+12345678902')
        teammate = create(:teammate, person: person, organization: expired_huddle.company)
        HuddleFeedback.create!(
          huddle: expired_huddle,
          teammate: teammate,
          informed_rating: 5,
          connected_rating: 5,
          goals_rating: 5,
          valuable_rating: 5
        )
      end

      it 'returns true' do
        expect(expired_huddle.closed?).to be true
      end
    end
  end

  describe '#department_head' do
    it 'delegates to company' do
      expect(huddle.company).to receive(:department_head)
      huddle.department_head
    end
  end

  describe '#nat_20_score' do
    context 'with no feedback' do
      it 'returns nil' do
        expect(huddle.nat_20_score).to be_nil
      end
    end

    context 'with feedback' do
      let(:person) { Person.create!(email: 'test@example.com', full_name: 'Test User', unique_textable_phone_number: '+12345678903') }
      let(:teammate) { create(:teammate, person: person, organization: huddle.company) }

      before do
        HuddleFeedback.create!(
          huddle: huddle,
          teammate: teammate,
          informed_rating: 5,
          connected_rating: 4,
          goals_rating: 5,
          valuable_rating: 4
        )
      end

      it 'calculates the average score' do
        expect(huddle.nat_20_score).to eq(18.0)
      end

      it 'handles multiple feedback submissions' do
        person2 = Person.create!(email: 'test2@example.com', full_name: 'Test User 2', unique_textable_phone_number: '+12345678901')
        teammate2 = create(:teammate, person: person2, organization: huddle.company)
        HuddleFeedback.create!(
          huddle: huddle,
          teammate: teammate2,
          informed_rating: 5,
          connected_rating: 5,
          goals_rating: 5,
          valuable_rating: 5
        )

        expect(huddle.nat_20_score).to eq(19.0)
      end
    end
  end

  describe '#feedback_anonymous?' do
    context 'with no feedback' do
      it 'returns false' do
        expect(huddle.feedback_anonymous?).to be false
      end
    end

    context 'with anonymous feedback' do
      let(:person) { Person.create!(email: 'test@example.com', full_name: 'Test User') }
      let(:teammate) { create(:teammate, person: person, organization: huddle.company) }

      before do
        HuddleFeedback.create!(
          huddle: huddle,
          teammate: teammate,
          informed_rating: 5,
          connected_rating: 5,
          goals_rating: 5,
          valuable_rating: 5,
          anonymous: true
        )
      end

      it 'returns true' do
        expect(huddle.feedback_anonymous?).to be true
      end
    end

    context 'with non-anonymous feedback' do
      let(:person) { Person.create!(email: 'test@example.com', full_name: 'Test User') }
      let(:teammate) { create(:teammate, person: person, organization: huddle.company) }

      before do
        HuddleFeedback.create!(
          huddle: huddle,
          teammate: teammate,
          informed_rating: 5,
          connected_rating: 5,
          goals_rating: 5,
          valuable_rating: 5,
          anonymous: false
        )
      end

      it 'returns false' do
        expect(huddle.feedback_anonymous?).to be false
      end
    end
  end

  describe 'conflict style distributions' do
    let(:organization) { create(:organization, name: 'Test Org') }
    let(:team) { create(:team, company: organization) }
    let(:huddle) { create(:huddle, team: team) }
    let(:person1) { create(:person, first_name: 'John', last_name: 'Doe') }
    let(:person2) { create(:person, first_name: 'Jane', last_name: 'Smith') }
    let(:person3) { create(:person, first_name: 'Bob', last_name: 'Johnson') }
    let(:teammate1) { create(:teammate, person: person1, organization: organization) }
    let(:teammate2) { create(:teammate, person: person2, organization: organization) }
    let(:teammate3) { create(:teammate, person: person3, organization: organization) }

    before do
      create(:huddle_participant, huddle: huddle, teammate: teammate1)
      create(:huddle_participant, huddle: huddle, teammate: teammate2)
      create(:huddle_participant, huddle: huddle, teammate: teammate3)
    end

    describe '#team_conflict_style_distribution' do
      it 'returns empty hash when no feedback' do
        expect(huddle.team_conflict_style_distribution).to eq({})
      end

      it 'returns distribution of team conflict styles' do
        create(:huddle_feedback, huddle: huddle, teammate: teammate1, team_conflict_style: 'Collaborative')
        create(:huddle_feedback, huddle: huddle, teammate: teammate2, team_conflict_style: 'Collaborative')
        create(:huddle_feedback, huddle: huddle, teammate: teammate3, team_conflict_style: 'Competing')

        expect(huddle.team_conflict_style_distribution).to eq({
          'Collaborative' => 2,
          'Competing' => 1
        })
      end

      it 'excludes nil and empty values' do
        create(:huddle_feedback, huddle: huddle, teammate: teammate1, team_conflict_style: 'Collaborative')
        create(:huddle_feedback, huddle: huddle, teammate: teammate2, team_conflict_style: nil)
        create(:huddle_feedback, huddle: huddle, teammate: teammate3, team_conflict_style: '')

        expect(huddle.team_conflict_style_distribution).to eq({
          'Collaborative' => 1
        })
      end
    end

    describe '#personal_conflict_style_distribution' do
      it 'returns empty hash when no feedback' do
        expect(huddle.personal_conflict_style_distribution).to eq({})
      end

      it 'returns distribution of personal conflict styles' do
        create(:huddle_feedback, huddle: huddle, teammate: teammate1, personal_conflict_style: 'Compromising')
        create(:huddle_feedback, huddle: huddle, teammate: teammate2, personal_conflict_style: 'Accommodating')
        create(:huddle_feedback, huddle: huddle, teammate: teammate3, personal_conflict_style: 'Compromising')

        expect(huddle.personal_conflict_style_distribution).to eq({
          'Compromising' => 2,
          'Accommodating' => 1
        })
      end
    end

    describe '#all_conflict_styles' do
      it 'returns all possible conflict styles' do
        expect(huddle.all_conflict_styles).to eq([
          'Collaborative',
          'Competing',
          'Compromising',
          'Accommodating',
          'Avoiding'
        ])
      end
    end
  end
end
