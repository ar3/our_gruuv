require 'rails_helper'

RSpec.describe Huddle, type: :model do
  let(:company) { Company.create!(name: 'Acme Corp') }
  let(:team) { Team.create!(name: 'Engineering', parent: company) }
  let(:huddle) { Huddle.create!(organization: team, started_at: Time.current) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:huddle_participants).dependent(:destroy) }
    it { should have_many(:participants).through(:huddle_participants).source(:person) }
    it { should have_many(:huddle_feedbacks).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:started_at) }
    
    describe 'unique organization per day' do
      it 'allows multiple huddles for different organizations on the same day' do
        other_team = Team.create!(name: 'Design', parent: company)
        other_huddle = Huddle.create!(organization: other_team, started_at: Time.current)
        
        expect(huddle).to be_valid
      end
      
      it 'prevents duplicate huddles for the same organization on the same day' do
        # Ensure the existing huddle exists
        expect(huddle).to be_persisted
        
        duplicate_huddle = Huddle.new(organization: team, started_at: Time.current)
        expect(duplicate_huddle).not_to be_valid
        expect(duplicate_huddle.errors[:base]).to include('A huddle for this organization already exists today')
        expect(duplicate_huddle.errors[:existing_huddle_id]).to include(huddle.id)
      end
      
      it 'allows huddles for the same organization on different days' do
        tomorrow_huddle = Huddle.new(organization: team, started_at: 1.day.from_now)
        expect(tomorrow_huddle).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:old_huddle) { Huddle.create!(organization: team, started_at: 25.hours.ago, expires_at: 1.hour.ago) }
    let!(:recent_huddle) { Huddle.create!(organization: team, started_at: 1.hour.ago) }

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
    context 'without alias' do
      it 'returns organization name and date' do
        expect(huddle.display_name).to include('Acme Corp > Engineering')
        expect(huddle.display_name).to include(Time.current.strftime('%B %d, %Y'))
      end
    end

    context 'with alias' do
      let(:huddle_with_alias) { Huddle.create!(organization: team, started_at: Time.current, huddle_alias: 'Sprint Planning') }

      it 'includes the alias in the display name' do
        expect(huddle_with_alias.display_name).to include('Sprint Planning')
      end
    end
  end

  describe '#slug' do
    it 'returns a URL-friendly slug' do
      expect(huddle.slug).to eq("engineering_#{Time.current.strftime('%Y-%m-%d')}")
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
        HuddleFeedback.create!(
          huddle: huddle,
          person: person,
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
      let(:expired_huddle) { Huddle.create!(organization: team, started_at: 25.hours.ago, expires_at: 1.hour.ago) }

      before do
        person = Person.create!(email: 'test@example.com', full_name: 'Test User', unique_textable_phone_number: '+12345678902')
        HuddleFeedback.create!(
          huddle: expired_huddle,
          person: person,
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
    it 'delegates to organization' do
      expect(huddle.organization).to receive(:department_head)
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

      before do
        HuddleFeedback.create!(
          huddle: huddle,
          person: person,
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
        HuddleFeedback.create!(
          huddle: huddle,
          person: person2,
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

      before do
        HuddleFeedback.create!(
          huddle: huddle,
          person: person,
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

      before do
        HuddleFeedback.create!(
          huddle: huddle,
          person: person,
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
    let(:huddle) { create(:huddle, organization: organization) }
    let(:person1) { create(:person, first_name: 'John', last_name: 'Doe') }
    let(:person2) { create(:person, first_name: 'Jane', last_name: 'Smith') }
    let(:person3) { create(:person, first_name: 'Bob', last_name: 'Johnson') }

    before do
      create(:huddle_participant, huddle: huddle, person: person1)
      create(:huddle_participant, huddle: huddle, person: person2)
      create(:huddle_participant, huddle: huddle, person: person3)
    end

    describe '#team_conflict_style_distribution' do
      it 'returns empty hash when no feedback' do
        expect(huddle.team_conflict_style_distribution).to eq({})
      end

      it 'returns distribution of team conflict styles' do
        create(:huddle_feedback, huddle: huddle, person: person1, team_conflict_style: 'Collaborative')
        create(:huddle_feedback, huddle: huddle, person: person2, team_conflict_style: 'Collaborative')
        create(:huddle_feedback, huddle: huddle, person: person3, team_conflict_style: 'Competing')

        expect(huddle.team_conflict_style_distribution).to eq({
          'Collaborative' => 2,
          'Competing' => 1
        })
      end

      it 'excludes nil and empty values' do
        create(:huddle_feedback, huddle: huddle, person: person1, team_conflict_style: 'Collaborative')
        create(:huddle_feedback, huddle: huddle, person: person2, team_conflict_style: nil)
        create(:huddle_feedback, huddle: huddle, person: person3, team_conflict_style: '')

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
        create(:huddle_feedback, huddle: huddle, person: person1, personal_conflict_style: 'Compromising')
        create(:huddle_feedback, huddle: huddle, person: person2, personal_conflict_style: 'Accommodating')
        create(:huddle_feedback, huddle: huddle, person: person3, personal_conflict_style: 'Compromising')

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