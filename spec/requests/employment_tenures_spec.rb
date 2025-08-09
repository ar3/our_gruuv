require 'rails_helper'

RSpec.describe "EmploymentTenures", type: :request do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:position) do
    position_major_level = create(:position_major_level)
    position_type = create(:position_type, organization: company, position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, position_type: position_type, position_level: position_level)
  end
  let(:employment_tenure) { create(:employment_tenure, person: person, company: company, position: position) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
  end

  describe "GET /index" do
    it "returns http success" do
      get employment_tenures_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get employment_tenure_path(employment_tenure)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_employment_tenure_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    it "returns http success" do
      post employment_tenures_path, params: { employment_tenure: { 
        person_id: person.id, 
        company_id: company.id, 
        position_id: position.id, 
        started_at: 1.month.ago 
      } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get edit_employment_tenure_path(employment_tenure)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /update" do
    it "returns http success" do
      patch employment_tenure_path(employment_tenure), params: { employment_tenure: { started_at: 2.months.ago } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /destroy" do
    it "returns http success" do
      delete employment_tenure_path(employment_tenure)
      expect(response).to have_http_status(:redirect)
    end
  end
end
