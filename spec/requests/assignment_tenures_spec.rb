require 'rails_helper'

RSpec.describe AssignmentTenuresController, type: :request do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:employment_tenure) { create(:employment_tenure, person: person, company: company, position: position, started_at: 1.year.ago) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    # Create employment tenure so the person has a current position
    employment_tenure
  end

  describe "GET /people/:person_id/assignment_tenures" do
    it "returns http success" do
      get person_assignment_tenures_path(person)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /people/:person_id/assignment_tenures/choose_assignments" do
    it "returns http success" do
      get choose_assignments_person_assignment_tenures_path(person)
      expect(response).to have_http_status(:success)
    end
  end
end
