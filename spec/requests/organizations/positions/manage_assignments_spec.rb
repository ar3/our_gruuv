require 'rails_helper'

RSpec.describe 'Position Assignments Management', type: :request do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:department, company: company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:company_teammate, person: person, organization: company, can_manage_maap: true) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  
  let(:company_assignment) { create(:assignment, company: company, department: nil) }
  let(:department_assignment) { create(:assignment, company: company, department: department) }
  
  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/positions/:id/manage_assignments' do
    it 'loads assignments grouped by hierarchy' do
      company_assignment
      department_assignment
      
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
      assignments = assigns(:assignments)
      expect(assignments.map(&:id)).to include(company_assignment.id, department_assignment.id)
      expect(assigns(:assignments_by_org)).to be_a(Hash)
    end

    it 'requires MAAP permission' do
      teammate.update(can_manage_maap: false)
      
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'allows access with MAAP permission even without employment management permission' do
      teammate.update(can_manage_maap: true, can_manage_employment: false)
      
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
    end

    it 'pre-populates existing position assignments' do
      existing_pa = create(:position_assignment, 
        position: position, 
        assignment: company_assignment,
        min_estimated_energy: 20,
        max_estimated_energy: 40,
        assignment_type: 'required'
      )
      
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
      expect(assigns(:existing_position_assignments)[company_assignment.id]).to eq(existing_pa)
    end

    it 'returns 404 if position does not exist' do
      get manage_assignments_organization_position_path(company, 99999)
      
      expect(response).to have_http_status(:not_found)
    end

    context 'sibling positions for the Copy Position Assignments card' do
      let(:other_level) { create(:position_level, position_major_level: position_major_level) }
      let(:archived_level) { create(:position_level, position_major_level: position_major_level) }
      let(:other_title) { create(:title, company: company, position_major_level: position_major_level, external_title: 'Other Title For Spec') }
      let(:other_title_level) { create(:position_level, position_major_level: position_major_level) }
      let!(:sibling) { create(:position, title: title, position_level: other_level) }
      let!(:archived_sibling) do
        p = create(:position, title: title, position_level: archived_level)
        p.archive!
        p
      end
      let!(:position_in_other_title) { create(:position, title: other_title, position_level: other_title_level) }

      it 'assigns sibling positions in the same title (excluding self, archived, and other titles)' do
        get manage_assignments_organization_position_path(company, position)

        expect(response).to have_http_status(:success)
        expect(assigns(:sibling_positions).map(&:id)).to eq([sibling.id])
      end

      it 'assigns assignment_diffs keyed by sibling positions' do
        get manage_assignments_organization_position_path(company, position)

        diffs = assigns(:assignment_diffs)
        expect(diffs).to have_key(sibling)
        expect(diffs[sibling]).to be_a(PositionAssignments::Diff::Result)
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/positions/:id/update_assignments' do
    it 'creates PositionAssignment when max_estimated_energy > 0' do
      expect do
        patch update_assignments_organization_position_path(company, position), params: {
          position_assignments: {
            company_assignment.id => {
              min_estimated_energy: '20',
              max_estimated_energy: '40',
              assignment_type: 'required'
            }
          }
        }
      end.to change { position.reload.versions.count }.by(1)

      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      expect(flash[:notice]).to be_present

      version = position.versions.last
      expect(version.event).to eq('update')
      cs = version.changeset
      changed = cs.keys.map(&:to_s)
      expect(changed).to include('semantic_version', 'assignments_audit_snapshot')
      snapshot_pair = cs['assignments_audit_snapshot'] || cs[:assignments_audit_snapshot]
      expect(snapshot_pair&.last.to_s).to include(company_assignment.title)

      pa = PositionAssignment.find_by(position: position, assignment: company_assignment)
      expect(pa).to be_present
      expect(pa.min_estimated_energy).to eq(20)
      expect(pa.max_estimated_energy).to eq(40)
      expect(pa.anticipated_energy_percentage).to eq(30)
      expect(pa.assignment_type).to eq('required')
    end

    it 'updates existing PositionAssignment' do
      existing_pa = create(:position_assignment,
        position: position,
        assignment: company_assignment,
        min_estimated_energy: 10,
        max_estimated_energy: 20,
        assignment_type: 'suggested'
      )
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            min_estimated_energy: '25',
            max_estimated_energy: '50',
            assignment_type: 'required'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      
      existing_pa.reload
      expect(existing_pa.min_estimated_energy).to eq(25)
      expect(existing_pa.max_estimated_energy).to eq(50)
      expect(existing_pa.anticipated_energy_percentage).to eq(38)
      expect(existing_pa.assignment_type).to eq('required')
    end

    it 'destroys PositionAssignment when max_estimated_energy is 0' do
      existing_pa = create(:position_assignment,
        position: position,
        assignment: company_assignment,
        max_estimated_energy: 30
      )
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            max_estimated_energy: '0'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      expect(PositionAssignment.find_by(id: existing_pa.id)).to be_nil
    end

    it 'destroys PositionAssignment when not in params' do
      existing_pa1 = create(:position_assignment, position: position, assignment: company_assignment)
      existing_pa2 = create(:position_assignment, position: position, assignment: department_assignment)
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            max_estimated_energy: '50'
          }
        }
      }
      
      expect(PositionAssignment.find_by(id: existing_pa1.id)).to be_present
      expect(PositionAssignment.find_by(id: existing_pa2.id)).to be_nil
    end

    it 'handles multiple assignments in single request' do
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            min_estimated_energy: '10',
            max_estimated_energy: '30',
            assignment_type: 'required'
          },
          department_assignment.id => {
            min_estimated_energy: '20',
            max_estimated_energy: '40',
            assignment_type: 'suggested'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      
      pa1 = PositionAssignment.find_by(position: position, assignment: company_assignment)
      pa2 = PositionAssignment.find_by(position: position, assignment: department_assignment)
      
      expect(pa1).to be_present
      expect(pa2).to be_present
      expect(pa1.assignment_type).to eq('required')
      expect(pa2.assignment_type).to eq('suggested')
    end

    it 'validates min <= max' do
      expect do
        patch update_assignments_organization_position_path(company, position), params: {
          position_assignments: {
            company_assignment.id => {
              min_estimated_energy: '50',
              max_estimated_energy: '30',
              assignment_type: 'required'
            }
          }
        }
      end.not_to change { position.reload.versions.count }

      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      expect(flash[:alert]).to be_present
      expect(flash[:alert]).to include('minimum energy')
    end

    it 'requires MAAP permission' do
      teammate.update(can_manage_maap: false)
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {}
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end

    it 'allows access with MAAP permission even without employment management permission' do
      teammate.update(can_manage_maap: true, can_manage_employment: false)
      
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            max_estimated_energy: '50'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
    end

    it 'handles nil values for optional fields' do
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            min_estimated_energy: '',
            max_estimated_energy: '50',
            assignment_type: 'required'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      
      pa = PositionAssignment.find_by(position: position, assignment: company_assignment)
      expect(pa.min_estimated_energy).to be_nil
      expect(pa.max_estimated_energy).to eq(50)
      expect(pa.anticipated_energy_percentage).to eq(50)
    end

    context 'with copy_action from the Copy Position Assignments card' do
      let(:other_level) { create(:position_level, position_major_level: position_major_level) }
      let!(:sibling) { create(:position, title: title, position_level: other_level) }
      let(:other_title) { create(:title, company: company, position_major_level: position_major_level, external_title: 'Other Title For Spec') }
      let(:other_title_level) { create(:position_level, position_major_level: position_major_level) }
      let!(:position_in_other_title) { create(:position, title: other_title, position_level: other_title_level) }

      it 'with "to:<sibling>" saves the page edits AND overwrites the sibling with this page configuration' do
        sibling_existing_pa = create(:position_assignment, position: sibling, assignment: department_assignment, assignment_type: 'suggested', max_estimated_energy: 50)

        patch update_assignments_organization_position_path(company, position), params: {
          position_assignments: {
            company_assignment.id => {
              min_estimated_energy: '20',
              max_estimated_energy: '40',
              assignment_type: 'required'
            }
          },
          copy_action: "to:#{sibling.id}"
        }

        expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
        expect(flash[:notice]).to be_present
        expect(flash[:notice]).to include('copied assignments')

        page_pa = PositionAssignment.find_by(position: position, assignment: company_assignment)
        expect(page_pa).to be_present
        expect(page_pa.min_estimated_energy).to eq(20)
        expect(page_pa.max_estimated_energy).to eq(40)
        expect(page_pa.assignment_type).to eq('required')

        expect(PositionAssignment.find_by(id: sibling_existing_pa.id)).to be_nil
        sibling_pas = sibling.reload.position_assignments
        expect(sibling_pas.size).to eq(1)
        expect(sibling_pas.first.assignment_id).to eq(company_assignment.id)
        expect(sibling_pas.first.min_estimated_energy).to eq(20)
        expect(sibling_pas.first.max_estimated_energy).to eq(40)
        expect(sibling_pas.first.assignment_type).to eq('required')
      end

      it 'with "from:<sibling>" saves the page edits AND overwrites the page position with the sibling configuration' do
        create(:position_assignment, position: sibling, assignment: department_assignment, assignment_type: 'suggested', max_estimated_energy: 70)

        patch update_assignments_organization_position_path(company, position), params: {
          position_assignments: {
            company_assignment.id => {
              min_estimated_energy: '20',
              max_estimated_energy: '40',
              assignment_type: 'required'
            }
          },
          copy_action: "from:#{sibling.id}"
        }

        expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
        expect(flash[:notice]).to be_present

        page_pas = position.reload.position_assignments
        expect(page_pas.map(&:assignment_id)).to eq([department_assignment.id])
        expect(page_pas.first.assignment_type).to eq('suggested')
        expect(page_pas.first.max_estimated_energy).to eq(70)
      end

      it 'bumps semantic version on both the page position (from save) and the destination of the copy' do
        create(:position_assignment, position: sibling, assignment: department_assignment, max_estimated_energy: 50)

        expect do
          patch update_assignments_organization_position_path(company, position), params: {
            position_assignments: {
              company_assignment.id => {
                max_estimated_energy: '40',
                assignment_type: 'required'
              }
            },
            copy_action: "to:#{sibling.id}"
          }
        end.to change { position.reload.versions.count }.by_at_least(1)
          .and change { sibling.reload.versions.count }.by_at_least(1)
      end

      it 'rejects copy_action when target is in a different title' do
        patch update_assignments_organization_position_path(company, position), params: {
          position_assignments: {
            company_assignment.id => {
              max_estimated_energy: '40',
              assignment_type: 'required'
            }
          },
          copy_action: "to:#{position_in_other_title.id}"
        }

        expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
        expect(flash[:alert]).to include('sibling position')
        expect(position_in_other_title.reload.position_assignments).to be_empty
      end

      it 'rejects copy_action with invalid format' do
        patch update_assignments_organization_position_path(company, position), params: {
          position_assignments: {
            company_assignment.id => {
              max_estimated_energy: '40',
              assignment_type: 'required'
            }
          },
          copy_action: 'bogus:abc'
        }

        expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
        expect(flash[:alert]).to include('Invalid copy action')
      end

      it 'skips copy when the page save phase fails (validation errors)' do
        sibling_pa = create(:position_assignment, position: sibling, assignment: department_assignment, max_estimated_energy: 50)

        patch update_assignments_organization_position_path(company, position), params: {
          position_assignments: {
            company_assignment.id => {
              min_estimated_energy: '60',
              max_estimated_energy: '40',
              assignment_type: 'required'
            }
          },
          copy_action: "to:#{sibling.id}"
        }

        expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to include('minimum energy')
        expect(sibling.reload.position_assignments.map(&:id)).to eq([sibling_pa.id])
      end

      it 'requires MAAP permission for copy_action' do
        teammate.update(can_manage_maap: false)

        patch update_assignments_organization_position_path(company, position), params: {
          position_assignments: {
            company_assignment.id => {
              max_estimated_energy: '40',
              assignment_type: 'required'
            }
          },
          copy_action: "to:#{sibling.id}"
        }

        expect(response).to redirect_to(root_path)
        expect(sibling.reload.position_assignments).to be_empty
      end
    end
  end

  describe 'hierarchy permission checking' do
    let(:person_with_multiple_teammates) { create(:person) }
    let!(:company_teammate) { create(:company_teammate, person: person_with_multiple_teammates, organization: company, can_manage_maap: true, can_manage_employment: false) }

    before do
      sign_in_as_teammate_for_request(person_with_multiple_teammates, company)
    end

    it 'allows access when only company teammate has MAAP permission' do
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:success)
    end

    it 'allows updating assignments when only company teammate has MAAP permission' do
      patch update_assignments_organization_position_path(company, position), params: {
        position_assignments: {
          company_assignment.id => {
            max_estimated_energy: '50'
          }
        }
      }
      
      expect(response).to redirect_to(manage_assignments_organization_position_path(company, position))
      expect(flash[:notice]).to be_present
    end

    it 'denies access when company teammate does not have MAAP permission' do
      company_teammate.update(can_manage_maap: false)
      
      get manage_assignments_organization_position_path(company, position)
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
    end
  end
end

