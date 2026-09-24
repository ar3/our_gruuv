# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Post-login return_to", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:protected_path) { organization_goals_path(organization) }

  describe "unauthenticated visit to a protected page" do
    it "stores the path and redirects to login" do
      get protected_path

      expect(response).to redirect_to(login_path)
      expect(session[:return_to]).to eq(protected_path)
      expect(flash[:alert]).to include("log in")
    end

    it "stores the GET path for a non-GET request (does not replay the POST)" do
      post protected_path, params: { goal: { title: "Nope" } }

      expect(response).to redirect_to(login_path)
      expect(session[:return_to]).to eq(protected_path)
    end

    it "preserves query string on GET" do
      get protected_path, params: { owner_id: "CompanyTeammate_#{teammate.id}" }

      expect(response).to redirect_to(login_path)
      expect(session[:return_to]).to eq("#{protected_path}?owner_id=CompanyTeammate_#{teammate.id}")
    end
  end

  describe "GET /login when already logged in" do
    it "sends the visitor to the stored return_to path" do
      get protected_path
      expect(session[:return_to]).to eq(protected_path)

      sign_in_as_teammate_for_request(person, organization)
      get login_path

      expect(response).to redirect_to(protected_path)
      expect(session[:return_to]).to be_nil
    end

    it "falls back to preferred start page when return_to is absent" do
      sign_in_as_teammate_for_request(person, organization)
      get login_path

      expect(response).to redirect_to(organization_og_academy_path(organization))
    end
  end
end

RSpec.describe AuthController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    session[:current_company_teammate_id] = teammate.id
  end

  describe "GET #login with unsafe return_to" do
    it "ignores absolute URLs (open redirect protection)" do
      session[:return_to] = "https://evil.example/phish"
      get :login
      expect(response).to redirect_to(organization_og_academy_path(organization))
    end

    it "ignores protocol-relative URLs" do
      session[:return_to] = "//evil.example/phish"
      get :login
      expect(response).to redirect_to(organization_og_academy_path(organization))
    end

    it "honors a safe relative path" do
      session[:return_to] = organization_goals_path(organization)
      get :login
      expect(response).to redirect_to(organization_goals_path(organization))
    end
  end
end
