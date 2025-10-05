require 'rails_helper'

RSpec.describe HuddleFeedback, type: :model do
  let(:company) { Company.create!(name: 'Test Company') }
  let(:team) { Team.create!(name: 'Test Team', parent: company) }
  let(:huddle) do
    playbook = create(:huddle_playbook, organization: team, special_session_name: 'test-huddle')
    Huddle.create!(huddle_playbook: playbook, started_at: Time.current)
  end
  let(:person) { Person.create!(full_name: 'John Doe', email: 'john@example.com') }
  let(:teammate) { Teammate.create!(person: person, organization: team) }

  before do
    # Clear any existing test data
    Huddle.destroy_all
    Person.destroy_all
    Company.destroy_all
  end

  describe 'associations' do
    it 'belongs to a huddle' do
      feedback = HuddleFeedback.new(huddle: huddle, teammate: teammate)
      expect(feedback.huddle).to eq(huddle)
    end

    it 'belongs to a teammate' do
      feedback = HuddleFeedback.new(huddle: huddle, teammate: teammate)
      expect(feedback.teammate).to eq(teammate)
    end
  end

  let(:valid_attributes) do
    {
      huddle: huddle,
      teammate: teammate,
      informed_rating: 4,
      connected_rating: 5,
      goals_rating: 4,
      valuable_rating: 5
    }
  end

  describe 'validations' do

    it 'is valid with valid attributes' do
      feedback = HuddleFeedback.new(valid_attributes)
      expect(feedback).to be_valid
    end

    it 'requires a huddle' do
      feedback = HuddleFeedback.new(valid_attributes.except(:huddle))
      expect(feedback).not_to be_valid
      expect(feedback.errors[:huddle]).to include('must exist')
    end

    it 'requires a teammate' do
      feedback = HuddleFeedback.new(valid_attributes.except(:teammate))
      expect(feedback).not_to be_valid
      expect(feedback.errors[:teammate]).to include('must exist')
    end

    it 'requires informed_rating' do
      feedback = HuddleFeedback.new(valid_attributes.except(:informed_rating))
      expect(feedback).not_to be_valid
      expect(feedback.errors[:informed_rating]).to include("can't be blank")
    end

    it 'requires connected_rating' do
      feedback = HuddleFeedback.new(valid_attributes.except(:connected_rating))
      expect(feedback).not_to be_valid
      expect(feedback.errors[:connected_rating]).to include("can't be blank")
    end

    it 'requires goals_rating' do
      feedback = HuddleFeedback.new(valid_attributes.except(:goals_rating))
      expect(feedback).not_to be_valid
      expect(feedback.errors[:goals_rating]).to include("can't be blank")
    end

    it 'requires valuable_rating' do
      feedback = HuddleFeedback.new(valid_attributes.except(:valuable_rating))
      expect(feedback).not_to be_valid
      expect(feedback.errors[:valuable_rating]).to include("can't be blank")
    end

    it 'validates ratings are between 0 and 5' do
      [-1, 6].each do |invalid_rating|
        feedback = HuddleFeedback.new(valid_attributes.merge(informed_rating: invalid_rating))
        expect(feedback).not_to be_valid
        expect(feedback.errors[:informed_rating]).to include('is not included in the list')
      end
    end

    it 'allows ratings from 0 to 5' do
      (0..5).each do |rating|
        feedback = HuddleFeedback.new(valid_attributes.merge(informed_rating: rating))
        expect(feedback).to be_valid, "Rating #{rating} should be valid"
      end
    end

    it 'prevents duplicate feedback from the same teammate for the same huddle' do
      HuddleFeedback.create!(valid_attributes)
      duplicate = HuddleFeedback.new(valid_attributes)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:teammate_id]).to include('has already been taken')
    end

    it 'allows feedback from different teammates for the same huddle' do
      person2 = Person.create!(full_name: 'Jane Smith', email: 'jane@example.com')
      teammate2 = Teammate.create!(person: person2, organization: team)
      HuddleFeedback.create!(valid_attributes)
      feedback2 = HuddleFeedback.new(valid_attributes.merge(teammate: teammate2))
      expect(feedback2).to be_valid
    end

    it 'allows feedback from the same teammate for different huddles' do
      team2 = Team.create!(name: 'Test Team 2', parent: company)
      playbook2 = create(:huddle_playbook, organization: team2, special_session_name: 'test-huddle-2')
            huddle2 = Huddle.create!(huddle_playbook: playbook2, started_at: Time.current)
      HuddleFeedback.create!(valid_attributes)
      feedback2 = HuddleFeedback.new(valid_attributes.merge(huddle: huddle2))
      expect(feedback2).to be_valid
    end

    it 'validates conflict styles are from allowed list' do
      feedback = HuddleFeedback.new(valid_attributes.merge(
        personal_conflict_style: 'Collaborative',
        team_conflict_style: 'Compromising'
      ))
      expect(feedback).to be_valid
    end

    it 'allows blank conflict styles' do
      feedback = HuddleFeedback.new(valid_attributes.merge(
        personal_conflict_style: '',
        team_conflict_style: nil
      ))
      expect(feedback).to be_valid
    end

    it 'rejects invalid conflict styles' do
      feedback = HuddleFeedback.new(valid_attributes.merge(
        personal_conflict_style: 'Invalid Style'
      ))
      expect(feedback).not_to be_valid
      expect(feedback.errors[:personal_conflict_style]).to include('is not included in the list')
    end
  end

  describe 'constants' do
    it 'defines CONFLICT_STYLES constant' do
      expect(HuddleFeedback::CONFLICT_STYLES).to be_an(Array)
      expect(HuddleFeedback::CONFLICT_STYLES).to include('Collaborative', 'Competing', 'Compromising', 'Accommodating', 'Avoiding')
    end
  end

  describe 'scopes' do
    let!(:anonymous_feedback) { HuddleFeedback.create!(valid_attributes.merge(anonymous: true)) }
    let!(:named_feedback) { 
      person2 = Person.create!(full_name: 'Jane', email: 'jane@example.com')
      teammate2 = Teammate.create!(person: person2, organization: team)
      HuddleFeedback.create!(valid_attributes.merge(teammate: teammate2, anonymous: false)) 
    }

    describe '.anonymous' do
      it 'returns only anonymous feedback' do
        expect(HuddleFeedback.anonymous).to include(anonymous_feedback)
        expect(HuddleFeedback.anonymous).not_to include(named_feedback)
      end
    end

    describe '.named' do
      it 'returns only named feedback' do
        expect(HuddleFeedback.named).to include(named_feedback)
        expect(HuddleFeedback.named).not_to include(anonymous_feedback)
      end
    end
  end

  describe 'instance methods' do
    let(:feedback) { HuddleFeedback.new(valid_attributes) }

    describe '#nat_20_score' do
      it 'calculates the sum of all ratings' do
        expect(feedback.nat_20_score).to eq(18) # 4 + 5 + 4 + 5
      end
    end

    describe '#perfect_nat_20?' do
      it 'returns true when all ratings are 5' do
        perfect_feedback = HuddleFeedback.new(valid_attributes.merge(
          informed_rating: 5,
          connected_rating: 5,
          goals_rating: 5,
          valuable_rating: 5
        ))
        expect(perfect_feedback.perfect_nat_20?).to be true
      end

      it 'returns false when not all ratings are 5' do
        expect(feedback.perfect_nat_20?).to be false
      end
    end

    describe '#has_private_feedback?' do
      it 'returns true when private feedback is present' do
        feedback.private_department_head = 'Some private feedback'
        expect(feedback.has_private_feedback?).to be true
      end

      it 'returns false when no private feedback is present' do
        expect(feedback.has_private_feedback?).to be false
      end
    end

    describe '#display_name' do
      it 'returns "Anonymous" when feedback is anonymous' do
        feedback.anonymous = true
        expect(feedback.display_name).to eq('Anonymous')
      end

      it 'returns person name when feedback is not anonymous' do
        feedback.anonymous = false
        expect(feedback.display_name).to eq(person.full_name)
      end
    end
  end
end
