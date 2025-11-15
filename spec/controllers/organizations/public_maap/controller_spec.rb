require 'rails_helper'

RSpec.describe Organizations::PublicMaapController, type: :controller do
  let(:company) { create(:organization, :company, name: 'Test Company') }

  describe 'GET #show' do
    it 'renders successfully without authentication' do
      get :show, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the organization' do
      get :show, params: { organization_id: company.id }
      expect(assigns(:organization).id).to eq(company.id)
      expect(assigns(:organization)).to be_a(Organization)
    end

    it 'handles id-name-parameterized format' do
      param = "#{company.id}-test-company"
      get :show, params: { organization_id: param }
      expect(assigns(:organization).id).to eq(company.id)
      expect(assigns(:organization)).to be_a(Organization)
    end

    it 'raises error for invalid organization' do
      expect {
        get :show, params: { organization_id: '999999' }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

