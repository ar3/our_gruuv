require 'rails_helper'

RSpec.describe Organizations::FinalizationsController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  
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
    create(:employment_tenure,
           teammate: employee_teammate,
           company: organization,
           manager: manager,
           started_at: 1.month.ago)
    
    # Set current organization for manager
    allow(manager).to receive(:current_organization).and_return(organization)
    
    # Mock authentication at ApplicationController level
    allow_any_instance_of(ApplicationController).to receive(:authenticate_person!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
  end

  describe 'GET #show' do
    it 'loads ready assignment check-ins' do
      get :show, params: { organization_id: organization.id, person_id: employee.id }
      
      expect(response.status).to eq(200)
      expect(assigns(:ready_assignment_check_ins)).to include(assignment_check_in)
    end
    
    it 'authorizes access to finalization' do
      expect(controller).to receive(:authorize).with(employee, :view_check_ins?)
      
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
        expect(CheckInFinalizationService).to receive(:new).with(
          teammate: employee_teammate,
          finalization_params: hash_including(:assignment_check_ins),
          finalized_by: manager,
          request_info: hash_including(:ip_address)
        ).and_return(double(call: Result.ok(snapshot: double, results: {})))
        
        post :create, params: finalization_params
      end
      
      it 'redirects with success notice' do
        allow_any_instance_of(CheckInFinalizationService)
          .to receive(:call)
          .and_return(Result.ok(snapshot: double, results: {}))
        
        post :create, params: finalization_params
        
        expect(response).to redirect_to(organization_person_check_ins_path(organization, employee))
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
        allow_any_instance_of(Organizations::FinalizationsController).to receive(:current_person).and_return(employee) # Employee trying to finalize
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