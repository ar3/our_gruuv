require 'rails_helper'

RSpec.describe TeammateMilestone, type: :model do
  let(:organization) { create(:organization) }
  let(:ability) { create(:ability, organization: organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:certifier_person) { create(:person) }
  let(:certifier_teammate) { CompanyTeammate.find(create(:teammate, person: certifier_person, organization: organization).id) }
  let(:teammate_milestone) { create(:teammate_milestone, teammate: teammate, ability: ability, certifying_teammate: certifier_teammate) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(teammate_milestone).to be_valid
    end

    it 'requires a teammate' do
      teammate_milestone.teammate = nil
      expect(teammate_milestone).not_to be_valid
      expect(teammate_milestone.errors[:teammate]).to include('must exist')
    end

    it 'requires an ability' do
      teammate_milestone.ability = nil
      expect(teammate_milestone).not_to be_valid
      expect(teammate_milestone.errors[:ability]).to include('must exist')
    end

    it 'requires a milestone_level' do
      teammate_milestone.milestone_level = nil
      expect(teammate_milestone).not_to be_valid
      expect(teammate_milestone.errors[:milestone_level]).to include("can't be blank")
    end

    it 'validates milestone_level is between 1 and 5' do
      teammate_milestone.milestone_level = 0
      expect(teammate_milestone).not_to be_valid
      expect(teammate_milestone.errors[:milestone_level]).to include('must be greater than or equal to 1')

      teammate_milestone.milestone_level = 6
      expect(teammate_milestone).not_to be_valid
      expect(teammate_milestone.errors[:milestone_level]).to include('must be less than or equal to 5')

      teammate_milestone.milestone_level = 3
      expect(teammate_milestone).to be_valid
    end

    it 'requires a certifying_teammate' do
      teammate_milestone.certifying_teammate = nil
      expect(teammate_milestone).not_to be_valid
      expect(teammate_milestone.errors[:certifying_teammate]).to include('must exist')
    end

    it 'requires an attained_at date' do
      teammate_milestone.attained_at = nil
      expect(teammate_milestone).not_to be_valid
      expect(teammate_milestone.errors[:attained_at]).to include("can't be blank")
    end

    it 'enforces unique teammate-ability-milestone combinations' do
      create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 3, certifying_teammate: certifier_teammate)
      duplicate = build(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 3, certifying_teammate: certifier_teammate)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:milestone_level]).to include('has already been taken for this teammate and ability')
    end

    it 'allows same milestone level for different abilities' do
      other_ability = create(:ability, organization: organization)
      create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 3, certifying_teammate: certifier_teammate)
      other_milestone = build(:teammate_milestone, teammate: teammate, ability: other_ability, milestone_level: 3, certifying_teammate: certifier_teammate)
      
      expect(other_milestone).to be_valid
    end

    it 'allows same milestone level for different people' do
      other_person = create(:person)
      other_teammate = create(:teammate, person: other_person, organization: organization)
      create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 3, certifying_teammate: certifier_teammate)
      other_milestone = build(:teammate_milestone, teammate: other_teammate, ability: ability, milestone_level: 3, certifying_teammate: certifier_teammate)
      
      expect(other_milestone).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to a teammate' do
      expect(teammate_milestone).to belong_to(:teammate)
    end

    it 'belongs to an ability' do
      expect(teammate_milestone).to belong_to(:ability)
    end

    it 'belongs to a certifying_teammate' do
      expect(teammate_milestone).to belong_to(:certifying_teammate).class_name('CompanyTeammate')
    end
  end

  describe 'scopes' do
    let!(:milestone_1) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, certifying_teammate: certifier_teammate) }
    let!(:milestone_3) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 3, certifying_teammate: certifier_teammate) }
    let!(:milestone_5) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 5, certifying_teammate: certifier_teammate) }

    describe '.by_milestone_level' do
      it 'orders by milestone level ascending' do
        result = TeammateMilestone.by_milestone_level
        expect(result.to_a).to eq([milestone_1, milestone_3, milestone_5])
      end
    end

    describe '.for_teammate' do
      it 'returns milestones for specific teammate' do
        other_person = create(:person)
        other_teammate = create(:teammate, person: other_person, organization: organization)
        other_milestone = create(:teammate_milestone, teammate: other_teammate, ability: ability, milestone_level: 2, certifying_teammate: certifier_teammate)

        result = TeammateMilestone.for_teammate(teammate)
        expect(result).to include(milestone_1, milestone_3, milestone_5)
        expect(result).not_to include(other_milestone)
      end
    end

    describe '.for_ability' do
      it 'returns milestones for specific ability' do
        other_ability = create(:ability, organization: organization)
        other_milestone = create(:teammate_milestone, teammate: teammate, ability: other_ability, milestone_level: 2, certifying_teammate: certifier_teammate)

        result = TeammateMilestone.for_ability(ability)
        expect(result).to include(milestone_1, milestone_3, milestone_5)
        expect(result).not_to include(other_milestone)
      end
    end

    describe '.recent' do
      it 'orders by attained_at descending' do
        milestone_1.update!(attained_at: 3.days.ago)
        milestone_3.update!(attained_at: 1.day.ago)
        milestone_5.update!(attained_at: 2.days.ago)

        result = TeammateMilestone.recent
        expect(result.to_a).to eq([milestone_3, milestone_5, milestone_1])
      end
    end
  end

  describe 'instance methods' do
    describe '#milestone_level_display' do
      it 'returns formatted milestone level' do
        teammate_milestone.milestone_level = 3
        expect(teammate_milestone.milestone_level_display).to eq('Milestone 3')
      end
    end

    describe '#attainment_display' do
      it 'returns formatted attainment description' do
        teammate_milestone.milestone_level = 2
        teammate_milestone.attained_at = Date.new(2024, 1, 15)
        expect(teammate_milestone.attainment_display).to eq("#{ability.name} - Milestone 2 (attained January 15, 2024)")
      end
    end

    describe '#certifier_display' do
      it 'returns certifier name' do
        certifier_person.update!(first_name: 'John', last_name: 'Manager')
        expect(teammate_milestone.certifier_display).to eq('John Manager')
      end
    end
  end

  describe 'new fields and methods' do
    describe '#published?' do
      it 'returns true when published_at is present' do
        teammate_milestone.published_at = Time.current
        expect(teammate_milestone.published?).to be true
      end

      it 'returns false when published_at is nil' do
        teammate_milestone.published_at = nil
        expect(teammate_milestone.published?).to be false
      end
    end

    describe '#public_profile_published?' do
      it 'returns true when public_profile_published_at is present' do
        teammate_milestone.public_profile_published_at = Time.current
        expect(teammate_milestone.public_profile_published?).to be true
      end

      it 'returns false when public_profile_published_at is nil' do
        teammate_milestone.public_profile_published_at = nil
        expect(teammate_milestone.public_profile_published?).to be false
      end
    end

    describe '#eligible_viewers' do
      it 'includes the employee' do
        viewers = teammate_milestone.eligible_viewers
        expect(viewers.map { |v| v[:person] }).to include(teammate.person)
      end
    end
  end

  describe 'scopes for publishing' do
    let(:other_ability) { create(:ability, organization: organization) }
    let!(:published_milestone) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 1, published_at: Time.current, certifying_teammate: certifier_teammate) }
    let!(:unpublished_milestone) { create(:teammate_milestone, teammate: teammate, ability: ability, milestone_level: 2, published_at: nil, certifying_teammate: certifier_teammate) }
    let!(:public_profile_milestone) { create(:teammate_milestone, teammate: teammate, ability: other_ability, milestone_level: 1, public_profile_published_at: Time.current, certifying_teammate: certifier_teammate) }

    describe '.published' do
      it 'returns only published milestones' do
        expect(TeammateMilestone.published).to include(published_milestone)
        expect(TeammateMilestone.published).not_to include(unpublished_milestone)
      end
    end

    describe '.unpublished' do
      it 'returns only unpublished milestones' do
        expect(TeammateMilestone.unpublished).to include(unpublished_milestone)
        expect(TeammateMilestone.unpublished).not_to include(published_milestone)
      end
    end

    describe '.public_profile_published' do
      it 'returns only public profile published milestones' do
        expect(TeammateMilestone.public_profile_published).to include(public_profile_milestone)
        expect(TeammateMilestone.public_profile_published).not_to include(unpublished_milestone)
      end
    end
  end
end
