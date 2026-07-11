# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public About and New Us pages', type: :request do
  describe 'GET /about' do
    it 'returns success when logged out' do
      get about_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('About OurGruuv')
      expect(response.body).to include(new_us_path)
    end
  end

  describe 'GET /new-us' do
    it 'returns success when logged out' do
      get new_us_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('New Us')
      expect(response.body).to include('The people')
      expect(response.body).to include('AR3')
      expect(response.body).to include('Something fun')
      expect(response.body).to include('Skills')
      expect(response.body).to include('Why New Us')
      expect(response.body).to include(about_path)
    end
  end

  describe 'GET /ar3' do
    it 'redirects to New Us' do
      get '/ar3'

      expect(response).to redirect_to('/new-us')
    end
  end
end
