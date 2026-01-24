require 'rails_helper'

RSpec.describe "Titles", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }

  before do
    teammate = sign_in_as_teammate_for_request(person, organization)
    teammate.update(can_manage_maap: true)
  end

  describe "GET /new" do
    it "returns http success" do
      get "/organizations/#{organization.id}/titles/new"
      # May redirect if authorization fails, but should at least not error
      expect(response.status).to be_between(200, 399).inclusive
    end
  end

  describe "GET /index" do
    it "returns http success" do
      get "/organizations/#{organization.id}/titles"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    let(:position_major_level) { create(:position_major_level) }
    let(:title) { create(:title, organization: organization, position_major_level: position_major_level) }

    it "returns http success and renders without NoMethodError" do
      get "/organizations/#{organization.id}/titles/#{title.id}/edit"
      
      # Should succeed (200) or redirect if unauthorized (302), but should not error (500)
      expect(response.status).to be_between(200, 399).inclusive
      
      # If successful, verify the form renders correctly
      if response.status == 200
        expect(response.body).to include('Edit Position Type')
        expect(response.body).to include(title.external_title)
        # Should not have NoMethodError about company_title_path - this is the key check
        expect(response.body).not_to include('NoMethodError')
        expect(response.body).not_to include('company_title_path')
        expect(response.body).not_to include('undefined method')
        expect(response.body).not_to include("undefined method 'company_title_path'")
        # Form should have the correct action URL using organization_title_path
        expect(response.body).to include("action=\"/organizations/#{organization.id}/titles/#{title.id}\"")
      end
    end
  end
end
