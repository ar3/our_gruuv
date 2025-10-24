require_relative '../../spec_helper'

RSpec.describe Enm::HomeController, type: :controller do
  describe 'GET #index' do
    it 'returns success' do
      get :index
      expect(response).to have_http_status(:success)
    end
    
    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end
  end
end




