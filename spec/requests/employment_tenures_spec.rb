require 'rails_helper'

RSpec.describe "EmploymentTenures", type: :request do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:organization) { company }
  let(:position) do
    position_major_level = create(:position_major_level)
    position_type = create(:position_type, organization: company, position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, position_type: position_type, position_level: position_level)
  end
  
  # Use the teammate created by sign_in_as_teammate_for_request instead of creating a duplicate
  let(:person_teammate) do
    # The helper creates a teammate, so we need to find it or create it if it doesn't exist
    person.teammates.find_by(organization: company) || 
      create(:teammate, person: person, organization: company)
  end
  let(:teammate) { person_teammate }
  let(:employment_tenure) { create(:employment_tenure, teammate: person_teammate, company: company, position: position) }

  before do
    # Sign in and set organization
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /people/:id/employment_tenures/new" do
    it "returns http success" do
      get new_organization_company_teammate_employment_tenure_path(organization, teammate)
      # The new action shows company selection, which should render successfully
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /people/:id/employment_tenures/change" do
    it "returns http success" do
      get change_organization_company_teammate_employment_tenures_path(organization, teammate, company_id: company.id)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /people/:id/employment_tenures" do
    it "returns http success" do
      post organization_company_teammate_employment_tenures_path(organization, teammate), params: { employment_tenure: { 
        company_id: company.id, 
        position_id: position.id, 
        started_at: 1.month.ago 
      } }
      expect(response).to have_http_status(:redirect)
    end

    context "when creating a job change" do
      let!(:active_tenure) { create(:employment_tenure, teammate: person_teammate, company: company, position: position, started_at: 6.months.ago) }
      let(:new_position) do
        position_major_level = create(:position_major_level)
        position_type = create(:position_type, organization: company, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        create(:position, position_type: position_type, position_level: position_level)
      end

      it "deactivates the current active tenure and creates a new one" do
        effective_date = Date.current
        
        expect {
          post organization_company_teammate_employment_tenures_path(organization, teammate), params: { 
            employment_tenure: { 
              company_id: company.id, 
              position_id: new_position.id, 
              started_at: effective_date 
            },
            effective_date: effective_date
          }
        }.to change { EmploymentTenure.joins(:teammate).where(teammates: { person: person }).count }.by(1)

        # Check that the old tenure is now inactive
        expect(active_tenure.reload.ended_at).to eq(effective_date)
        
        # Check that the new tenure is active
        new_tenure = EmploymentTenure.joins(:teammate).where(teammates: { person: person }).order(:created_at).last
        expect(new_tenure.active?).to be true
        expect(new_tenure.started_at).to eq(effective_date)
      end

      it "shows 'no changes' message when position and manager are the same" do
        post organization_company_teammate_employment_tenures_path(organization, teammate), params: { 
          employment_tenure: { 
            company_id: company.id, 
            position_id: active_tenure.position_id, 
            manager_teammate_id: active_tenure.manager_teammate_id,
            started_at: Date.current 
          }
        }
        
        expect(response).to redirect_to(organization_company_teammate_path(company, person_teammate))
        expect(flash[:notice]).to eq('No changes were made to your employment.')
      end
    end

    context "when creating employment for a different company" do
      let(:other_company) { create(:organization, :company) }
      let(:other_company_teammate) do
        person.teammates.find_by(organization: other_company) ||
          create(:teammate, person: person, organization: other_company)
      end

      it "redirects to the teammate profile for the target company" do
        post organization_company_teammate_employment_tenures_path(organization, teammate), params: {
          employment_tenure: {
            company_id: other_company.id,
            position_id: position.id,
            started_at: 1.month.ago
          }
        }

        expect(response).to redirect_to(organization_company_teammate_path(other_company, other_company_teammate))
        expect(flash[:notice]).to eq('Employment tenure was successfully created.')
      end
    end
  end

  describe "GET /people/:id/employment_tenures/:id" do
    it "returns http success" do
      get organization_company_teammate_employment_tenure_path(organization, teammate, employment_tenure)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /people/:id/employment_tenures/:id/edit" do
    it "returns http success" do
      get edit_organization_company_teammate_employment_tenure_path(organization, teammate, employment_tenure)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /people/:id/employment_tenures/:id" do
    it "returns http success" do
      patch organization_company_teammate_employment_tenure_path(organization, teammate, employment_tenure), params: { employment_tenure: { started_at: 2.months.ago } }
      expect(response).to have_http_status(:redirect)
    end

    it "redirects to the teammate profile for the employment tenure's company" do
      patch organization_company_teammate_employment_tenure_path(organization, teammate, employment_tenure), params: { employment_tenure: { started_at: 2.months.ago } }
      
      expect(response).to redirect_to(organization_company_teammate_path(employment_tenure.company, employment_tenure.teammate))
      expect(flash[:notice]).to eq('Employment tenure was successfully updated.')
    end
  end

  describe "DELETE /people/:id/employment_tenures/:id" do
    it "returns http success" do
      delete organization_company_teammate_employment_tenure_path(organization, teammate, employment_tenure)
      expect(response).to have_http_status(:redirect)
    end

    it "redirects to the teammate profile for the employment tenure's company" do
      company = employment_tenure.company
      tenure_teammate = employment_tenure.teammate
      
      delete organization_company_teammate_employment_tenure_path(organization, teammate, employment_tenure)
      
      expect(response).to redirect_to(organization_company_teammate_path(company, tenure_teammate))
      expect(flash[:notice]).to eq('Employment tenure was successfully deleted.')
    end
  end

  describe "GET /people/:id/employment_tenures/:id/employment_summary" do
    it "returns http success" do
      get employment_summary_organization_company_teammate_employment_tenure_path(organization, teammate, employment_tenure)
      expect(response).to have_http_status(:success)
    end
  end
end
