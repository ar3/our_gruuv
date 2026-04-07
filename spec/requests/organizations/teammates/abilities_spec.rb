# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Teammates::Abilities", type: :request do
  let(:organization) { create(:organization) }
  let(:employee_person) { create(:person) }
  let(:manager_person) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
  let!(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let(:ability) { create(:ability, company: organization, created_by: manager_person, updated_by: manager_person, name: "Leadership") }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago) if manager_teammate.respond_to?(:first_employed_at)
    employee_teammate.update!(first_employed_at: 1.year.ago) if employee_teammate.respond_to?(:first_employed_at)
  end

  def ability_show_path
    organization_teammate_ability_path(organization, employee_teammate, ability)
  end

  describe "GET show" do
    before { sign_in_as_teammate_for_request(manager_person, organization) }

    it "returns success and shows teammate, ability, and award link for employment manager" do
      get ability_show_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include(ability.name)
      expect(response.body).to include("Milestones attained")
      expect(response.body).to include("Expand to see milestone details")
      expect(response.body).to include("Observations")
      expect(response.body).to include("Associated Goals")
      expect(response.body).to include(my_growth_goals_organization_company_teammate_path(organization, employee_teammate))
      expect(response.body).to include("View all of #{employee_person.casual_name}'s goals")
      expect(response.body).to include("Award milestone")
      expect(response.body).to include("teammate_milestones/new")
      expect(response.body).to include("teammate_id=#{employee_teammate.id}")
      expect(response.body).to include("ability_id=#{ability.id}")
    end

    context "when viewer is the teammate on the page (cannot award self)" do
      before { sign_in_as_teammate_for_request(employee_person, organization) }

      it "disables award milestone with explanation tooltip" do
        get ability_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Award milestone")
        expect(response.body).to include("award-milestone-reason")
        expect(response.body).to include("bi-exclamation-triangle")
        expect(response.body).to include("cannot award a milestone to yourself")
      end
    end
  end
end
