require 'rails_helper'

RSpec.describe "Organizations::CompanyTeammates::Finalizations", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  
  let!(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  
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
        expect(snapshot.employee).to eq(employee)
        expect(snapshot.created_by).to eq(manager)

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
        expect(position_check_in.maap_snapshot.employee).to eq(employee)
      end
    end
  end
end

