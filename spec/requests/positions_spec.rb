require 'rails_helper'

RSpec.describe "Positions", type: :request do
  let(:company) { create(:organization, type: 'Company') }
  let(:person) { create(:person) }
  
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
    it "returns http success" do
      get new_organization_position_path(company)
      expect(response).to have_http_status(:success)
    end
  end
end
