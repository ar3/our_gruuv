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

      it 'rejects old manual tag format for assignment check-ins' do
        assignment_check_in = create(:assignment_check_in, teammate: employee.teammates.first, assignment: assignment, manager_rating: nil)
        
        # Check initial state
        expect(assignment_check_in.manager_rating).to be_nil
        
        # This should not update anything since we removed dual-format support
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
        expect(assignment_check_in.manager_rating).not_to eq('meeting')
        expect(assignment_check_in.manager_completed?).to be false
      end

      it 'rejects old manual tag format for aspiration check-ins' do
        aspiration_check_in = create(:aspiration_check_in, teammate: employee.teammates.first, aspiration: aspiration)
        
        # This should not update anything since we removed dual-format support
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
        expect(aspiration_check_in.manager_rating).not_to eq('exceeding')
        expect(aspiration_check_in.manager_completed?).to be false
      end

      it 'rejects old manual tag format for position check-ins' do
        position_check_in = create(:position_check_in, teammate: employee.teammates.first, employment_tenure: employment_tenure)
        
        # This should not update anything since we removed dual-format support
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
        expect(position_check_in.manager_rating).not_to eq(1)
        expect(position_check_in.manager_completed?).to be false
      end
    end
  end
end