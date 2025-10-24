require 'rails_helper'

RSpec.describe Organizations::SearchController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person, current_organization: organization) }

  before do
    session[:current_person_id] = person.id
  end

  describe 'GET #show' do
    context 'with search query' do
      it 'assigns @query and @results' do
        get :show, params: { organization_id: organization.id, q: 'test' }
        
        expect(assigns(:query)).to eq('test')
        expect(assigns(:results)).to be_present
        expect(assigns(:organization).id).to eq(organization.id)
      end
    end

    context 'without search query' do
      it 'assigns empty results' do
        get :show, params: { organization_id: organization.id }
        
        expect(assigns(:query)).to eq('')
        expect(assigns(:results)[:total_count]).to eq(0)
        expect(assigns(:organization).id).to eq(organization.id)
      end
    end

    it 'renders the show template' do
      get :show, params: { organization_id: organization.id }
      expect(response).to render_template(:show)
    end
  end
end
