require 'rails_helper'

RSpec.describe Organizations::CompanyTeammates::FinalizationsController, type: :controller do
  let(:organization) { create(:organization) }
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
    manager_ct = CompanyTeammate.find(manager_teammate.id) # Ensure it's a CompanyTeammate instance
    create(:assignment_check_in,
           teammate: employee_teammate,
           assignment: assignment,
           employee_rating: 'meeting',
           manager_rating: 'exceeding',
           employee_completed_at: 1.day.ago,
           manager_completed_at: 1.day.ago,
           manager_completed_by_teammate: manager_ct)
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
      get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
      
      expect(response.status).to eq(200)
      expect(assigns(:ready_assignment_check_ins)).to include(assignment_check_in)
    end

    it 'sorts ready assignment check-ins by active tenure percentage then by assignment title' do
      assignment_b = create(:assignment, company: organization, title: 'Alpha Assignment')
      assignment_c = create(:assignment, company: organization, title: 'Beta Assignment')
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_b, anticipated_energy_percentage: 25, started_at: 1.month.ago)
      create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_c, anticipated_energy_percentage: 75, started_at: 1.month.ago)
      manager_ct = CompanyTeammate.find(manager_teammate.id)
      check_in_b = create(:assignment_check_in, teammate: employee_teammate, assignment: assignment_b, employee_rating: 'meeting', manager_rating: 'exceeding', employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_ct)
      check_in_c = create(:assignment_check_in, teammate: employee_teammate, assignment: assignment_c, employee_rating: 'meeting', manager_rating: 'exceeding', employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago, manager_completed_by_teammate: manager_ct)
      # assignment (50%) should come after assignment_c (75%) and before assignment_b (25%) by percentage; then alpha by title
      get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
      ready = assigns(:ready_assignment_check_ins)
      titles = ready.map { |ci| ci.assignment.title }
      # Order by percentage desc then title: 75% Beta, 50% Test, 25% Alpha
      expect(titles).to eq(['Beta Assignment', assignment.title, 'Alpha Assignment'])
    end

    it 'sorts ready aspiration check-ins by aspiration name' do
      aspiration_z = create(:aspiration, company: organization, name: 'Zebra')
      aspiration_a = create(:aspiration, company: organization, name: 'Alpha')
      manager_ct = CompanyTeammate.find(manager_teammate.id)
      create(:aspiration_check_in, :ready_for_finalization, teammate: employee_teammate, aspiration: aspiration_z, manager_completed_by_teammate: manager_ct)
      create(:aspiration_check_in, :ready_for_finalization, teammate: employee_teammate, aspiration: aspiration_a, manager_completed_by_teammate: manager_ct)
      get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
      ready = assigns(:ready_aspiration_check_ins)
      names = ready.map { |ci| ci.aspiration.name }
      expect(names).to eq(names.sort)
    end
    
    it 'authorizes access to finalization' do
      # Authorization is tested via the before_action and policy specs
      get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
      expect(response).to have_http_status(:success)
    end

    context 'position check-ins' do
      let(:title) { create(:title, company: organization) }
      let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
      let(:position) { create(:position, title: title, position_level: position_level) }
      let(:employment_tenure) do
        # Use the existing employment_tenure from the before block, or find/create one
        EmploymentTenure.find_by(company_teammate: employee_teammate, company: organization) ||
          create(:employment_tenure,
            teammate: employee_teammate,
            company: organization,
            manager: manager,
            position: position,
            started_at: 1.month.ago)
      end

      context 'when position check-in is ready for finalization' do
        let!(:ready_position_check_in) do
          manager_ct = CompanyTeammate.find(manager_teammate.id) # Ensure it's a CompanyTeammate instance
          create(:position_check_in,
            teammate: employee_teammate,
            employment_tenure: employment_tenure,
            employee_rating: 1,
            manager_rating: 2,
            employee_completed_at: 1.day.ago,
            manager_completed_at: 1.day.ago,
            manager_completed_by_teammate: manager_ct)
        end

        it 'loads ready position check-in' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          expect(assigns(:ready_position_check_in)).to eq(ready_position_check_in)
          expect(assigns(:ready_position_check_in).officially_completed?).to be false
        end
      end

      context 'when position check-in has been finalized' do
        let!(:finalized_position_check_in) do
          manager_ct = CompanyTeammate.find(manager_teammate.id) # Ensure it's a CompanyTeammate instance
          create(:position_check_in,
            teammate: employee_teammate,
            employment_tenure: employment_tenure,
            employee_rating: 1,
            manager_rating: 2,
            employee_completed_at: 2.days.ago,
            manager_completed_at: 2.days.ago,
            manager_completed_by_teammate: manager_ct,
            official_check_in_completed_at: 1.day.ago,
            official_rating: 2,
            finalized_by_teammate: manager_ct)
        end

        it 'does NOT load finalized position check-in in ready_for_finalization' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          expect(assigns(:ready_position_check_in)).to be_nil
          expect(finalized_position_check_in.officially_completed?).to be true
        end

        it 'loads finalized position check-in separately for acknowledgment view' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          expect(assigns(:finalized_position_check_in)).to eq(finalized_position_check_in)
          expect(assigns(:finalized_position_check_in).officially_completed?).to be true
        end

        it 'does NOT include finalized check-in in incomplete_position_check_ins' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          incomplete = assigns(:incomplete_position_check_ins)
          expect(incomplete).not_to include(finalized_position_check_in)
          if incomplete.present?
            incomplete.each do |check_in|
              expect(check_in.officially_completed?).to be false
            end
          end
        end
      end

      context 'when both ready and finalized position check-ins exist' do
        let!(:finalized_position_check_in) do
          manager_ct = CompanyTeammate.find(manager_teammate.id) # Ensure it's a CompanyTeammate instance
          create(:position_check_in,
            teammate: employee_teammate,
            employment_tenure: employment_tenure,
            employee_rating: 1,
            manager_rating: 2,
            employee_completed_at: 3.days.ago,
            manager_completed_at: 3.days.ago,
            manager_completed_by_teammate: manager_ct,
            official_check_in_completed_at: 2.days.ago,
            official_rating: 2,
            finalized_by_teammate: manager_ct)
        end

        let!(:ready_position_check_in) do
          manager_ct = CompanyTeammate.find(manager_teammate.id) # Ensure it's a CompanyTeammate instance
          create(:position_check_in,
            teammate: employee_teammate,
            employment_tenure: employment_tenure,
            employee_rating: 1,
            manager_rating: 2,
            employee_completed_at: 1.day.ago,
            manager_completed_at: 1.day.ago,
            manager_completed_by_teammate: manager_ct)
        end

        it 'only loads ready check-in, not finalized one' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          expect(assigns(:ready_position_check_in)).to eq(ready_position_check_in)
          expect(assigns(:ready_position_check_in)).not_to eq(finalized_position_check_in)
          expect(assigns(:ready_position_check_in).officially_completed?).to be false
        end

        it 'loads finalized check-in separately for acknowledgment' do
          get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
          
          expect(assigns(:finalized_position_check_in)).to eq(finalized_position_check_in)
        end
      end
    end
  end

  describe 'POST #create' do
    let(:finalization_params) do
      {
        organization_id: organization.id,
        company_teammate_id: employee_teammate.id,
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
        # finalized_by is a CompanyTeammate, not a Person
        expect(captured_args[:kwargs][:finalized_by]).to be_a(CompanyTeammate)
        expect(captured_args[:kwargs][:finalized_by].person).to eq(manager)
        expect(captured_args[:kwargs][:finalization_params]).to be_a(ActionController::Parameters)
        expect(captured_args[:kwargs][:finalization_params][:assignment_check_ins]).to be_present
        expect(captured_args[:kwargs][:request_info]).to be_a(Hash)
        expect(captured_args[:kwargs][:request_info][:ip_address]).to be_present
        expect(captured_args[:kwargs][:maap_snapshot_reason]).to be_nil
      end
      
      it 'passes maap_snapshot_reason to service when provided' do
        service_double = double(call: Result.ok(snapshot: double, results: {}))
        captured_args = nil
        allow(CheckInFinalizationService).to receive(:new) do |*args, **kwargs|
          captured_args = { args: args, kwargs: kwargs }
          service_double
        end
        
        params_with_reason = finalization_params.merge(maap_snapshot_reason: 'Q4 2024 Performance Review')
        post :create, params: params_with_reason
        
        expect(captured_args[:kwargs][:maap_snapshot_reason]).to eq('Q4 2024 Performance Review')
      end
      
      it 'redirects with success notice' do
        allow_any_instance_of(CheckInFinalizationService)
          .to receive(:call)
          .and_return(Result.ok(snapshot: double, results: {}))
        
        post :create, params: finalization_params
        
        expect(response).to redirect_to(audit_organization_employee_path(organization, employee_teammate))
        expect(flash[:notice]).to include('finalized successfully')
      end
    end
    
    context 'when finalization fails' do
      it 'redirects with error alert' do
        allow_any_instance_of(CheckInFinalizationService)
          .to receive(:call)
          .and_return(Result.err('Finalization failed'))
        
        post :create, params: finalization_params
        
        expect(response).to redirect_to(organization_company_teammate_finalization_path(organization, employee_teammate))
        expect(flash[:alert]).to include('Failed to finalize')
      end
    end
    
    context 'when authorization fails' do
      before do
        # Employee trying to finalize (should not have permission)
        employee_teammate # Ensure employee teammate exists
        sign_in_as_teammate(employee, organization)
        allow_any_instance_of(Organizations::CompanyTeammates::FinalizationsController).to receive(:authorize_finalization).and_raise(Pundit::NotAuthorizedError)
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
    
    it 'permits maap_snapshot_reason parameter' do
      params = ActionController::Parameters.new(
        maap_snapshot_reason: 'Q4 2024 Performance Review'
      )
      
      controller.params = params
      permitted = controller.send(:finalization_params)
      
      expect(permitted[:maap_snapshot_reason]).to eq('Q4 2024 Performance Review')
    end
    
    it 'allows maap_snapshot_reason to be blank' do
      params = ActionController::Parameters.new(
        maap_snapshot_reason: ''
      )
      
      controller.params = params
      permitted = controller.send(:finalization_params)
      
      expect(permitted[:maap_snapshot_reason]).to eq('')
    end
  end
end