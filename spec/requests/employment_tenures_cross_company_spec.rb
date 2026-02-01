require 'rails_helper'

RSpec.describe "EmploymentTenures Cross-Company", type: :request do
  let(:person) { create(:person) }
  let(:company1) { create(:organization, :company, name: 'Company 1') }
  let(:company2) { create(:organization, :company, name: 'Company 2') }
  let(:organization) { company1 }
  
  let(:position1) do
    position_major_level = create(:position_major_level)
    title = create(:title, company: company1, position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, title: title, position_level: position_level)
  end

  let(:position2) do
    position_major_level = create(:position_major_level)
    title = create(:title, company: company2, position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, title: title, position_level: position_level)
  end

  let(:teammate1) do
    person.teammates.find_by(organization: company1) ||
      create(:teammate, person: person, organization: company1)
  end

  let(:teammate2) do
    person.teammates.find_by(organization: company2) ||
      create(:teammate, person: person, organization: company2)
  end

  before do
    sign_in_as_teammate_for_request(person, company1)
  end

  describe "POST /organizations/:organization_id/company_teammates/:company_teammate_id/employment_tenures" do
    context "when creating employment for a different company than current organization" do
      it "creates employment tenure for the target company" do
        expect {
          post organization_company_teammate_employment_tenures_path(organization, teammate1), params: {
            employment_tenure: {
              company_id: company2.id,
              position_id: position2.id,
              started_at: 1.month.ago
            }
          }
        }.to change { EmploymentTenure.count }.by(1)

        new_tenure = EmploymentTenure.last
        expect(new_tenure.company.id).to eq(company2.id)
        expect(new_tenure.teammate).to eq(teammate2)
      end

      it "redirects to the teammate profile for the target company, not the organization context" do
        post organization_company_teammate_employment_tenures_path(organization, teammate1), params: {
          employment_tenure: {
            company_id: company2.id,
            position_id: position2.id,
            started_at: 1.month.ago
          }
        }

        expect(response).to redirect_to(organization_company_teammate_path(company2, teammate2))
        expect(flash[:notice]).to eq('Employment tenure was successfully created.')
      end
    end

    context "when creating a job change for a different company" do
      let!(:existing_tenure) do
        create(:employment_tenure, teammate: teammate2, company: company2, position: position2, started_at: 6.months.ago)
      end

      it "redirects to the teammate profile for the target company" do
        post organization_company_teammate_employment_tenures_path(organization, teammate1), params: {
          employment_tenure: {
            company_id: company2.id,
            position_id: position2.id,
            started_at: Date.current
          },
          effective_date: Date.current
        }

        expect(response).to redirect_to(organization_company_teammate_path(company2, teammate2))
        expect(flash[:notice]).to eq('Employment tenure was successfully created.')
      end
    end
  end

  describe "PATCH /organizations/:organization_id/company_teammates/:company_teammate_id/employment_tenures/:id" do
    let!(:employment_tenure) do
      create(:employment_tenure, teammate: teammate2, company: company2, position: position2)
    end

    context "when updating employment tenure for a different company" do
      it "redirects to the teammate profile for the employment tenure's company" do
        patch organization_company_teammate_employment_tenure_path(organization, teammate1, employment_tenure), params: {
          employment_tenure: { started_at: 2.months.ago }
        }

        expect(response).to redirect_to(organization_company_teammate_path(company2, teammate2))
        expect(flash[:notice]).to eq('Employment tenure was successfully updated.')
      end
    end
  end

  describe "DELETE /organizations/:organization_id/company_teammates/:company_teammate_id/employment_tenures/:id" do
    let!(:employment_tenure) do
      create(:employment_tenure, teammate: teammate2, company: company2, position: position2)
    end

    context "when deleting employment tenure for a different company" do
      it "redirects to the teammate profile for the employment tenure's company" do
        delete organization_company_teammate_employment_tenure_path(organization, teammate1, employment_tenure)

        expect(response).to redirect_to(organization_company_teammate_path(company2, teammate2))
        expect(flash[:notice]).to eq('Employment tenure was successfully deleted.')
      end
    end
  end
end

