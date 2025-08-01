require 'rails_helper'

RSpec.describe "PositionTypes", type: :request do
  describe "GET /new" do
    it "returns http success" do
      get "/position_types/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /index" do
    it "returns http success" do
      get "/position_types"
      expect(response).to have_http_status(:success)
    end
  end
end
