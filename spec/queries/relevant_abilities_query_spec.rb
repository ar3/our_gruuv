require 'rails_helper'

RSpec.describe RelevantAbilitiesQuery, type: :query do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:department, company: organization, name: 'Engineering') }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:certifier) { create(:person) }
  
  let(:ability_with_milestone) { create(:ability, name: 'Ability A', company: organization) }
  let(:ability_with_assignment) { create(:ability, name: 'Ability B', company: organization) }
  let(:ability_with_both) { create(:ability, name: 'Ability C', company: organization) }
  let(:ability_outside_hierarchy) { create(:ability, name: 'Outside Ability', company: create(:organization, :company)) }
  let(:ability_in_department) { create(:ability, name: 'Department Ability', company: organization, department: department) }

  describe '#call' do
    context 'when teammate is nil' do
      it 'returns empty array' do
        query = RelevantAbilitiesQuery.new(teammate: nil, organization: organization)
        expect(query.call).to eq([])
      end
    end

    context 'when employee has milestone attainments' do
      it 'includes abilities where employee has milestones' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        milestone = create(:teammate_milestone, teammate: teammate, ability: ability_with_milestone, certifying_teammate: certifier_teammate, milestone_level: 2)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        expect(results).to be_present
        ability_data = results.find { |a| a[:ability].id == ability_with_milestone.id }
        expect(ability_data).to be_present
        expect(ability_data[:milestone_attainments]).to include(milestone)
        expect(ability_data[:assignment_requirements]).to be_empty
      end

      it 'includes all milestone attainments for each ability' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        milestone1 = create(:teammate_milestone, teammate: teammate, ability: ability_with_milestone, certifying_teammate: certifier_teammate, milestone_level: 1, attained_at: 6.months.ago)
        milestone2 = create(:teammate_milestone, teammate: teammate, ability: ability_with_milestone, certifying_teammate: certifier_teammate, milestone_level: 3, attained_at: 1.month.ago)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        ability_data = results.find { |a| a[:ability].id == ability_with_milestone.id }
        expect(ability_data[:milestone_attainments].size).to eq(2)
        expect(ability_data[:milestone_attainments]).to include(milestone1, milestone2)
      end
    end

    context 'when employee has active assignment requirements' do
      it 'includes abilities required by active assignments' do
        assignment = create(:assignment, company: organization, title: 'Test Assignment')
        create(:assignment_tenure, teammate: teammate, assignment: assignment, ended_at: nil)
        assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability_with_assignment, milestone_level: 3)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        expect(results).to be_present
        ability_data = results.find { |a| a[:ability].id == ability_with_assignment.id }
        expect(ability_data).to be_present
        expect(ability_data[:milestone_attainments]).to be_empty
        expect(ability_data[:assignment_requirements]).to include(assignment_ability)
      end

      it 'includes all assignment requirements for each ability' do
        assignment1 = create(:assignment, company: organization, title: 'Assignment 1')
        assignment2 = create(:assignment, company: organization, title: 'Assignment 2')
        create(:assignment_tenure, teammate: teammate, assignment: assignment1, ended_at: nil)
        create(:assignment_tenure, teammate: teammate, assignment: assignment2, ended_at: nil)
        assignment_ability1 = create(:assignment_ability, assignment: assignment1, ability: ability_with_assignment, milestone_level: 2)
        assignment_ability2 = create(:assignment_ability, assignment: assignment2, ability: ability_with_assignment, milestone_level: 4)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        ability_data = results.find { |a| a[:ability].id == ability_with_assignment.id }
        expect(ability_data[:assignment_requirements].size).to eq(2)
        expect(ability_data[:assignment_requirements]).to include(assignment_ability1, assignment_ability2)
      end

      it 'excludes abilities from inactive assignment tenures' do
        assignment = create(:assignment, company: organization, title: 'Inactive Assignment')
        create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 3.months.ago, ended_at: 1.month.ago)
        create(:assignment_ability, assignment: assignment, ability: ability_with_assignment, milestone_level: 2)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        ability_ids = results.map { |a| a[:ability].id }
        expect(ability_ids).not_to include(ability_with_assignment.id)
      end
    end

    context 'when employee has both milestones and assignment requirements' do
      it 'includes abilities with both and deduplicates correctly' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        milestone = create(:teammate_milestone, teammate: teammate, ability: ability_with_both, certifying_teammate: certifier_teammate, milestone_level: 2)
        assignment = create(:assignment, company: organization, title: 'Test Assignment')
        create(:assignment_tenure, teammate: teammate, assignment: assignment, ended_at: nil)
        assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability_with_both, milestone_level: 3)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        ability_data_list = results.select { |a| a[:ability].id == ability_with_both.id }
        expect(ability_data_list.size).to eq(1)
        expect(ability_data_list.first[:milestone_attainments]).to include(milestone)
        expect(ability_data_list.first[:assignment_requirements]).to include(assignment_ability)
      end
    end

    context 'organization hierarchy scoping' do
      it 'only includes abilities from organization hierarchy' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        create(:teammate_milestone, teammate: teammate, ability: ability_outside_hierarchy, certifying_teammate: certifier_teammate, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability_with_milestone, certifying_teammate: certifier_teammate, milestone_level: 1)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        ability_ids = results.map { |a| a[:ability].id }
        expect(ability_ids).to include(ability_with_milestone.id)
        expect(ability_ids).not_to include(ability_outside_hierarchy.id)
      end

      it 'includes abilities from departments within the organization hierarchy' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        milestone = create(:teammate_milestone, teammate: teammate, ability: ability_in_department, certifying_teammate: certifier_teammate, milestone_level: 2)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        ability_ids = results.map { |a| a[:ability].id }
        expect(ability_ids).to include(ability_in_department.id)
      end
    end

    context 'sorting' do
      it 'sorts abilities alphabetically by name' do
        ability_z = create(:ability, name: 'Z Ability', company: organization)
        ability_a = create(:ability, name: 'A Ability', company: organization)
        ability_m = create(:ability, name: 'M Ability', company: organization)
        
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        create(:teammate_milestone, teammate: teammate, ability: ability_z, certifying_teammate: certifier_teammate, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability_a, certifying_teammate: certifier_teammate, milestone_level: 1)
        create(:teammate_milestone, teammate: teammate, ability: ability_m, certifying_teammate: certifier_teammate, milestone_level: 1)
        
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        results = query.call
        
        ability_names = results.map { |a| a[:ability].name }
        expect(ability_names).to eq(['A Ability', 'M Ability', 'Z Ability'])
      end
    end

    context 'empty state' do
      it 'returns empty array when employee has no milestones or active assignments' do
        query = RelevantAbilitiesQuery.new(teammate: teammate, organization: organization)
        expect(query.call).to eq([])
      end
    end
  end
end











