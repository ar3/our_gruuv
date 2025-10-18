require 'rails_helper'

RSpec.describe Organizations::AssignmentTenuresController, type: :request do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:person_teammate) { create(:teammate, person: person, organization: company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:employment_tenure) { create(:employment_tenure, teammate: person_teammate, company: company, position: position, started_at: 1.year.ago) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    # Create employment tenure so the person has a current position
    employment_tenure
  end

  describe "GET /organizations/:organization_id/assignment_tenures/:id" do
    it "returns http success" do
      get organization_person_check_ins_path(company, person)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /organizations/:organization_id/assignment_tenures/:id/choose_assignments" do
    it "returns http success" do
      get organization_assignments_path(company)
      expect(response).to have_http_status(:success)
    end
  end
end
