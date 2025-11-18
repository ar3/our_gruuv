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
        admin_teammate = admin.active_teammates.first
        post :create, params: { person_id: regular_person.id }
        
        regular_teammate = regular_person.active_teammates.first
        # impersonating_teammate_id stores the ORIGINAL user (admin) before impersonation
        expect(session[:impersonating_teammate_id]).to eq(admin_teammate.id)
        # current_company_teammate_id stores the IMPERSONATED user (regular_person)
        expect(session[:current_company_teammate_id]).to eq(regular_teammate.id)
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
    context 'when admin is impersonating' do
      before do
        # Create teammate for regular_person and set up impersonation
        admin_teammate = admin.active_teammates.first
        regular_teammate = create(:teammate, person: regular_person, organization: create(:organization, :company))
        # Set up impersonation: impersonating_teammate_id stores original user (admin)
        session[:impersonating_teammate_id] = admin_teammate.id
        # current_company_teammate_id stores impersonated user (regular_person)
        session[:current_company_teammate_id] = regular_teammate.id
      end

      it 'stops impersonation' do
        admin_teammate = admin.active_teammates.first
        delete :destroy, params: { id: 1 }
        
        # After stopping, impersonating_teammate_id should be nil
        expect(session[:impersonating_teammate_id]).to be_nil
        # After stopping, current_company_teammate_id should be restored to original user (admin)
        expect(session[:current_company_teammate_id]).to eq(admin_teammate.id)
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("Stopped impersonation")
      end
    end

    context 'when non-admin is impersonating (e.g., admin impersonated them)' do
      let(:regular_person_org) { create(:organization, :company) }
      let(:regular_person_teammate) { create(:teammate, person: regular_person, organization: regular_person_org) }
      let(:admin_teammate) { admin.active_teammates.first }

      before do
        # Set up impersonation session: impersonating_teammate_id stores original user (admin)
        session[:impersonating_teammate_id] = admin_teammate.id
        # current_company_teammate_id stores impersonated user (regular_person)
        session[:current_company_teammate_id] = regular_person_teammate.id
      end

      it 'allows anyone to stop impersonation' do
        delete :destroy, params: { id: 1 }
        
        # After stopping, impersonating_teammate_id should be nil
        expect(session[:impersonating_teammate_id]).to be_nil
        # After stopping, current_company_teammate_id should be restored to original user (admin)
        expect(session[:current_company_teammate_id]).to eq(admin_teammate.id)
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("Stopped impersonation")
      end
    end

    context 'when not impersonating' do
      it 'denies access' do
        delete :destroy, params: { id: 1 }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include("You are not currently impersonating anyone")
      end
    end
  end
end
