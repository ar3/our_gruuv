require 'rails_helper'

RSpec.describe "Auths", type: :request do
  describe "GET /google_oauth2_callback" do
    it "returns http success" do
      get "/auth/google_oauth2_callback"
      expect(response).to have_http_status(:success)
    end
  end

end
