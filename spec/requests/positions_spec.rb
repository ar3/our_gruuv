require 'rails_helper'

RSpec.describe "Positions", type: :request do
  let(:company) { create(:organization, type: 'Company') }
  let(:person) { create(:person) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  
  before do
    # Set up authentication and organization context
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(company)
  end

  describe "GET /index" do
    it "returns http success" do
      get organization_positions_path(company)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success when position_type_id is provided" do
      get new_organization_position_path(company, position_type_id: position_type.id)
      expect(response).to have_http_status(:success)
    end

    it "redirects when position_type_id is not provided" do
      get new_organization_position_path(company)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_positions_path(company))
    end
  end
end
