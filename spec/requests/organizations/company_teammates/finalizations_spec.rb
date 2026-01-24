require 'rails_helper'

RSpec.describe "Organizations::CompanyTeammates::Finalizations", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:title) { create(:title, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  
  let!(:manager_teammate) { create(:company_teammate, person: manager, organization: organization, can_manage_employment: true) }
  let!(:employee_teammate) { create(:company_teammate, person: employee, organization: organization) }
  
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      company: organization,
      manager: manager,
      position: position,
      started_at: 1.month.ago)
  end
  
  let!(:position_check_in) do
    create(:position_check_in,
      :ready_for_finalization,
      teammate: employee_teammate,
      employment_tenure: employment_tenure,
      employee_rating: 1,
      manager_rating: 2)
  end

  before do
    # Create active employment for manager
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.month.ago)
    
    # Setup authentication
    sign_in_as_teammate_for_request(manager, organization)
  end

  describe "POST /organizations/:org_id/company_teammates/:company_teammate_id/finalization" do
    context "position check-in finalization" do
      let(:finalization_params) do
        {
          position_check_in: {
            finalize: '1',
            official_rating: '2',
            shared_notes: 'Excellent performance overall'
          }
        }
      end

      it "creates snapshot with correct position rating" do
        expect {
          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: finalization_params
        }.to change(MaapSnapshot, :count).by(1)

        position_check_in.reload
        snapshot = MaapSnapshot.last

        # Verify snapshot was created
        expect(snapshot).to be_present
        expect(snapshot.employee_company_teammate).to eq(employee_teammate)
        expect(snapshot.creator_company_teammate).to eq(manager_teammate)

        # Verify snapshot's position rating matches submitted rating
        snapshot_rating = snapshot.maap_data['position']['rated_position']['official_position_rating']
        expect(snapshot_rating).to eq(2)
        expect(snapshot_rating).to eq(finalization_params[:position_check_in][:official_rating].to_i)
      end

      it "links check-in to snapshot" do
        post organization_company_teammate_finalization_path(organization, employee_teammate),
             params: finalization_params

        position_check_in.reload
        snapshot = MaapSnapshot.last

        # Verify check-in is linked to snapshot
        expect(position_check_in.maap_snapshot_id).to eq(snapshot.id)
        expect(position_check_in.maap_snapshot).to eq(snapshot)
      end

      it "snapshot rating matches check-in official_rating" do
        post organization_company_teammate_finalization_path(organization, employee_teammate),
             params: finalization_params

        position_check_in.reload
        snapshot = MaapSnapshot.last

        # Verify check-in has correct rating
        expect(position_check_in.official_rating).to eq(2)

        # Verify snapshot rating matches check-in rating
        snapshot_rating = snapshot.maap_data['position']['rated_position']['official_position_rating']
        expect(snapshot_rating).to eq(position_check_in.official_rating)
      end

      it "all three objects (check-in, tenure, snapshot) have consistent ratings" do
        post organization_company_teammate_finalization_path(organization, employee_teammate),
             params: finalization_params

        position_check_in.reload
        snapshot = MaapSnapshot.last
        closed_tenure = employee_teammate.employment_tenures.inactive.order(ended_at: :desc).first

        # Verify all have consistent rating
        expect(position_check_in.official_rating).to eq(2)
        expect(closed_tenure.official_position_rating).to eq(2)
        
        snapshot_rating = snapshot.maap_data['position']['rated_position']['official_position_rating']
        expect(snapshot_rating).to eq(2)
        
        # All should match
        expect(position_check_in.official_rating).to eq(closed_tenure.official_position_rating)
        expect(snapshot_rating).to eq(position_check_in.official_rating)
        expect(snapshot_rating).to eq(closed_tenure.official_position_rating)
      end

      it "check-in can access snapshot via association after finalization" do
        post organization_company_teammate_finalization_path(organization, employee_teammate),
             params: finalization_params

        position_check_in.reload
        snapshot = MaapSnapshot.last

        # Verify bidirectional relationship
        expect(position_check_in.maap_snapshot).to eq(snapshot)
        expect(position_check_in.maap_snapshot_id).to be_present
        expect(position_check_in.maap_snapshot.employee_company_teammate).to eq(employee_teammate)
      end
    end

    context "assignment check-in finalization" do
      let(:assignment) { create(:assignment, company: organization) }
      
      let!(:assignment_check_in) do
        create(:assignment_check_in,
          :ready_for_finalization,
          teammate: employee_teammate,
          assignment: assignment,
          employee_rating: 'meeting',
          manager_rating: 'exceeding',
          manager_completed_by_teammate: manager_teammate.reload.becomes(CompanyTeammate))
      end

      context "when no assignment tenure exists (first check-in)" do
        let(:finalization_params) do
          {
            assignment_check_ins: {
              assignment_check_in.id.to_s => {
                finalize: '1',
                official_rating: 'exceeding',
                shared_notes: 'First check-in for this assignment',
                anticipated_energy_percentage: '60'
              }
            }
          }
        end

        it "creates the first assignment tenure successfully" do
          expect {
            post organization_company_teammate_finalization_path(organization, employee_teammate),
                 params: finalization_params
          }.to change(AssignmentTenure, :count).by(1)

          new_tenure = AssignmentTenure.last
          expect(new_tenure.teammate).to be_a(Teammate)
          expect(new_tenure.teammate.id).to eq(employee_teammate.id)
          expect(new_tenure.assignment).to eq(assignment)
          expect(new_tenure.anticipated_energy_percentage).to eq(60)
          expect(new_tenure.started_at).to eq(Date.current)
          expect(new_tenure.ended_at).to be_nil
          expect(new_tenure.official_rating).to be_nil
        end

        it "finalizes the check-in correctly" do
          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: finalization_params

          assignment_check_in.reload
          expect(assignment_check_in.official_rating).to eq('exceeding')
          expect(assignment_check_in.shared_notes).to eq('First check-in for this assignment')
          expect(assignment_check_in.official_check_in_completed_at).to be_present
          expect(assignment_check_in.finalized_by_teammate_id).to eq(manager_teammate.id)
        end

        it "creates snapshot with assignment data" do
          expect {
            post organization_company_teammate_finalization_path(organization, employee_teammate),
                 params: finalization_params
          }.to change(MaapSnapshot, :count).by(1)

          snapshot = MaapSnapshot.last
          expect(snapshot.employee_company_teammate).to eq(employee_teammate)
          expect(snapshot.creator_company_teammate).to eq(manager_teammate)
          expect(snapshot.change_type).to eq('assignment_management')
        end

        it "defaults to 50 when anticipated_energy_percentage is not provided" do
          params_without_energy = {
            assignment_check_ins: {
              assignment_check_in.id.to_s => {
                finalize: '1',
                official_rating: 'exceeding',
                shared_notes: 'First check-in',
                anticipated_energy_percentage: ''
              }
            }
          }

          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: params_without_energy

          new_tenure = AssignmentTenure.last
          expect(new_tenure.anticipated_energy_percentage).to eq(50)
        end
      end

      context "when assignment tenure exists" do
        let!(:assignment_tenure) do
          create(:assignment_tenure,
            teammate: employee_teammate,
            assignment: assignment,
            anticipated_energy_percentage: 75,
            started_at: 1.month.ago)
        end

        let(:finalization_params) do
          {
            assignment_check_ins: {
              assignment_check_in.id.to_s => {
                finalize: '1',
                official_rating: 'exceeding',
                shared_notes: 'Great work',
                anticipated_energy_percentage: '80'
              }
            }
          }
        end

        it "closes existing tenure and creates new one" do
          expect {
            post organization_company_teammate_finalization_path(organization, employee_teammate),
                 params: finalization_params
          }.to change(AssignmentTenure, :count).by(1)

          assignment_tenure.reload
          expect(assignment_tenure.ended_at).to eq(Date.current)
          expect(assignment_tenure.official_rating).to eq('exceeding')

          new_tenure = AssignmentTenure.last
          expect(new_tenure.anticipated_energy_percentage).to eq(80)
          expect(new_tenure.started_at).to eq(Date.current)
          expect(new_tenure.ended_at).to be_nil
        end
      end
    end

    context "when no check-ins are finalized" do
      it "succeeds but does not create a snapshot" do
        empty_params = {}
        
        expect {
          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: empty_params
        }.not_to change { MaapSnapshot.count }
        
        expect(response).to redirect_to(audit_organization_employee_path(organization, employee_teammate))
      end

      it "succeeds when finalize flag is not set for position" do
        params_without_finalize = {
          position_check_in: {
            official_rating: '2',
            shared_notes: 'Not finalizing'
          }
        }
        
        expect {
          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: params_without_finalize
        }.not_to change { MaapSnapshot.count }
        
        expect(response).to redirect_to(audit_organization_employee_path(organization, employee_teammate))
      end

      it "succeeds when assignment_check_ins exists but finalize flag is not set" do
        assignment = create(:assignment, company: organization)
        assignment_check_in = create(:assignment_check_in,
          :ready_for_finalization,
          teammate: employee_teammate,
          assignment: assignment,
          employee_rating: 'meeting',
          manager_rating: 'exceeding',
          manager_completed_by_teammate: manager_teammate.reload.becomes(CompanyTeammate))
        
        params_without_finalize = {
          assignment_check_ins: {
            assignment_check_in.id.to_s => {
              finalize: '0',
              official_rating: 'meeting',
              shared_notes: 'Not finalizing'
            }
          }
        }
        
        expect {
          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: params_without_finalize
        }.not_to change { MaapSnapshot.count }
        
        expect(response).to redirect_to(audit_organization_employee_path(organization, employee_teammate))
      end
    end

    context "when partial finalizations occur" do
      let(:assignment) { create(:assignment, company: organization) }
      let!(:assignment_check_in) do
        create(:assignment_check_in,
          :ready_for_finalization,
          teammate: employee_teammate,
          assignment: assignment,
          employee_rating: 'meeting',
          manager_rating: 'exceeding',
          manager_completed_by_teammate: manager_teammate.reload.becomes(CompanyTeammate))
      end

      it "creates snapshot when only position is finalized" do
        position_params = {
          position_check_in: {
            finalize: '1',
            official_rating: '2',
            shared_notes: 'Finalizing position only'
          }
        }
        
        expect {
          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: position_params
        }.to change { MaapSnapshot.count }.by(1)
        
        snapshot = MaapSnapshot.last
        expect(snapshot.change_type).to eq('position_tenure')
      end

      it "creates snapshot when only assignment is finalized" do
        assignment_params = {
          assignment_check_ins: {
            assignment_check_in.id.to_s => {
              finalize: '1',
              official_rating: 'exceeding',
              shared_notes: 'Finalizing assignment only',
              anticipated_energy_percentage: '60'
            }
          }
        }
        
        expect {
          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: assignment_params
        }.to change { MaapSnapshot.count }.by(1)
        
        snapshot = MaapSnapshot.last
        expect(snapshot.change_type).to eq('assignment_management')
      end

      it "creates snapshot when position is finalized but assignment is not" do
        mixed_params = {
          position_check_in: {
            finalize: '1',
            official_rating: '2',
            shared_notes: 'Finalizing position'
          },
          assignment_check_ins: {
            assignment_check_in.id.to_s => {
              finalize: '0',
              official_rating: 'exceeding',
              shared_notes: 'Not finalizing assignment'
            }
          }
        }
        
        expect {
          post organization_company_teammate_finalization_path(organization, employee_teammate),
               params: mixed_params
        }.to change { MaapSnapshot.count }.by(1)
        
        snapshot = MaapSnapshot.last
        # When assignment_check_ins params are present, even if not finalized, it's treated as bulk
        expect(snapshot.change_type).to eq('bulk_check_in_finalization')
      end
    end
  end
end

