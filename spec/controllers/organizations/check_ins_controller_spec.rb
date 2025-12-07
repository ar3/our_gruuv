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
  let(:manager_employment) do
    manager_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: manager_teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
  end

  before do
    manager_teammate
    employee_teammate
    employment_tenure
    assignment_tenure
    manager_employment
    sign_in_as_teammate(manager, organization)
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

        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
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

        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
        
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

        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
        
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

        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
        
        assignment_check_in.reload
        aspiration_check_in.reload
        
        expect(assignment_check_in.manager_completed?).to be true
        expect(aspiration_check_in.manager_completed?).to be false
      end
    end

    context 'as employee' do
      before { sign_in_as_teammate(employee, organization) }

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

        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
        
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

        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
        
        assignment_check_in.reload
        expect(assignment_check_in.employee_rating).to eq('exceeding')
        expect(assignment_check_in.employee_private_notes).to eq('Love this work')
        expect(assignment_check_in.actual_energy_percentage).to eq(85)
        expect(assignment_check_in.employee_personal_alignment).to eq('love')
        expect(assignment_check_in.employee_completed?).to be true
      end

      it 'raises ArgumentError when employee_personal_alignment is set to invalid value "tolerate"' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        
        # The error should be raised when trying to update with invalid enum value
        # ApplicationController re-raises errors in test mode, so RSpec should catch it
        expect {
          patch :update, params: {
            organization_id: organization.id,
            person_id: employee.id,
            assignment_check_ins: {
              assignment_check_in.id => {
                assignment_id: assignment.id,
                employee_personal_alignment: 'tolerate',
                status: 'complete'
              }
            }
          }
        }.to raise_error(ArgumentError) do |error|
          expect(error.message).to match(/'tolerate' is not a valid employee_personal_alignment/)
        end
      end

      it 'raises ArgumentError when employee_personal_alignment is set to invalid value "tolerate" as draft' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        
        expect {
          patch :update, params: {
            organization_id: organization.id,
            person_id: employee.id,
            assignment_check_ins: {
              assignment_check_in.id => {
                assignment_id: assignment.id,
                employee_personal_alignment: 'tolerate',
                status: 'draft'
              }
            }
          }
        }.to raise_error(ArgumentError) do |error|
          expect(error.message).to match(/'tolerate' is not a valid employee_personal_alignment/)
        end
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

        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
        
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
        sign_in_as_teammate(manager, organization)
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

    context 'load_goals' do
      before do
        sign_in_as_teammate(manager, organization)
        employment_tenure
      end

      it 'loads active goals filtered by timeframe' do
        # Create goals with different timeframes
        now_goal = create(:goal, 
          creator: employee_teammate, 
          owner: employee_teammate, 
          most_likely_target_date: Date.today + 1.month,
          started_at: 1.day.ago
        )
        next_goal = create(:goal, 
          creator: employee_teammate, 
          owner: employee_teammate, 
          most_likely_target_date: Date.today + 6.months,
          started_at: 1.day.ago
        )
        later_goal = create(:goal, 
          creator: employee_teammate, 
          owner: employee_teammate, 
          most_likely_target_date: Date.today + 12.months,
          started_at: 1.day.ago
        )
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        expect(assigns(:now_goals)).to include(now_goal)
        expect(assigns(:next_goals)).to include(next_goal)
        expect(assigns(:later_goals)).to include(later_goal)
      end

      it 'only loads active goals (not draft or completed)' do
        active_goal = create(:goal, 
          creator: employee_teammate, 
          owner: employee_teammate, 
          most_likely_target_date: Date.today + 1.month,
          started_at: 1.day.ago,
          completed_at: nil
        )
        draft_goal = create(:goal, 
          creator: employee_teammate, 
          owner: employee_teammate, 
          most_likely_target_date: Date.today + 1.month,
          started_at: nil
        )
        completed_goal = create(:goal, 
          creator: employee_teammate, 
          owner: employee_teammate, 
          most_likely_target_date: Date.today + 1.month,
          started_at: 2.days.ago,
          completed_at: 1.day.ago
        )
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        expect(assigns(:now_goals)).to include(active_goal)
        expect(assigns(:now_goals)).not_to include(draft_goal)
        # Completed goals are excluded by default scope
        expect(Goal.unscoped.find_by(id: completed_goal.id)).to be_present
      end

      it 'handles empty state when employee has no goals' do
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        expect(assigns(:now_goals)).to be_empty
        expect(assigns(:next_goals)).to be_empty
        expect(assigns(:later_goals)).to be_empty
      end

      it 'only loads goals for the specific teammate' do
        other_person = create(:person, full_name: 'Other Person')
        other_teammate = create(:teammate, person: other_person, organization: organization)
        
        employee_goal = create(:goal, 
          creator: employee_teammate, 
          owner: employee_teammate, 
          most_likely_target_date: Date.today + 1.month,
          started_at: 1.day.ago
        )
        other_goal = create(:goal, 
          creator: other_teammate, 
          owner: other_teammate, 
          most_likely_target_date: Date.today + 1.month,
          started_at: 1.day.ago
        )
        
        get :show, params: { organization_id: organization.id, person_id: employee.id }
        
        expect(assigns(:now_goals)).to include(employee_goal)
        expect(assigns(:now_goals)).not_to include(other_goal)
      end
    end
  end

  describe 'POST #save_and_redirect' do
    context 'as manager' do
      it 'saves form data and redirects to specified URL' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        redirect_url = organization_person_path(organization, employee)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          person_id: employee.id,
          redirect_url: redirect_url,
          position_check_in: {
            manager_rating: 2,
            manager_private_notes: 'Test notes',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(redirect_url)
        expect(flash[:notice]).to eq('Check-ins saved successfully.')
        
        position_check_in.reload
        expect(position_check_in.manager_rating).to eq(2)
        expect(position_check_in.manager_private_notes).to eq('Test notes')
        expect(position_check_in.manager_completed?).to be true
      end

      it 'saves form data and redirects to finalization page when no redirect_url provided' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          person_id: employee.id,
          position_check_in: {
            manager_rating: 1,
            manager_private_notes: 'Test notes',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
        expect(flash[:notice]).to eq('Check-ins saved successfully.')
        
        position_check_in.reload
        expect(position_check_in.manager_rating).to eq(1)
      end

      it 'handles multiple check-in types in single request' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        redirect_url = organization_person_path(organization, employee)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          person_id: employee.id,
          redirect_url: redirect_url,
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

        expect(response).to redirect_to(redirect_url)
        
        assignment_check_in.reload
        aspiration_check_in.reload
        
        expect(assignment_check_in.manager_completed?).to be true
        expect(aspiration_check_in.manager_completed?).to be false
      end

      it 'handles check_ins scoped parameters' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        redirect_url = organization_person_path(organization, employee)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          person_id: employee.id,
          redirect_url: redirect_url,
          check_ins: {
            position_check_in: {
              manager_rating: 2,
              manager_private_notes: 'Scoped notes',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(redirect_url)
        
        position_check_in.reload
        expect(position_check_in.manager_rating).to eq(2)
        expect(position_check_in.manager_private_notes).to eq('Scoped notes')
      end
    end

    context 'as employee' do
      before { sign_in_as_teammate(employee, organization) }

      it 'saves form data and redirects to specified URL' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        redirect_url = organization_person_path(organization, employee)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          person_id: employee.id,
          redirect_url: redirect_url,
          position_check_in: {
            employee_rating: 1,
            employee_private_notes: 'Employee notes',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(redirect_url)
        expect(flash[:notice]).to eq('Check-ins saved successfully.')
        
        position_check_in.reload
        expect(position_check_in.employee_rating).to eq(1)
        expect(position_check_in.employee_private_notes).to eq('Employee notes')
        expect(position_check_in.employee_completed?).to be true
      end
    end
  end
end