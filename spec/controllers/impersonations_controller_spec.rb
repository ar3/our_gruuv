require 'rails_helper'

RSpec.describe ImpersonationsController, type: :controller do
  let(:admin) { create(:person, :admin) }
  let(:regular_person) { create(:person) }
  let(:other_admin) { create(:person, :admin) }

  before do
    # Create teammates for admin and regular person
    admin_teammate = create(:teammate, person: admin, organization: create(:organization, :company))
    sign_in_as_teammate(admin, admin_teammate.organization)
  end

  describe 'POST #create' do
    context 'when admin tries to impersonate a regular person' do
      before do
        # Create teammate for regular_person so impersonation can work
        create(:teammate, person: regular_person, organization: create(:organization, :company))
      end

      it 'starts impersonation' do
        post :create, params: { person_id: regular_person.id }
        
        regular_teammate = regular_person.active_teammates.first
        expect(session[:impersonating_teammate_id]).to eq(regular_teammate.id)
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("Now impersonating")
      end
    end

    context 'when admin tries to impersonate another admin' do
      before do
        # Create teammate for other_admin so impersonation can be attempted
        create(:teammate, person: other_admin, organization: create(:organization, :company))
      end

      it 'does not start impersonation' do
        post :create, params: { person_id: other_admin.id }
        
        expect(session[:impersonating_teammate_id]).to be_nil
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include("Unable to impersonate")
      end
    end

    context 'when non-admin tries to impersonate' do
      before do
        regular_teammate = create(:teammate, person: regular_person, organization: create(:organization, :company))
        sign_in_as_teammate(regular_person, regular_teammate.organization)
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
      # Create teammate for regular_person and set up impersonation
      regular_teammate = create(:teammate, person: regular_person, organization: create(:organization, :company))
      session[:impersonating_teammate_id] = regular_teammate.id
    end

    it 'stops impersonation' do
      delete :destroy, params: { id: 1 }
      
      expect(session[:impersonating_teammate_id]).to be_nil
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to include("Stopped impersonation")
    end
  end
end
