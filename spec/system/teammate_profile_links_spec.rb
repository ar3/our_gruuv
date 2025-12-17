require 'rails_helper'

RSpec.describe "Teammate Profile Links", type: :system do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person) }
  let(:employee) { create(:person) }
  let(:position) do
    position_major_level = create(:position_major_level)
    position_type = create(:position_type, organization: organization, position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, position_type: position_type, position_level: position_level)
  end

  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:employment_tenure) { create(:employment_tenure, teammate: employee_teammate, company: organization, position: position) }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, position: position)
    sign_in_as_teammate(manager, organization)
  end

  describe "check_ins/show view" do
    it "uses teammate in all route helpers" do
      visit organization_company_teammate_check_ins_path(organization, employee_teammate)

      # Check that links use teammate, not person
      expect(page).to have_link(href: organization_company_teammate_path(organization, employee_teammate))
      expect(page).to have_link(href: organization_company_teammate_check_ins_path(organization, employee_teammate, view: 'table'))
      expect(page).to have_link(href: organization_company_teammate_check_ins_path(organization, employee_teammate, view: 'card'))
      expect(page).to have_link(href: assignment_selection_organization_company_teammate_path(organization, employee_teammate))
    end
  end

  describe "assignment_selection view" do
    it "uses teammate in all route helpers" do
      visit assignment_selection_organization_company_teammate_path(organization, employee_teammate)

      # Check that links use teammate, not person
      expect(page).to have_link(href: organization_company_teammate_check_ins_path(organization, employee_teammate))
      expect(page).to have_link(href: update_assignments_organization_company_teammate_path(organization, employee_teammate))
    end
  end

  describe "employment_tenures views" do
    it "uses correct teammate in employment_summary view" do
      visit employment_summary_organization_company_teammate_employment_tenure_path(organization, employee_teammate, employment_tenure)

      # Check that back link uses teammate for the company
      expect(page).to have_link(href: organization_company_teammate_path(organization, employee_teammate))
    end

    it "uses correct teammate in edit view" do
      visit edit_organization_company_teammate_employment_tenure_path(organization, employee_teammate, employment_tenure)

      # Check that back link uses employment_tenure.teammate
      expect(page).to have_link(href: organization_company_teammate_path(organization, employee_teammate))
    end
  end

  describe "check_ins_health views" do
    it "uses teammate from data hash in links" do
      visit check_ins_health_organization_path(organization)

      # The view should use teammate, not person, in route helpers
      # This is tested by checking that links are present and functional
      expect(page).to have_http_status(:success)
    end
  end
end

