require 'rails_helper'

RSpec.describe Organizations::CheckInsController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person, full_name: 'Manager Person') }
  let(:employee) { create(:person, full_name: 'Employee Person') }
  let(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer') }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level, level: '1.2') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: 'Frontend Development') }
  let(:aspiration) { create(:aspiration, organization: organization, name: 'Technical Skills') }

  let(:employment_tenure) { create(:employment_tenure, teammate: employee_teammate, company: organization, manager: manager, position: position) }
  let(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }

  before do
    session[:current_person_id] = manager.id
    manager_teammate
    employee_teammate
    employment_tenure
    assignment_tenure
  end

  describe 'PATCH #update' do
    context 'as manager' do
      # Manager session already set in main before block

      it 'updates position check-in with manager fields' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        
        patch :update, params: {
          organization_id: organization.id,
        person_id: employee.id,
          position_check_in: {
            manager_rating: 2,  # Integer value for "Praising/Trusting"
            manager_private_notes: 'Outstanding work',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
        expect(flash[:notice]).to eq('Check-ins saved successfully.')
        
        position_check_in.reload
        expect(position_check_in.manager_rating).to eq(2)
        expect(position_check_in.manager_private_notes).to eq('Outstanding work')
        expect(position_check_in.manager_completed?).to be true
      end

      it 'updates assignment check-ins with manager fields' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          assignment_check_ins: {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              manager_rating: 'meeting',
              manager_private_notes: 'Good progress',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
        
        assignment_check_in.reload
        expect(assignment_check_in.manager_rating).to eq('meeting')
        expect(assignment_check_in.manager_private_notes).to eq('Good progress')
        expect(assignment_check_in.manager_completed?).to be true
      end

      it 'updates aspiration check-ins with manager fields' do
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          aspiration_check_ins: {
            aspiration_check_in.id => {
              aspiration_id: aspiration.id,
              manager_rating: 'exceeding',
              manager_private_notes: 'Excellent growth',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
        
        aspiration_check_in.reload
        expect(aspiration_check_in.manager_rating).to eq('exceeding')
        expect(aspiration_check_in.manager_private_notes).to eq('Excellent growth')
        expect(aspiration_check_in.manager_completed?).to be true
      end

      it 'handles multiple check-ins in single request' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          assignment_check_ins: {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              manager_rating: 'meeting',
              manager_private_notes: 'Good work',
              status: 'complete'
            }
          },
          aspiration_check_ins: {
            aspiration_check_in.id => {
              aspiration_id: aspiration.id,
              manager_rating: 'exceeding',
              manager_private_notes: 'Great progress',
              status: 'draft'
            }
          }
        }

        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
        
        assignment_check_in.reload
        aspiration_check_in.reload
        
        expect(assignment_check_in.manager_completed?).to be true
        expect(aspiration_check_in.manager_completed?).to be false
      end
    end

    context 'as employee' do
      before { session[:current_person_id] = employee.id }

      it 'updates position check-in with employee fields' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          position_check_in: {
            employee_rating: 1,  # Integer value for "Meeting"
            employee_private_notes: 'Making good progress',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
        
        position_check_in.reload
        expect(position_check_in.employee_rating).to eq(1)
        expect(position_check_in.employee_private_notes).to eq('Making good progress')
        expect(position_check_in.employee_completed?).to be true
      end

      it 'updates assignment check-ins with employee fields' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          assignment_check_ins: {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              employee_rating: 'exceeding',
              employee_private_notes: 'Love this work',
              actual_energy_percentage: 85,
              employee_personal_alignment: 'love',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
        
        assignment_check_in.reload
        expect(assignment_check_in.employee_rating).to eq('exceeding')
        expect(assignment_check_in.employee_private_notes).to eq('Love this work')
        expect(assignment_check_in.actual_energy_percentage).to eq(85)
        expect(assignment_check_in.employee_personal_alignment).to eq('love')
        expect(assignment_check_in.employee_completed?).to be true
      end

      it 'updates aspiration check-ins with employee fields' do
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          aspiration_check_ins: {
            aspiration_check_in.id => {
              aspiration_id: aspiration.id,
              employee_rating: 'meeting',
              employee_private_notes: 'Learning a lot',
              status: 'draft'
            }
          }
        }

        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
        
        aspiration_check_in.reload
        expect(aspiration_check_in.employee_rating).to eq('meeting')
        expect(aspiration_check_in.employee_private_notes).to eq('Learning a lot')
        expect(aspiration_check_in.employee_completed?).to be false
      end
    end

    context 'status transitions' do
      # Manager session already set in main before block

      it 'handles draft to complete transition' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          position_check_in: {
            manager_rating: 2,
            manager_private_notes: 'Great work',
            status: 'complete'
          }
        }

        position_check_in.reload
        expect(position_check_in.manager_completed?).to be true
        expect(position_check_in.manager_completed_at).to be_present
      end

      it 'handles complete to draft transition' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        position_check_in.complete_manager_side!(completed_by: manager)
        
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          position_check_in: {
            manager_rating: 1,
            manager_private_notes: 'Updated assessment',
            status: 'draft'
          }
        }

        position_check_in.reload
        expect(position_check_in.manager_completed?).to be false
        expect(position_check_in.manager_completed_at).to be_nil
      end
    end

    context 'parameter format validation' do
      # Manager session already set in main before block

      it 'accepts old manual tag format for assignment check-ins' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment, manager_rating: nil)
        
        # Check initial state
        expect(assignment_check_in.manager_rating).to be_nil
        
        # This should update since we support dual-format for backward compatibility
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          '[assignment_check_ins]' => {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              manager_rating: 'meeting',
              status: 'complete'
            }
          }
        }

        assignment_check_in.reload
        expect(assignment_check_in.manager_rating).to eq('meeting')
        expect(assignment_check_in.manager_completed?).to be true
      end

      it 'accepts old manual tag format for aspiration check-ins' do
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        
        # This should update since we support dual-format for backward compatibility
        patch :update, params: {
          organization_id: organization.id,
          person_id: employee.id,
          '[aspiration_check_ins]' => {
            aspiration_check_in.id => {
              aspiration_id: aspiration.id,
              manager_rating: 'exceeding',
              status: 'complete'
            }
          }
        }

        aspiration_check_in.reload
        expect(aspiration_check_in.manager_rating).to eq('exceeding')
        expect(aspiration_check_in.manager_completed?).to be true
      end

      it 'accepts old manual tag format for position check-ins' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        
        # This should update since we support dual-format for backward compatibility
        patch :update, params: {
          organization_id: organization.id,
        person_id: employee.id,
          '[position_check_in]' => {
            manager_rating: 1,
            manager_private_notes: 'Test notes',
            status: 'complete'
          }
        }

        position_check_in.reload
        expect(position_check_in.manager_rating).to eq(1)
        expect(position_check_in.manager_completed?).to be true
      end
    end
  end

  describe 'GET #show' do
    context 'load_relevant_abilities' do
      let(:ability_with_milestone) { create(:ability, name: 'Ability A', organization: organization) }
      let(:ability_with_assignment) { create(:ability, name: 'Ability B', organization: organization) }
      let(:ability_with_both) { create(:ability, name: 'Ability C', organization: organization) }
      let(:ability_outside_hierarchy) { create(:ability, name: 'Outside Ability', organization: create(:organization, :company)) }
      let(:certifier) { create(:person) }

      before do
        session[:current_person_id] = manager.id
        employment_tenure
      end

      it 'includes abilities where employee has milestone attainments' do
        milestone = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certified_by: certifier, milestone_level: 2)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        expect(assigns(:relevant_abilities)).to be_present
        ability_data = assigns(:relevant_abilities).find { |a| a[:ability].id == ability_with_milestone.id }
        expect(ability_data).to be_present
        expect(ability_data[:milestone_attainments]).to include(milestone)
        expect(ability_data[:assignment_requirements]).to be_empty
      end

      it 'includes abilities required by active assignments' do
        assignment_with_ability = create(:assignment, company: organization, title: 'Test Assignment')
        active_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_with_ability, ended_at: nil)
        assignment_ability = create(:assignment_ability, assignment: assignment_with_ability, ability: ability_with_assignment, milestone_level: 3)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        expect(assigns(:relevant_abilities)).to be_present
        ability_data = assigns(:relevant_abilities).find { |a| a[:ability].id == ability_with_assignment.id }
        expect(ability_data).to be_present
        expect(ability_data[:milestone_attainments]).to be_empty
        expect(ability_data[:assignment_requirements]).to include(assignment_ability)
      end

      it 'includes abilities with both milestones and assignment requirements' do
        milestone = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_both, certified_by: certifier, milestone_level: 1)
        assignment_with_ability = create(:assignment, company: organization, title: 'Test Assignment')
        active_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_with_ability, ended_at: nil)
        assignment_ability = create(:assignment_ability, assignment: assignment_with_ability, ability: ability_with_both, milestone_level: 3)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        expect(assigns(:relevant_abilities)).to be_present
        ability_data = assigns(:relevant_abilities).find { |a| a[:ability].id == ability_with_both.id }
        expect(ability_data).to be_present
        expect(ability_data[:milestone_attainments]).to include(milestone)
        expect(ability_data[:assignment_requirements]).to include(assignment_ability)
      end

      it 'deduplicates abilities that appear in both milestone and assignment lists' do
        milestone = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_both, certified_by: certifier, milestone_level: 2)
        assignment_with_ability = create(:assignment, company: organization, title: 'Test Assignment')
        active_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_with_ability, ended_at: nil)
        assignment_ability = create(:assignment_ability, assignment: assignment_with_ability, ability: ability_with_both, milestone_level: 3)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_data_list = relevant_abilities.select { |a| a[:ability].id == ability_with_both.id }
        expect(ability_data_list.size).to eq(1)
        expect(ability_data_list.first[:milestone_attainments]).to include(milestone)
        expect(ability_data_list.first[:assignment_requirements]).to include(assignment_ability)
      end

      it 'only includes abilities from organization hierarchy' do
        milestone_outside = create(:teammate_milestone, teammate: employee_teammate, ability: ability_outside_hierarchy, certified_by: certifier, milestone_level: 1)
        milestone_inside = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certified_by: certifier, milestone_level: 1)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_ids = relevant_abilities.map { |a| a[:ability].id }
        expect(ability_ids).to include(ability_with_milestone.id)
        expect(ability_ids).not_to include(ability_outside_hierarchy.id)
      end

      it 'includes abilities from departments within the organization hierarchy' do
        department = create(:organization, type: 'Department', parent: organization, name: 'Engineering Department')
        ability_in_department = create(:ability, name: 'Department Ability', organization: department)
        milestone = create(:teammate_milestone, teammate: employee_teammate, ability: ability_in_department, certified_by: certifier, milestone_level: 2)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_ids = relevant_abilities.map { |a| a[:ability].id }
        expect(ability_ids).to include(ability_in_department.id)
      end

      it 'sorts abilities alphabetically by name' do
        ability_z = create(:ability, name: 'Z Ability', organization: organization)
        ability_a = create(:ability, name: 'A Ability', organization: organization)
        ability_m = create(:ability, name: 'M Ability', organization: organization)
        
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_z, certified_by: certifier, milestone_level: 1)
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_a, certified_by: certifier, milestone_level: 1)
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_m, certified_by: certifier, milestone_level: 1)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_names = relevant_abilities.map { |a| a[:ability].name }
        expect(ability_names).to eq(['A Ability', 'M Ability', 'Z Ability'])
      end

      it 'includes all milestone attainments for each ability' do
        milestone1 = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certified_by: certifier, milestone_level: 1, attained_at: 6.months.ago)
        milestone2 = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certified_by: certifier, milestone_level: 3, attained_at: 1.month.ago)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        ability_data = assigns(:relevant_abilities).find { |a| a[:ability].id == ability_with_milestone.id }
        expect(ability_data[:milestone_attainments].size).to eq(2)
        expect(ability_data[:milestone_attainments]).to include(milestone1, milestone2)
      end

      it 'includes all assignment requirements for each ability' do
        assignment1 = create(:assignment, company: organization, title: 'Assignment 1')
        assignment2 = create(:assignment, company: organization, title: 'Assignment 2')
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, ended_at: nil)
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2, ended_at: nil)
        assignment_ability1 = create(:assignment_ability, assignment: assignment1, ability: ability_with_assignment, milestone_level: 2)
        assignment_ability2 = create(:assignment_ability, assignment: assignment2, ability: ability_with_assignment, milestone_level: 4)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        ability_data = assigns(:relevant_abilities).find { |a| a[:ability].id == ability_with_assignment.id }
        expect(ability_data[:assignment_requirements].size).to eq(2)
        expect(ability_data[:assignment_requirements]).to include(assignment_ability1, assignment_ability2)
      end

      it 'excludes abilities from inactive assignment tenures' do
        assignment = create(:assignment, company: organization, title: 'Inactive Assignment')
        inactive_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 3.months.ago, ended_at: 1.month.ago)
        assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability_with_assignment, milestone_level: 2)
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_ids = relevant_abilities.map { |a| a[:ability].id }
        expect(ability_ids).not_to include(ability_with_assignment.id)
      end

      it 'handles empty state when employee has no milestones or active assignments' do
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        expect(assigns(:relevant_abilities)).to be_empty
      end
    end
  end
end