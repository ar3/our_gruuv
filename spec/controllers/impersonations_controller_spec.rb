require 'rails_helper'

RSpec.describe ImpersonationsController, type: :controller do
  let(:admin) { create(:person, :admin) }
  let(:regular_person) { create(:person) }
  let(:other_admin) { create(:person, :admin) }

  before do
    session[:current_person_id] = admin.id
  end

  describe 'POST #create' do
    context 'when admin tries to impersonate a regular person' do
      it 'starts impersonation' do
        post :create, params: { person_id: regular_person.id }
        
        expect(session[:impersonating_person_id]).to eq(regular_person.id)
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("Now impersonating")
      end
    end

    context 'when admin tries to impersonate another admin' do
      it 'does not start impersonation' do
        post :create, params: { person_id: other_admin.id }
        
        expect(session[:impersonating_person_id]).to be_nil
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include("Unable to impersonate")
      end
    end

    context 'when non-admin tries to impersonate' do
      before do
        session[:current_person_id] = regular_person.id
      end

      it 'denies access' do
        post :create, params: { person_id: regular_person.id }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include("Only administrators can impersonate users")
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      session[:impersonating_person_id] = regular_person.id
    end

    it 'stops impersonation' do
      delete :destroy, params: { id: 1 }
      
      expect(session[:impersonating_person_id]).to be_nil
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to include("Stopped impersonation")
    end
  end
end
