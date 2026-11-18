# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public marketing pages', type: :request do
  describe 'GET /' do
    it 'returns the outcomes home when logged out' do
      get root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Continuous clarity. Unfading growth.')
      expect(response.body).to include('without the busy work')
      expect(response.body).to include('Start Free')
      expect(response.body).to include(solutions_path)
      expect(response.body).to include('Three outcomes')
      expect(response.body).to include('How it benefits each seat')
      expect(response.body).not_to include('Taste-test')
      expect(response.body).not_to include('Variant')
    end
  end

  describe 'GET /solutions' do
    it 'returns solutions by persona' do
      get solutions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Replace glorified forms with a talent growth system')
      expect(response.body).to include('Challenge')
      expect(response.body).to include('Clarity')
      expect(response.body).to include('Continuous Feedback')
      expect(response.body).to include('MAAP')
      expect(response.body).to include(og3_goals_path)
      expect(response.body).to include('OG3 Goals')
    end
  end

  describe 'GET /flow-state' do
    it 'returns flow state manifesto' do
      get flow_state_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Challenge. Clarity. Continuous Feedback.')
      expect(response.body).to include('research behind peak work')
      expect(response.body).to include('What we believe')
      expect(response.body).to include('Csikszentmihalyi')
    end
  end

  describe 'GET /og3-goals' do
    it 'returns the OG3 Progressive Outcome theory page' do
      get og3_goals_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('OG3 Progressive Outcome')
      expect(response.body).to include('Commit')
      expect(response.body).to include('Stretch')
      expect(response.body).to include('Transform')
      expect(response.body).to include('ALWAYS LEARN')
      expect(response.body).to include('on / off track')
      expect(response.body).to include('Demo confidence check')
      expect(response.body).to include('Notes / Learnings')
      expect(response.body).to include('Rocks')
      expect(response.body).to include('cross off an accomplishment as DONE')
      expect(response.body).not_to include('progressive_outcome')
      expect(response.body).not_to include('Internally we')
    end
  end

  describe 'GET /pricing' do
    it 'returns value-based pricing story' do
      get pricing_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Pay for value, not empty seats')
      expect(response.body).to include('$3')
      expect(response.body).to include('$5')
      expect(response.body).to include('$10')
      expect(response.body).to include('No minimum')
      expect(response.body).to include('active teammate')
    end
  end

  describe 'GET /start-free' do
    it 'returns the wizard outline stub' do
      get start_free_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Wizard outline')
      expect(response.body).to include('Not implemented yet')
      expect(response.body).to include('job description')
    end
  end
end
