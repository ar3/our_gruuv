require 'rails_helper'

RSpec.describe "Positions", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/positions"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/positions/new"
      expect(response).to have_http_status(:success)
    end
  end
end
