require 'rails_helper'

RSpec.describe Organizations::CompanyTeammates::CheckInsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person, full_name: 'Manager Person') }
  let(:employee) { create(:person, full_name: 'Employee Person') }
  let(:title) { create(:title, company: organization, external_title: 'Software Engineer') }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level, level: '1.2') }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: 'Frontend Development') }
  let(:aspiration) { create(:aspiration, company: organization, name: 'Technical Skills') }

  let(:manager_teammate) { create(:company_teammate, person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:employment_tenure) do
    mt = CompanyTeammate.find(manager_teammate.id) # Ensure it's a CompanyTeammate instance
    create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: mt, position: position)
  end
  let(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment) }
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
        company_teammate_id: employee_teammate.id,
          position_check_in: {
            manager_rating: 2,  # Integer value for "Praising/Trusting"
            manager_private_notes: 'Outstanding work',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
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
          company_teammate_id: employee_teammate.id,
          assignment_check_ins: {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              manager_rating: 'meeting',
              manager_private_notes: 'Good progress',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        assignment_check_in.reload
        expect(assignment_check_in.manager_rating).to eq('meeting')
        expect(assignment_check_in.manager_private_notes).to eq('Good progress')
        expect(assignment_check_in.manager_completed?).to be true
      end

      it 'updates assignment check-ins even when no assignment tenure exists' do
        # Create a check-in without a tenure (matching load_or_build_assignment_check_ins behavior for required assignments)
        assignment_check_in = create(:assignment_check_in,
          teammate: employee.teammates.first,
          assignment: assignment,
          check_in_started_on: Date.current,
          actual_energy_percentage: nil
        )
        # Ensure no tenure exists
        AssignmentTenure.where(company_teammate: employee_teammate, assignment: assignment).destroy_all
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          assignment_check_ins: {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              manager_rating: 'exceeding',
              manager_private_notes: 'Excellent work without tenure',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        assignment_check_in.reload
        expect(assignment_check_in.manager_rating).to eq('exceeding')
        expect(assignment_check_in.manager_private_notes).to eq('Excellent work without tenure')
        expect(assignment_check_in.manager_completed?).to be true
      end

      it 'creates assignment check-in when updating if none exists and no tenure exists' do
        # Ensure no check-in and no tenure exist
        AssignmentCheckIn.where(company_teammate: employee_teammate, assignment: assignment).destroy_all
        AssignmentTenure.where(company_teammate: employee_teammate, assignment: assignment).destroy_all
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          assignment_check_ins: {
            'new_check_in' => {
              assignment_id: assignment.id,
              manager_rating: 'meeting',
              manager_private_notes: 'Created without tenure',
              status: 'draft'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        check_in = AssignmentCheckIn.find_by(company_teammate: employee_teammate, assignment: assignment)
        expect(check_in).to be_present
        expect(check_in.manager_rating).to eq('meeting')
        expect(check_in.manager_private_notes).to eq('Created without tenure')
        expect(check_in.manager_completed?).to be false
      end

      it 'updates aspiration check-ins with manager fields' do
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          aspiration_check_ins: {
            aspiration_check_in.id => {
              aspiration_id: aspiration.id,
              manager_rating: 'exceeding',
              manager_private_notes: 'Excellent growth',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
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
          company_teammate_id: employee_teammate.id,
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

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        assignment_check_in.reload
        aspiration_check_in.reload
        
        expect(assignment_check_in.manager_completed?).to be true
        expect(aspiration_check_in.manager_completed?).to be false
      end

      it 'when one check-in fails validation, redirects with alert and other check-ins still save' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)

        invalid_record = AspirationCheckIn.new
        invalid_record.errors.add(:base, 'Only one open aspiration check-in allowed per teammate per aspiration')
        allow_any_instance_of(AspirationCheckIn).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(invalid_record))

        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          position_check_in: {
            manager_rating: 2,
            manager_private_notes: 'Saved',
            status: 'complete'
          },
          aspiration_check_ins: {
            aspiration_check_in.id => {
              aspiration_id: aspiration.id,
              manager_rating: 'exceeding',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        expect(flash[:alert]).to include('could not be saved')
        position_check_in.reload
        expect(position_check_in.manager_rating).to eq(2)
        expect(position_check_in.manager_completed?).to be true
      end

      it 'when duplicate open aspiration check-ins exist, closes the duplicate and update succeeds' do
        aspiration_check_in1 = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        aspiration_check_in2 = AspirationCheckIn.new(
          company_teammate: aspiration_check_in1.company_teammate,
          aspiration: aspiration,
          check_in_started_on: aspiration_check_in1.check_in_started_on
        )
        aspiration_check_in2.save!(validate: false)

        expect(AspirationCheckIn.where(company_teammate: employee_teammate, aspiration: aspiration).open.count).to eq(2)

        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          aspiration_check_ins: {
            aspiration_check_in1.id => {
              aspiration_id: aspiration.id,
              manager_rating: 'exceeding',
              manager_private_notes: 'Updated',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        expect(flash[:notice]).to eq('Check-ins saved successfully.')

        aspiration_check_in1.reload
        aspiration_check_in2.reload
        expect(aspiration_check_in1.manager_rating).to eq('exceeding')
        expect(aspiration_check_in1.manager_completed?).to be true
        expect(aspiration_check_in2.official_check_in_completed_at).to be_present
        expect(AspirationCheckIn.where(company_teammate: employee_teammate, aspiration: aspiration).open.count).to eq(1)
      end

      it 'uses check_in id from params to update the correct aspiration check-in when duplicates exist' do
        aspiration_check_in_first = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        aspiration_check_in_second = AspirationCheckIn.new(
          company_teammate: aspiration_check_in_first.company_teammate,
          aspiration: aspiration,
          check_in_started_on: aspiration_check_in_first.check_in_started_on
        )
        aspiration_check_in_second.save!(validate: false)

        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          aspiration_check_ins: {
            aspiration_check_in_second.id => {
              aspiration_id: aspiration.id,
              manager_rating: 'exceeding',
              manager_private_notes: 'Second one',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        aspiration_check_in_first.reload
        aspiration_check_in_second.reload
        expect(aspiration_check_in_second.manager_rating).to eq('exceeding')
        expect(aspiration_check_in_second.manager_private_notes).to eq('Second one')
        expect(aspiration_check_in_first.manager_rating).not_to eq('exceeding')
      end
    end

    context 'as employee' do
      before { sign_in_as_teammate(employee, organization) }

      it 'updates position check-in with employee fields' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          position_check_in: {
            employee_rating: 1,  # Integer value for "Meeting"
            employee_private_notes: 'Making good progress',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        position_check_in.reload
        expect(position_check_in.employee_rating).to eq(1)
        expect(position_check_in.employee_private_notes).to eq('Making good progress')
        expect(position_check_in.employee_completed?).to be true
      end

      it 'updates assignment check-ins with employee fields' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
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

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        assignment_check_in.reload
        expect(assignment_check_in.employee_rating).to eq('exceeding')
        expect(assignment_check_in.employee_private_notes).to eq('Love this work')
        expect(assignment_check_in.actual_energy_percentage).to eq(85)
        expect(assignment_check_in.employee_personal_alignment).to eq('love')
        expect(assignment_check_in.employee_completed?).to be true
      end

      it 'updates assignment check-ins with employee fields even when no assignment tenure exists' do
        # Create a check-in without a tenure
        assignment_check_in = create(:assignment_check_in,
          teammate: employee.teammates.first,
          assignment: assignment,
          check_in_started_on: Date.current,
          actual_energy_percentage: nil
        )
        # Ensure no tenure exists
        AssignmentTenure.where(company_teammate: employee_teammate, assignment: assignment).destroy_all
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          assignment_check_ins: {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              employee_rating: 'meeting',
              employee_private_notes: 'Working on it',
              actual_energy_percentage: 75,
              employee_personal_alignment: 'like',
              status: 'draft'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        assignment_check_in.reload
        expect(assignment_check_in.employee_rating).to eq('meeting')
        expect(assignment_check_in.employee_private_notes).to eq('Working on it')
        expect(assignment_check_in.actual_energy_percentage).to eq(75)
        expect(assignment_check_in.employee_personal_alignment).to eq('like')
        expect(assignment_check_in.employee_completed?).to be false
      end

      it 'raises ArgumentError when employee_personal_alignment is set to invalid value "tolerate"' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        
        # The error should be raised when trying to update with invalid enum value
        # ApplicationController re-raises errors in test mode, so RSpec should catch it
        expect {
          patch :update, params: {
            organization_id: organization.id,
            company_teammate_id: employee_teammate.id,
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
            company_teammate_id: employee_teammate.id,
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
          company_teammate_id: employee_teammate.id,
          aspiration_check_ins: {
            aspiration_check_in.id => {
              aspiration_id: aspiration.id,
              employee_rating: 'meeting',
              employee_private_notes: 'Learning a lot',
              status: 'draft'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
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
          company_teammate_id: employee_teammate.id,
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
        manager_ct = CompanyTeammate.find(manager_teammate.id)
        position_check_in.complete_manager_side!(completed_by: manager_ct)
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
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
          company_teammate_id: employee_teammate.id,
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
          company_teammate_id: employee_teammate.id,
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
        company_teammate_id: employee_teammate.id,
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
      let(:ability_with_milestone) { create(:ability, name: 'Ability A', company: organization) }
      let(:ability_with_assignment) { create(:ability, name: 'Ability B', company: organization) }
      let(:ability_with_both) { create(:ability, name: 'Ability C', company: organization) }
      let(:ability_outside_hierarchy) { create(:ability, name: 'Outside Ability', company: create(:organization)) }
      let(:certifier) { create(:person) }

      before do
        sign_in_as_teammate(manager, organization)
        employment_tenure
      end

      it 'includes abilities where employee has milestone attainments' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        certifier_teammate = CompanyTeammate.find(certifier_teammate.id) # Ensure it's a CompanyTeammate instance
        milestone = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certifying_teammate: certifier_teammate, milestone_level: 2)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
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
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        expect(assigns(:relevant_abilities)).to be_present
        ability_data = assigns(:relevant_abilities).find { |a| a[:ability].id == ability_with_assignment.id }
        expect(ability_data).to be_present
        expect(ability_data[:milestone_attainments]).to be_empty
        expect(ability_data[:assignment_requirements]).to include(assignment_ability)
      end

      it 'includes abilities with both milestones and assignment requirements' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        certifier_teammate = CompanyTeammate.find(certifier_teammate.id) # Ensure it's a CompanyTeammate instance
        milestone = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_both, certifying_teammate: certifier_teammate, milestone_level: 1)
        assignment_with_ability = create(:assignment, company: organization, title: 'Test Assignment')
        active_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_with_ability, ended_at: nil)
        assignment_ability = create(:assignment_ability, assignment: assignment_with_ability, ability: ability_with_both, milestone_level: 3)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        expect(assigns(:relevant_abilities)).to be_present
        ability_data = assigns(:relevant_abilities).find { |a| a[:ability].id == ability_with_both.id }
        expect(ability_data).to be_present
        expect(ability_data[:milestone_attainments]).to include(milestone)
        expect(ability_data[:assignment_requirements]).to include(assignment_ability)
      end

      it 'deduplicates abilities that appear in both milestone and assignment lists' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        certifier_teammate = CompanyTeammate.find(certifier_teammate.id) # Ensure it's a CompanyTeammate instance
        milestone = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_both, certifying_teammate: certifier_teammate, milestone_level: 2)
        assignment_with_ability = create(:assignment, company: organization, title: 'Test Assignment')
        active_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_with_ability, ended_at: nil)
        assignment_ability = create(:assignment_ability, assignment: assignment_with_ability, ability: ability_with_both, milestone_level: 3)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_data_list = relevant_abilities.select { |a| a[:ability].id == ability_with_both.id }
        expect(ability_data_list.size).to eq(1)
        expect(ability_data_list.first[:milestone_attainments]).to include(milestone)
        expect(ability_data_list.first[:assignment_requirements]).to include(assignment_ability)
      end

      it 'only includes abilities from organization hierarchy' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        certifier_teammate = CompanyTeammate.find(certifier_teammate.id) # Ensure it's a CompanyTeammate instance
        milestone_outside = create(:teammate_milestone, teammate: employee_teammate, ability: ability_outside_hierarchy, certifying_teammate: certifier_teammate, milestone_level: 1)
        milestone_inside = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certifying_teammate: certifier_teammate, milestone_level: 1)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_ids = relevant_abilities.map { |a| a[:ability].id }
        expect(ability_ids).to include(ability_with_milestone.id)
        expect(ability_ids).not_to include(ability_outside_hierarchy.id)
      end

      it 'includes abilities from departments within the organization hierarchy' do
        department = create(:department, company: organization, name: 'Engineering Department')
        ability_in_department = create(:ability, name: 'Department Ability', company: organization, department: department)
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        certifier_teammate = CompanyTeammate.find(certifier_teammate.id) # Ensure it's a CompanyTeammate instance
        milestone = create(:teammate_milestone, teammate: employee_teammate, ability: ability_in_department, certifying_teammate: certifier_teammate, milestone_level: 2)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_ids = relevant_abilities.map { |a| a[:ability].id }
        expect(ability_ids).to include(ability_in_department.id)
      end

      it 'sorts abilities alphabetically by name' do
        ability_z = create(:ability, name: 'Z Ability', company: organization)
        ability_a = create(:ability, name: 'A Ability', company: organization)
        ability_m = create(:ability, name: 'M Ability', company: organization)
        
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        certifier_teammate = CompanyTeammate.find(certifier_teammate.id) # Ensure it's a CompanyTeammate instance
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_z, certifying_teammate: certifier_teammate, milestone_level: 1)
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_a, certifying_teammate: certifier_teammate, milestone_level: 1)
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_m, certifying_teammate: certifier_teammate, milestone_level: 1)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_names = relevant_abilities.map { |a| a[:ability].name }
        expect(ability_names).to eq(['A Ability', 'M Ability', 'Z Ability'])
      end

      it 'includes all milestone attainments for each ability' do
        certifier_teammate = create(:company_teammate, person: certifier, organization: organization)
        certifier_teammate = CompanyTeammate.find(certifier_teammate.id) # Ensure it's a CompanyTeammate instance
        milestone1 = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certifying_teammate: certifier_teammate, milestone_level: 1, attained_at: 6.months.ago)
        milestone2 = create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certifying_teammate: certifier_teammate, milestone_level: 3, attained_at: 1.month.ago)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
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
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        ability_data = assigns(:relevant_abilities).find { |a| a[:ability].id == ability_with_assignment.id }
        expect(ability_data[:assignment_requirements].size).to eq(2)
        expect(ability_data[:assignment_requirements]).to include(assignment_ability1, assignment_ability2)
      end

      it 'excludes abilities from inactive assignment tenures' do
        assignment = create(:assignment, company: organization, title: 'Inactive Assignment')
        inactive_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 3.months.ago, ended_at: 1.month.ago)
        assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability_with_assignment, milestone_level: 2)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        relevant_abilities = assigns(:relevant_abilities)
        ability_ids = relevant_abilities.map { |a| a[:ability].id }
        expect(ability_ids).not_to include(ability_with_assignment.id)
      end

      it 'handles empty state when employee has no milestones or active assignments' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        expect(assigns(:relevant_abilities)).to be_empty
      end
    end

    context 'load_or_build_assignment_check_ins' do
      let(:required_assignment) { create(:assignment, company: organization, title: 'Required Assignment') }
      let(:suggested_assignment) { create(:assignment, company: organization, title: 'Suggested Assignment') }
      let(:other_assignment) { create(:assignment, company: organization, title: 'Other Assignment') }

      before do
        sign_in_as_teammate(manager, organization)
        # Ensure employment_tenure is active and has the position
        employment_tenure.update!(ended_at: nil, company: organization, position: position)
        
        # Create position assignments
        create(:position_assignment, position: position, assignment: required_assignment, assignment_type: 'required')
        create(:position_assignment, position: position, assignment: suggested_assignment, assignment_type: 'suggested')
        
        # Don't create assignment_tenure for these tests - we want to test position-based loading
        AssignmentTenure.where(company_teammate: employee_teammate, assignment: [required_assignment, suggested_assignment]).destroy_all
      end

      it 'loads check-ins for required assignments' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        assignment_check_ins = assigns(:assignment_check_ins)
        expect(assignment_check_ins).to be_present
        
        required_check_in = assignment_check_ins.find { |ci| ci.assignment_id == required_assignment.id }
        
        expect(required_check_in).to be_present, "Expected check-in for required assignment #{required_assignment.id}, but found: #{assignment_check_ins.map { |ci| ci.assignment_id }}"
        expect(required_check_in.assignment).to eq(required_assignment)
      end

      it 'loads check-ins for suggested assignments' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        assignment_check_ins = assigns(:assignment_check_ins)
        expect(assignment_check_ins).to be_present
        
        suggested_check_in = assignment_check_ins.find { |ci| ci.assignment_id == suggested_assignment.id }
        
        expect(suggested_check_in).to be_present
        expect(suggested_check_in.assignment).to eq(suggested_assignment)
      end

      it 'does not load check-ins for assignments not in position' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        assignment_check_ins = assigns(:assignment_check_ins)
        other_check_in = assignment_check_ins.find { |ci| ci.assignment_id == other_assignment.id }
        
        expect(other_check_in).to be_nil
      end

      it 'creates blank check-ins for suggested assignments without tenure' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        assignment_check_ins = assigns(:assignment_check_ins)
        suggested_check_in = assignment_check_ins.find { |ci| ci.assignment_id == suggested_assignment.id }
        
        expect(suggested_check_in).to be_present
        expect(suggested_check_in.actual_energy_percentage).to be_nil
        expect(suggested_check_in.check_in_started_on).to eq(Date.current)
      end

      it 'includes both required and suggested assignments in check-ins list' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        assignment_check_ins = assigns(:assignment_check_ins)
        assignment_ids = assignment_check_ins.map(&:assignment_id)
        
        expect(assignment_ids).to include(required_assignment.id)
        expect(assignment_ids).to include(suggested_assignment.id)
      end

      it 'separates active and non-active assignment check-ins' do
        # Create an active tenure
        active_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: required_assignment, ended_at: nil)
        # Create an inactive tenure
        inactive_tenure = create(:assignment_tenure, teammate: employee_teammate, assignment: suggested_assignment, started_at: 3.months.ago, ended_at: 1.month.ago)
        
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        active_check_ins = assigns(:active_assignment_check_ins)
        non_active_check_ins = assigns(:non_active_assignment_check_ins)
        
        expect(active_check_ins).to be_present
        expect(non_active_check_ins).to be_present
        
        # Active check-ins should include the one with active tenure
        active_assignment_ids = active_check_ins.map(&:assignment_id)
        expect(active_assignment_ids).to include(required_assignment.id)
        
        # Non-active check-ins should include the one with inactive tenure
        non_active_assignment_ids = non_active_check_ins.map(&:assignment_id)
        expect(non_active_assignment_ids).to include(suggested_assignment.id)
      end

      it 'places assignments without active tenure in non-active check-ins' do
        # No tenure created for these assignments (they're position-based only)
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        active_check_ins = assigns(:active_assignment_check_ins)
        non_active_check_ins = assigns(:non_active_assignment_check_ins)
        
        # Since no active tenures exist, these should be in non-active
        non_active_assignment_ids = non_active_check_ins.map(&:assignment_id)
        expect(non_active_assignment_ids).to include(required_assignment.id)
        expect(non_active_assignment_ids).to include(suggested_assignment.id)
      end

      it 'maintains backward compatibility with @assignment_check_ins' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        assignment_check_ins = assigns(:assignment_check_ins)
        active_check_ins = assigns(:active_assignment_check_ins)
        non_active_check_ins = assigns(:non_active_assignment_check_ins)
        
        # @assignment_check_ins should be the combination of both
        expect(assignment_check_ins.length).to eq(active_check_ins.length + non_active_check_ins.length)
        expect(assignment_check_ins.map(&:id)).to match_array((active_check_ins.map(&:id) + non_active_check_ins.map(&:id)))
      end
    end

  end

  describe 'POST #save_and_redirect' do
    context 'as manager' do
      it 'saves form data and redirects to specified URL' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        redirect_url = organization_company_teammate_path(organization, employee_teammate)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
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
          company_teammate_id: employee_teammate.id,
          position_check_in: {
            manager_rating: 1,
            manager_private_notes: 'Test notes',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        expect(flash[:notice]).to eq('Check-ins saved successfully.')
        
        position_check_in.reload
        expect(position_check_in.manager_rating).to eq(1)
      end

      it 'handles multiple check-in types in single request' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        redirect_url = organization_company_teammate_path(organization, employee_teammate)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
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
        redirect_url = organization_company_teammate_path(organization, employee_teammate)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
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
        redirect_url = organization_company_teammate_path(organization, employee_teammate)
        
        post :save_and_redirect, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
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


    context 'when check-in has been finalized' do
      let(:finalized_by_teammate) { manager_teammate.reload.becomes(CompanyTeammate) }
      let!(:finalized_check_in) do
        create(:position_check_in,
          :closed,
          teammate: employee_teammate,
          employment_tenure: employment_tenure,
          employee_rating: 1,
          manager_rating: 2,
          official_rating: 2,
          shared_notes: 'Great work overall',
          finalized_by_teammate: finalized_by_teammate
        )
      end

      context 'as manager' do
        before do
          sign_in_as_teammate(manager, organization)
        end

        it 'shows a blank/new check-in (not the finalized one)' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          position_check_in = assigns(:position_check_in)
          
          expect(position_check_in).to be_present
          expect(position_check_in).not_to eq(finalized_check_in)
          expect(position_check_in.open?).to be true
          expect(position_check_in.officially_completed?).to be false
          expect(position_check_in.employee_rating).to be_nil
          expect(position_check_in.manager_rating).to be_nil
        end

        it 'allows access to finalized check-in via latest_finalized_for for hover popover' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          latest_finalized = PositionCheckIn.latest_finalized_for(employee_teammate)
          
          expect(latest_finalized).to eq(finalized_check_in)
          expect(latest_finalized.official_rating).to eq(2)
          expect(latest_finalized.shared_notes).to eq('Great work overall')
          expect(latest_finalized.finalized_by_teammate).to eq(finalized_by_teammate)
        end
      end

      context 'as employee' do
        before do
          sign_in_as_teammate(employee, organization)
        end

        it 'shows a blank/new check-in (not the finalized one)' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          position_check_in = assigns(:position_check_in)
          
          expect(position_check_in).to be_present
          expect(position_check_in).not_to eq(finalized_check_in)
          expect(position_check_in.open?).to be true
          expect(position_check_in.officially_completed?).to be false
          expect(position_check_in.employee_rating).to be_nil
          expect(position_check_in.manager_rating).to be_nil
        end

        it 'allows access to finalized check-in via latest_finalized_for for hover popover' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          latest_finalized = PositionCheckIn.latest_finalized_for(employee_teammate)
          
          expect(latest_finalized).to eq(finalized_check_in)
          expect(latest_finalized.official_rating).to eq(2)
          expect(latest_finalized.shared_notes).to eq('Great work overall')
        end
      end
    end
  end

  describe 'GET #show' do
    context 'as non-direct-manager viewer (should behave as manager)' do
      let(:other_teammate) { create(:person, full_name: 'Other Teammate') }
      let(:other_teammate_ct) { create(:company_teammate, person: other_teammate, organization: organization) }
      let(:other_employment) do
        other_teammate_ct.update!(first_employed_at: 1.year.ago)
        create(:employment_tenure, teammate: other_teammate_ct, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
      end

      before do
        other_employment
        # Make other_teammate_ct the manager of manager_teammate so they're in the hierarchy above the employee
        manager_teammate.employment_tenures.where(company: organization).update_all(manager_teammate_id: other_teammate_ct.id)
        sign_in_as_teammate(other_teammate, organization)
      end

      it 'sets view_mode to :manager (not :readonly)' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        expect(assigns(:view_mode)).to eq(:manager)
        expect(assigns(:view_mode)).not_to eq(:readonly)
      end

      it 'allows viewing check-ins' do
        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        expect(response).to be_successful
        expect(assigns(:position_check_in)).to be_present
      end
    end
  end

  describe 'PATCH #update' do
    context 'as non-direct-manager viewer (should behave as manager)' do
      let(:other_teammate) { create(:person, full_name: 'Other Teammate') }
      let(:other_teammate_ct) { create(:company_teammate, person: other_teammate, organization: organization) }
      let(:other_employment) do
        other_teammate_ct.update!(first_employed_at: 1.year.ago)
        create(:employment_tenure, teammate: other_teammate_ct, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
      end

      before do
        other_employment
        sign_in_as_teammate(other_teammate, organization)
      end

      it 'updates position check-in with manager fields' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          position_check_in: {
            manager_rating: 2,
            manager_private_notes: 'Outstanding work from non-direct-manager',
            status: 'complete'
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        expect(flash[:notice]).to eq('Check-ins saved successfully.')
        
        position_check_in.reload
        expect(position_check_in.manager_rating).to eq(2)
        expect(position_check_in.manager_private_notes).to eq('Outstanding work from non-direct-manager')
        expect(position_check_in.manager_completed?).to be true
        expect(position_check_in.manager_completed_by_teammate).to eq(other_teammate_ct)
      end

      it 'updates assignment check-ins with manager fields' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment)
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          assignment_check_ins: {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              manager_rating: 'meeting',
              manager_private_notes: 'Good progress from non-direct-manager',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        assignment_check_in.reload
        expect(assignment_check_in.manager_rating).to eq('meeting')
        expect(assignment_check_in.manager_private_notes).to eq('Good progress from non-direct-manager')
        expect(assignment_check_in.manager_completed?).to be true
        expect(assignment_check_in.manager_completed_by_teammate).to eq(other_teammate_ct)
      end

      it 'updates aspiration check-ins with manager fields' do
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          aspiration_check_ins: {
            aspiration_check_in.id => {
              aspiration_id: aspiration.id,
              manager_rating: 'exceeding',
              manager_private_notes: 'Excellent growth from non-direct-manager',
              status: 'complete'
            }
          }
        }

        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        
        aspiration_check_in.reload
        expect(aspiration_check_in.manager_rating).to eq('exceeding')
        expect(aspiration_check_in.manager_private_notes).to eq('Excellent growth from non-direct-manager')
        expect(aspiration_check_in.manager_completed?).to be true
        expect(aspiration_check_in.manager_completed_by_teammate).to eq(other_teammate_ct)
      end

      it 'does not allow updating employee fields' do
        # Create check-in with employee fields explicitly set to nil to test that they don't get updated
        assignment_check_in = create(:assignment_check_in, 
          teammate: employee.teammates.first, 
          assignment: assignment,
          employee_rating: nil,
          employee_private_notes: nil
        )
        
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          assignment_check_ins: {
            assignment_check_in.id => {
              assignment_id: assignment.id,
              employee_rating: 'exceeding',
              employee_private_notes: 'Should not be updated',
              manager_rating: 'meeting',
              manager_private_notes: 'This should work',
              status: 'complete'
            }
          }
        }

        assignment_check_in.reload
        # Employee fields should not be updated (not permitted when view_mode is :manager)
        expect(assignment_check_in.employee_rating).to be_nil
        expect(assignment_check_in.employee_private_notes).to be_nil
        # Manager fields should be updated
        expect(assignment_check_in.manager_rating).to eq('meeting')
        expect(assignment_check_in.manager_private_notes).to eq('This should work')
      end
    end
  end
end