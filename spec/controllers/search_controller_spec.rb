require 'rails_helper'

RSpec.describe SearchController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person, current_organization: organization) }

  before do
    session[:current_person_id] = person.id
  end

  describe 'GET #index' do
    context 'with search query' do
      it 'assigns @query and @results' do
        get :index, params: { q: 'test' }
        
        expect(assigns(:query)).to eq('test')
        expect(assigns(:results)).to be_present
        expect(assigns(:current_organization).id).to eq(organization.id)
      end
    end

    context 'without search query' do
      it 'assigns empty results' do
        get :index
        
        expect(assigns(:query)).to eq('')
        expect(assigns(:results)[:total_count]).to eq(0)
        expect(assigns(:current_organization).id).to eq(organization.id)
      end
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end
  end
end
