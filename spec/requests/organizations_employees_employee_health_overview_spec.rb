# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Employees#index with employee_health_overview spotlight", type: :request do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report1) { create(:person) }
  let(:direct_report2) { create(:person) }
  let!(:manager_teammate) { CompanyTeammate.create!(person: manager, organization: organization, first_employed_at: 1.month.ago) }
  let!(:direct_report1_teammate) { CompanyTeammate.create!(person: direct_report1, organization: organization, first_employed_at: 1.month.ago) }
  let!(:direct_report2_teammate) { CompanyTeammate.create!(person: direct_report2, organization: organization, first_employed_at: 1.month.ago) }

  before do
    create(:employment_tenure, teammate: direct_report1_teammate, company: organization, manager_teammate: manager_teammate, ended_at: nil)
    create(:employment_tenure, teammate: direct_report2_teammate, company: organization, manager_teammate: manager_teammate, ended_at: nil)

    direct_report1.update!(first_name: "Alice", last_name: "Alpha")
    direct_report2.update!(first_name: "Bob", last_name: "Bravo")

    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(manager)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(manager_teammate)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
  end

  describe "GET #index with employee_health_overview spotlight" do
    it "renders successfully" do
      get organization_employees_path(organization, spotlight: "employee_health_overview", view: "managers_view", manager_teammate_id: manager_teammate.id)

      expect(response).to be_successful
    end

    it "sets the correct spotlight type" do
      get organization_employees_path(organization, spotlight: "employee_health_overview", view: "managers_view", manager_teammate_id: manager_teammate.id)

      expect(assigns(:current_spotlight)).to eq("employee_health_overview")
    end

    it "calculates employee health overview spotlight stats" do
      get organization_employees_path(organization, spotlight: "employee_health_overview", view: "managers_view", manager_teammate_id: manager_teammate.id)

      spotlight_stats = assigns(:spotlight_stats)
      expect(spotlight_stats).to be_present
      expect(spotlight_stats).to include(:manager_filter, :check_ins, :goals, :observations)
      expect(spotlight_stats[:manager_filter]).to eq("my_direct_employees")
    end

    it "renders the employee health overview spotlight partial" do
      get organization_employees_path(organization, spotlight: "employee_health_overview", view: "managers_view", manager_teammate_id: manager_teammate.id)

      expect(response).to be_successful
      expect(response.body).to include("Employee Health Overview")
      expect(response.body).to include("Check-ins Health")
      expect(response.body).to include("Goals Health")
      expect(response.body).to include("Observations Health")
      expect(response.body).to include("Total Active Employees")
      expect(response.body).to include("Healthy")
      expect(response.body).to include("Needs Attention")
    end

    it "defaults to employee_health_overview when manager_teammate_id is present and no spotlight is specified" do
      get organization_employees_path(organization, view: "managers_view", manager_teammate_id: manager_teammate.id)

      expect(assigns(:current_spotlight)).to eq("employee_health_overview")
    end
  end
end
