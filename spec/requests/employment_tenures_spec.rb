require 'rails_helper'

RSpec.describe "EmploymentTenures", type: :request do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:position) do
    position_major_level = create(:position_major_level)
    position_type = create(:position_type, organization: company, position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, position_type: position_type, position_level: position_level)
  end
  let(:employment_tenure) { create(:employment_tenure, person: person, company: company, position: position) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
  end

  describe "GET /people/:id/employment_tenures/new" do
    it "returns http success" do
      get new_person_employment_tenure_path(person)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /people/:id/employment_tenures/change" do
    it "returns http success" do
      get change_person_employment_tenures_path(person, company_id: company.id)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /people/:id/employment_tenures" do
    it "returns http success" do
      post person_employment_tenures_path(person), params: { employment_tenure: { 
        company_id: company.id, 
        position_id: position.id, 
        started_at: 1.month.ago 
      } }
      expect(response).to have_http_status(:redirect)
    end

    context "when creating a job change" do
      let!(:active_tenure) { create(:employment_tenure, person: person, company: company, position: position, started_at: 6.months.ago) }
      let(:new_position) do
        position_major_level = create(:position_major_level)
        position_type = create(:position_type, organization: company, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        create(:position, position_type: position_type, position_level: position_level)
      end

      it "deactivates the current active tenure and creates a new one" do
        effective_date = Date.current
        
        expect {
          post person_employment_tenures_path(person), params: { 
            employment_tenure: { 
              company_id: company.id, 
              position_id: new_position.id, 
              started_at: effective_date 
            },
            effective_date: effective_date
          }
        }.to change { person.employment_tenures.count }.by(1)

        # Check that the old tenure is now inactive
        expect(active_tenure.reload.ended_at).to eq(effective_date)
        
        # Check that the new tenure is active
        new_tenure = person.employment_tenures.order(:created_at).last
        expect(new_tenure.active?).to be true
        expect(new_tenure.started_at).to eq(effective_date)
      end

      it "shows 'no changes' message when position and manager are the same" do
        post person_employment_tenures_path(person), params: { 
          employment_tenure: { 
            company_id: company.id, 
            position_id: active_tenure.position_id, 
            manager_id: active_tenure.manager_id,
            started_at: Date.current 
          }
        }
        
        expect(response).to redirect_to(person_path(person))
        expect(flash[:notice]).to eq('No changes were made to your employment.')
      end
    end
  end

  describe "GET /people/:id/employment_tenures/:id" do
    it "returns http success" do
      get person_employment_tenure_path(person, employment_tenure)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /people/:id/employment_tenures/:id/edit" do
    it "returns http success" do
      get edit_person_employment_tenure_path(person, employment_tenure)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /people/:id/employment_tenures/:id" do
    it "returns http success" do
      patch person_employment_tenure_path(person, employment_tenure), params: { employment_tenure: { started_at: 2.months.ago } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /people/:id/employment_tenures/:id" do
    it "returns http success" do
      delete person_employment_tenure_path(person, employment_tenure)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /people/:id/employment_tenures/:id/employment_summary" do
    it "returns http success" do
      get employment_summary_person_employment_tenure_path(person, employment_tenure)
      expect(response).to have_http_status(:success)
    end
  end
end
