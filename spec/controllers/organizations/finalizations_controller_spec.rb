require 'rails_helper'

RSpec.describe Organizations::FinalizationsController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }
  
  # Create teammates first, before they're used in let! blocks
  let!(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let!(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  
  let!(:assignment_tenure) do
    create(:assignment_tenure,
           teammate: employee_teammate,
           assignment: assignment,
           anticipated_energy_percentage: 50,
           started_at: 1.month.ago)
  end
  
  let!(:assignment_check_in) do
    create(:assignment_check_in,
           teammate: employee_teammate,
           assignment: assignment,
           employee_rating: 'meeting',
           manager_rating: 'exceeding',
           employee_completed_at: 1.day.ago,
           manager_completed_at: 1.day.ago)
  end

  before do
    # Set up employment relationship for authorization
    manager_teammate.update!(first_employed_at: 1.year.ago)
    # Create active employment tenure for manager (required for authorization)
    create(:employment_tenure,
           teammate: manager_teammate,
           company: organization,
           started_at: 1.year.ago,
           ended_at: nil)
    create(:employment_tenure,
           teammate: employee_teammate,
           company: organization,
           manager: manager,
           started_at: 1.month.ago)
    
    # Set up authentication using helper
    sign_in_as_teammate(manager, organization)
  end

  describe 'GET #show' do
    it 'loads ready assignment check-ins' do
      get :show, params: { organization_id: organization.id, person_id: employee.id }
      
      expect(response.status).to eq(200)
      expect(assigns(:ready_assignment_check_ins)).to include(assignment_check_in)
    end
    
    it 'authorizes access to finalization' do
      expect(controller).to receive(:authorize).with(employee, :view_check_ins?, hash_including(policy_class: PersonPolicy))
      
      get :show, params: { organization_id: organization.id, person_id: employee.id }
    end
  end

  describe 'POST #create' do
    let(:finalization_params) do
      {
        organization_id: organization.id,
        person_id: employee.id,
        assignment_check_ins: {
          assignment_check_in.id => {
            finalize: '1',
            official_rating: 'meeting',
            shared_notes: 'Good work'
          }
        }
      }
    end
    
    context 'when finalization succeeds' do
      it 'calls CheckInFinalizationService with assignment data' do
        service_double = double(call: Result.ok(snapshot: double, results: {}))
        # Approach 2: Capture arguments and verify separately
        captured_args = nil
        allow(CheckInFinalizationService).to receive(:new) do |*args, **kwargs|
          captured_args = { args: args, kwargs: kwargs }
          service_double
        end
        
        post :create, params: finalization_params
        
        # Verify the service was called
        expect(CheckInFinalizationService).to have_received(:new)
        # Verify arguments - compare by ID for STI types
        expect(captured_args[:kwargs][:teammate].id).to eq(employee_teammate.id)
        expect(captured_args[:kwargs][:finalized_by]).to eq(manager)
        expect(captured_args[:kwargs][:finalization_params]).to be_a(ActionController::Parameters)
        expect(captured_args[:kwargs][:finalization_params][:assignment_check_ins]).to be_present
        expect(captured_args[:kwargs][:request_info]).to be_a(Hash)
        expect(captured_args[:kwargs][:request_info][:ip_address]).to be_present
      end
      
      it 'redirects with success notice' do
        allow_any_instance_of(CheckInFinalizationService)
          .to receive(:call)
          .and_return(Result.ok(snapshot: double, results: {}))
        
        post :create, params: finalization_params
        
        expect(response).to redirect_to(audit_organization_employee_path(organization, employee))
        expect(flash[:notice]).to include('finalized successfully')
      end
    end
    
    context 'when finalization fails' do
      it 'redirects with error alert' do
        allow_any_instance_of(CheckInFinalizationService)
          .to receive(:call)
          .and_return(Result.err('Finalization failed'))
        
        post :create, params: finalization_params
        
        expect(response).to redirect_to(organization_person_finalization_path(organization, employee))
        expect(flash[:alert]).to include('Failed to finalize')
      end
    end
    
    context 'when authorization fails' do
      before do
        # Employee trying to finalize (should not have permission)
        employee_teammate # Ensure employee teammate exists
        sign_in_as_teammate(employee, organization)
        allow_any_instance_of(Organizations::FinalizationsController).to receive(:authorize_finalization).and_raise(Pundit::NotAuthorizedError)
      end
      
      it 'handles authorization failure' do
        post :create, params: finalization_params
        
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("don't have permission")
      end
    end
  end

  describe 'finalization_params' do
    it 'permits assignment check-in fields with individual finalize flags' do
      params = ActionController::Parameters.new(
        assignment_check_ins: {
          '1' => {
            finalize: '1',
            official_rating: 'meeting',
            shared_notes: 'Notes'
          }
        }
      )
      
      controller.params = params
      permitted = controller.send(:finalization_params)
      
      expect(permitted[:assignment_check_ins]).to be_present
      expect(permitted[:assignment_check_ins]['1'][:finalize]).to eq('1')
      expect(permitted[:assignment_check_ins]['1'][:official_rating]).to eq('meeting')
      expect(permitted[:assignment_check_ins]['1'][:shared_notes]).to eq('Notes')
    end
    
    it 'permits position check-in fields with individual finalize flags' do
      params = ActionController::Parameters.new(
        position_check_in: {
          finalize: '1',
          official_rating: '1',  # Comes in as string from form
          shared_notes: 'Position notes'
        }
      )
      
      controller.params = params
      permitted = controller.send(:finalization_params)
      
      expect(permitted[:position_check_in]).to be_present
      expect(permitted[:position_check_in][:finalize]).to eq('1')
      expect(permitted[:position_check_in][:official_rating]).to eq('1')
      expect(permitted[:position_check_in][:shared_notes]).to eq('Position notes')
    end
    
    it 'permits aspiration check-in fields with individual finalize flags' do
      params = ActionController::Parameters.new(
        aspiration_check_ins: {
          '1' => {
            finalize: '1',
            official_rating: 'meeting',
            shared_notes: 'Aspiration notes'
          }
        }
      )
      
      controller.params = params
      permitted = controller.send(:finalization_params)
      
      expect(permitted[:aspiration_check_ins]).to be_present
      expect(permitted[:aspiration_check_ins]['1'][:finalize]).to eq('1')
      expect(permitted[:aspiration_check_ins]['1'][:official_rating]).to eq('meeting')
      expect(permitted[:aspiration_check_ins]['1'][:shared_notes]).to eq('Aspiration notes')
    end
  end
end