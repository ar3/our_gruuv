require 'rails_helper'

RSpec.describe "Organizations::HuddleInstructions", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/organizations/huddle_instructions/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/organizations/huddle_instructions/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/organizations/huddle_instructions/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/organizations/huddle_instructions/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/organizations/huddle_instructions/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/organizations/huddle_instructions/destroy"
      expect(response).to have_http_status(:success)
    end
  end

end
