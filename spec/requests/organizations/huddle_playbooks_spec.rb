require 'rails_helper'

RSpec.describe "Organizations::HuddlePlaybooks", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
  end

  describe "GET /index" do
    it "returns http success" do
      get organization_huddle_playbooks_path(organization)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_organization_huddle_playbook_path(organization)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    it "returns http success" do
      post organization_huddle_playbooks_path(organization), params: { huddle_playbook: { special_session_name: "Sprint Planning" } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /edit" do
    let(:huddle_playbook) { create(:huddle_playbook, organization: organization) }

    it "returns http success" do
      get edit_organization_huddle_playbook_path(organization, huddle_playbook)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /update" do
    let(:huddle_playbook) { create(:huddle_playbook, organization: organization) }

    it "returns http success" do
      patch organization_huddle_playbook_path(organization, huddle_playbook), params: { huddle_playbook: { special_session_name: "Updated Planning" } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /destroy" do
    let(:huddle_playbook) { create(:huddle_playbook, organization: organization) }

    it "returns http success" do
      delete organization_huddle_playbook_path(organization, huddle_playbook)
      expect(response).to have_http_status(:redirect)
    end
  end
end
