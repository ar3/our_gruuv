require 'rails_helper'

RSpec.describe AssignmentsQuery, type: :query do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:department, company: organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  
  let(:assignment_company) { create(:assignment, company: organization, department: nil) }
  let(:assignment_department) { create(:assignment, company: organization, department: department) }
  let(:assignment_other_company) { create(:assignment, company: create(:organization, :company)) }
  
  let(:policy_scope) { Assignment.all }

  describe '#call' do
    context 'with no filters' do
      it 'returns all assignments in organization hierarchy' do
        query = AssignmentsQuery.new(organization, {}, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_company, assignment_department)
        expect(results).not_to include(assignment_other_company)
      end
    end

    context 'show_archived filter' do
      let!(:archived_assignment) do
        create(:assignment, company: organization, title: 'Archived One').tap { |a| a.update_columns(deleted_at: 1.day.ago) }
      end

      it 'excludes archived assignments by default' do
        query = AssignmentsQuery.new(organization, {}, current_person: person, policy_scope: policy_scope)
        results = query.call
        expect(results).to include(assignment_company, assignment_department)
        expect(results).not_to include(archived_assignment)
      end

      it 'includes archived assignments when show_archived=1' do
        query = AssignmentsQuery.new(organization, { show_archived: '1' }, current_person: person, policy_scope: policy_scope)
        results = query.call
        expect(results).to include(assignment_company, assignment_department, archived_assignment)
      end
    end

    context 'filtering by no department (company)' do
      it 'returns only assignments with nil department when "none" is selected' do
        query = AssignmentsQuery.new(organization, { departments: 'none' }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_company)
        expect(results).not_to include(assignment_department)
      end
    end

    context 'filtering by department' do
      it 'returns only assignments in selected department' do
        query = AssignmentsQuery.new(organization, { departments: department.id.to_s }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_department)
        expect(results).not_to include(assignment_company)
      end
    end

    context 'filtering by both no department and department' do
      it 'returns assignments matching either condition' do
        query = AssignmentsQuery.new(organization, { departments: "none,#{department.id}" }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_company, assignment_department)
      end
    end

    context 'filtering by multiple departments' do
      let(:department2) { create(:department, company: organization) }
      let(:assignment_department2) { create(:assignment, company: organization, department: department2) }
      
      it 'returns assignments from all selected departments' do
        query = AssignmentsQuery.new(organization, { departments: "#{department.id},#{department2.id}" }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_department, assignment_department2)
        expect(results).not_to include(assignment_company)
      end
    end

    context 'filtering by outcomes' do
      let(:assignment_with_outcomes) { create(:assignment, company: organization) }
      let(:assignment_without_outcomes) { create(:assignment, company: organization) }
      
      before do
        create(:assignment_outcome, assignment: assignment_with_outcomes)
      end

      it 'filters by outcomes with "with" filter' do
        query = AssignmentsQuery.new(organization, { outcomes_filter: 'with' }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_with_outcomes)
        expect(results).not_to include(assignment_without_outcomes)
      end

      it 'filters by outcomes with "without" filter' do
        query = AssignmentsQuery.new(organization, { outcomes_filter: 'without' }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_without_outcomes)
        expect(results).not_to include(assignment_with_outcomes)
      end
    end

    context 'filtering by abilities' do
      let(:ability) { create(:ability, company: organization) }
      let(:assignment_with_abilities) { create(:assignment, company: organization) }
      let(:assignment_without_abilities) { create(:assignment, company: organization) }
      
      before do
        create(:assignment_ability, assignment: assignment_with_abilities, ability: ability, milestone_level: 1)
      end

      it 'filters by abilities with "with" filter' do
        query = AssignmentsQuery.new(organization, { abilities_filter: 'with' }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_with_abilities)
        expect(results).not_to include(assignment_without_abilities)
      end

      it 'filters by abilities with "without" filter' do
        query = AssignmentsQuery.new(organization, { abilities_filter: 'without' }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_without_abilities)
        expect(results).not_to include(assignment_with_abilities)
      end
    end

    context 'filtering by major version' do
      let(:assignment_v1) { create(:assignment, company: organization, semantic_version: '1.0.0') }
      let(:assignment_v2) { create(:assignment, company: organization, semantic_version: '2.0.0') }
      
      it 'filters by major version' do
        query = AssignmentsQuery.new(organization, { major_version: 1 }, current_person: person, policy_scope: policy_scope)
        results = query.call
        
        expect(results).to include(assignment_v1)
        expect(results).not_to include(assignment_v2)
      end
    end

    context 'sorting' do
      let!(:assignment_a) { create(:assignment, company: organization, title: 'A Assignment') }
      let!(:assignment_b) { create(:assignment, company: organization, title: 'B Assignment') }
      let!(:assignment_z) { create(:assignment, company: organization, title: 'Z Assignment') }
      
      it 'sorts by title ascending' do
        query = AssignmentsQuery.new(organization, { sort: 'title' }, current_person: person, policy_scope: policy_scope)
        results = query.call.to_a
        
        a_index = results.index(assignment_a)
        b_index = results.index(assignment_b)
        z_index = results.index(assignment_z)
        
        expect(a_index).not_to be_nil
        expect(b_index).not_to be_nil
        expect(z_index).not_to be_nil
        expect(a_index).to be < b_index
        expect(b_index).to be < z_index
      end

      it 'sorts by title descending' do
        query = AssignmentsQuery.new(organization, { sort: 'title_desc' }, current_person: person, policy_scope: policy_scope)
        results = query.call.to_a
        
        a_index = results.index(assignment_a)
        b_index = results.index(assignment_b)
        z_index = results.index(assignment_z)
        
        expect(a_index).not_to be_nil
        expect(b_index).not_to be_nil
        expect(z_index).not_to be_nil
        expect(z_index).to be < b_index
        expect(b_index).to be < a_index
      end
    end
  end

  describe '#current_filters' do
    it 'returns empty hash when no filters applied' do
      query = AssignmentsQuery.new(organization, {}, current_person: person)
      expect(query.current_filters).to eq({})
    end

    it 'includes departments filter when present' do
      query = AssignmentsQuery.new(organization, { departments: "#{department.id},none" }, current_person: person)
      expect(query.current_filters[:departments]).to eq([department.id.to_s, 'none'])
    end

    it 'includes outcomes_filter when not "all"' do
      query = AssignmentsQuery.new(organization, { outcomes_filter: 'with' }, current_person: person)
      expect(query.current_filters[:outcomes_filter]).to eq('with')
    end

    it 'excludes outcomes_filter when "all"' do
      query = AssignmentsQuery.new(organization, { outcomes_filter: 'all' }, current_person: person)
      expect(query.current_filters[:outcomes_filter]).to be_nil
    end

    it 'includes show_archived when present and 1' do
      query = AssignmentsQuery.new(organization, { show_archived: '1' }, current_person: person)
      expect(query.current_filters[:show_archived]).to be true
    end
  end

  describe '#current_sort' do
    it 'defaults to department_and_title' do
      query = AssignmentsQuery.new(organization, {}, current_person: person)
      expect(query.current_sort).to eq('department_and_title')
    end

    it 'returns specified sort' do
      query = AssignmentsQuery.new(organization, { sort: 'title' }, current_person: person)
      expect(query.current_sort).to eq('title')
    end
  end

  describe '#current_view' do
    it 'defaults to table' do
      query = AssignmentsQuery.new(organization, {}, current_person: person)
      expect(query.current_view).to eq('table')
    end
  end

  describe '#current_spotlight' do
    it 'defaults to by_department' do
      query = AssignmentsQuery.new(organization, {}, current_person: person)
      expect(query.current_spotlight).to eq('by_department')
    end
  end
end
