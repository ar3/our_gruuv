require 'rails_helper'

RSpec.describe Organization, type: :model do
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  let(:person1) { create(:person) }
  let(:person2) { create(:person) }
  let(:teammate1) { create(:teammate, person: person1, organization: company) }
  let(:teammate2) { create(:teammate, person: person2, organization: company) }
  let(:huddle_playbook) { create(:huddle_playbook, organization: team) }
  let(:huddle) { create(:huddle, huddle_playbook: huddle_playbook) }
  let!(:huddle_participant1) { create(:huddle_participant, huddle: huddle, teammate: teammate1) }
  let!(:huddle_participant2) { create(:huddle_participant, huddle: huddle, teammate: teammate2) }

  describe '#huddle_participants' do
    it 'returns people who participated in huddles within the organization' do
      expect(company.huddle_participants).to include(person1, person2)
    end

    it 'includes participants from child organizations' do
      expect(company.huddle_participants).to include(person1, person2)
    end

    it 'returns distinct participants' do
      # Create another huddle with a different playbook to avoid validation issues
      another_playbook = create(:huddle_playbook, organization: team)
      another_huddle = create(:huddle, huddle_playbook: another_playbook)
      create(:huddle_participant, huddle: another_huddle, teammate: teammate1)
      
      expect(company.huddle_participants.count).to eq(2) # person1 and person2, not duplicated
    end

    it 'returns empty when no huddles exist' do
      empty_company = create(:organization, :company)
      expect(empty_company.huddle_participants).to be_empty
    end
  end

  describe '#just_huddle_participants' do
    it 'returns only huddle participants who are not active employees' do
      # Create an employment tenure for person1 (making them an employee)
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      position_type = create(:position_type, organization: company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
      position = create(:position, position_type: position_type, position_level: position_level)
      create(:employment_tenure, teammate: teammate1, company: company, position: position)
      
      # person2 has no employment tenure (just a huddle participant)
      
      expect(company.just_huddle_participants).to include(person2)
      expect(company.just_huddle_participants).not_to include(person1)
    end

    it 'returns empty when all huddle participants are employees' do
      # Make both people employees
      position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
      position_type = create(:position_type, organization: company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
      position = create(:position, position_type: position_type, position_level: position_level)
      
      create(:employment_tenure, teammate: teammate1, company: company, position: position)
      create(:employment_tenure, teammate: teammate2, company: company, position: position)
      
      expect(company.just_huddle_participants).to be_empty
    end
  end

  describe '#teammate_milestones_for_person' do
    let(:ability) { create(:ability, organization: company) }
    let(:certifier) { create(:person) }

    it 'returns milestones for a person in the organization' do
      # Create a milestone for person1
      teammate_milestone = create(:teammate_milestone, 
        teammate: teammate1, 
        ability: ability, 
        certified_by: certifier, 
        milestone_level: 2,
        attained_at: 30.days.ago
      )

      result = company.teammate_milestones_for_person(person1)
      
      expect(result).to be_an(ActiveRecord::Relation)
      expect(result.count).to eq(1)
      expect(result.first).to eq(teammate_milestone)
    end

    it 'returns empty collection when person has no teammate record' do
      person_without_teammate = create(:person)
      
      result = company.teammate_milestones_for_person(person_without_teammate)
      
      expect(result).to be_an(ActiveRecord::Relation)
      expect(result).to be_empty
    end

    it 'only returns milestones for abilities in the organization' do
      # Create ability in different organization
      other_company = create(:organization, :company)
      other_ability = create(:ability, organization: other_company)
      
      # Create milestones for both abilities
      milestone_in_company = create(:teammate_milestone, 
        teammate: teammate1, 
        ability: ability, 
        certified_by: certifier, 
        milestone_level: 2,
        attained_at: 30.days.ago
      )
      milestone_in_other_company = create(:teammate_milestone, 
        teammate: teammate1, 
        ability: other_ability, 
        certified_by: certifier, 
        milestone_level: 3,
        attained_at: 30.days.ago
      )

      result = company.teammate_milestones_for_person(person1)
      
      expect(result).to include(milestone_in_company)
      expect(result).not_to include(milestone_in_other_company)
    end

    it 'returns empty collection when teammate has no milestones' do
      result = company.teammate_milestones_for_person(person1)
      
      expect(result).to be_an(ActiveRecord::Relation)
      expect(result).to be_empty
    end
  end
end 