require 'rails_helper'

RSpec.describe "Organizations", type: :request do
  let(:person) { create(:person) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(nil)
  end

  describe "GET /index" do
    it "returns http success" do
      get organizations_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    let(:organization) { create(:organization) }

    it "returns http success" do
      get organization_path(organization)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_organization_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    it "returns http success" do
      post organizations_path, params: { organization: { name: "Test Org", type: "Company" } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /edit" do
    let(:organization) { create(:organization) }

    it "returns http success" do
      get edit_organization_path(organization)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /update" do
    let(:organization) { create(:organization) }

    it "returns http success" do
      patch organization_path(organization), params: { organization: { name: "Updated Org" } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /destroy" do
    let(:organization) { create(:organization) }

    it "returns http success" do
      delete organization_path(organization)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "PATCH /switch" do
    let(:organization) { create(:organization) }

    it "returns http success" do
      patch switch_organization_path(organization)
      expect(response).to have_http_status(:redirect)
    end
  end
end
