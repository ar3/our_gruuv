# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Teammates::Abilities", type: :request do
  let(:organization) { create(:organization) }
  let(:employee_person) { create(:person) }
  let(:manager_person) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
  let!(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let(:ability) { create(:ability, company: organization, created_by: manager_person, updated_by: manager_person, name: "Leadership") }
  let(:ability2) { create(:ability, company: organization, created_by: manager_person, updated_by: manager_person, name: "Strategy") }
  let!(:assignment) { create(:assignment, company: organization) }
  let!(:assignment_tenure) { create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 2.months.ago) }
  let!(:assignment_ability_leadership) { create(:assignment_ability, assignment: assignment, ability: ability) }
  let!(:assignment_ability_strategy) { create(:assignment_ability, assignment: assignment, ability: ability2) }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago) if manager_teammate.respond_to?(:first_employed_at)
    employee_teammate.update!(first_employed_at: 1.year.ago) if employee_teammate.respond_to?(:first_employed_at)
    employee_teammate.employment_tenures.active.first.update!(manager_teammate: manager_teammate)
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
      expect(response.body).to include("Milestones")
      expect(response.body).to include("has attained")
      expect(response.body).to include(employee_person.casual_name)
      expect(response.body).to include(internal_organization_company_teammate_path(organization, employee_teammate))
      expect(response.body).to include("Expand to see milestone details")
      expect(response.body).to include("Research: Current Period Observations")
      expect(response.body).to include("Associated Goals")
      expect(response.body).to include(my_growth_goals_organization_company_teammate_path(organization, employee_teammate))
      expect(response.body).to include("View all of #{employee_person.casual_name}'s goals")
      expect(response.body).to include("Prepare to award milestone")
      expect(response.body).to include("teammate_milestones/new")
      expect(response.body).to include("teammate_id=#{employee_teammate.id}")
      expect(response.body).to include("ability_id=#{ability.id}")

      body = response.body
      expect(body).to include(my_growth_abilities_organization_company_teammate_path(organization, employee_teammate))
      expect(body).to include("Growth")
      expect(body).to include("Switch teammate for ability milestones")
      expect(body).to include("Switch ability")
      expect(body).to include(organization_teammate_ability_path(organization, employee_teammate, ability2))
      expect(body).not_to include("Checking-in on")
      expect(body).not_to include("clear on where they stand")
      expect(body.index("Associated Goals")).to be < body.index("History")
      expect(body.index("History")).to be < body.index("Prepare to award milestone")
      expect(body).to include("No calibration or award history for this ability yet.")
    end

    it "links current period observations to the observations index with observee and ability (no timeframe)" do
      get ability_show_path
      expect(response).to have_http_status(:success)

      doc = Nokogiri::HTML(response.body)
      link = doc.at_xpath("//a[contains(., 'View all observations involving')]")
      expect(link).to be_present
      expect(link.text).to include(employee_person.casual_name)
      expect(link.text).to include(ability.name)

      href = link["href"]
      uri = URI.parse(href)
      params = Rack::Utils.parse_nested_query(uri.query)
      expect(uri.path).to eq(organization_observations_path(organization))
      expect(params["observee_ids"]).to eq([employee_teammate.id.to_s])
      expect(params["rateable_type"]).to eq("Ability")
      expect(params["rateable_id"]).to eq(ability.id.to_s)
      expect(params["timeframe"]).to be_nil
      expect(params["timeframe_start_date"]).to be_nil
      expect(params["timeframe_end_date"]).to be_nil
      expect(params["return_text"]).to eq("Back to 1-by-1 clarity check-in")
      expect(params["return_url"]).to eq(ability_show_path)
    end

    it "links add observation from the observations card with observee and ability" do
      get ability_show_path
      expect(response).to have_http_status(:success)

      doc = Nokogiri::HTML(response.body)
      add_link = doc.at_xpath("//a[contains(., 'Add New Win, Challenge, or Note about')]")
      expect(add_link).to be_present
      expect(add_link.text).to include(employee_person.casual_name)
      expect(add_link.text).to include(ability.name)

      href = add_link["href"]
      uri = URI.parse(href)
      params = Rack::Utils.parse_nested_query(uri.query)
      expect(uri.path).to eq(new_organization_observation_path(organization))
      expect(params["observee_ids"]).to eq([employee_teammate.id.to_s])
      expect(params["rateable_type"]).to eq("Ability")
      expect(params["rateable_id"]).to eq(ability.id.to_s)
      expect(params["return_text"]).to eq("Back to 1-by-1 clarity check-in")
      expect(params["return_url"]).to eq(ability_show_path)
    end

    context "when viewer is the teammate on the page (cannot award self)" do
      before { sign_in_as_teammate_for_request(employee_person, organization) }

      it "disables award milestone with explanation tooltip" do
        get ability_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Prepare to award milestone")
        expect(response.body).to include("award-milestone-reason")
        expect(response.body).to include("bi-exclamation-triangle")
        expect(response.body).to include("cannot award a milestone to yourself")
      end
    end

    context "history" do
      let(:cosigner) { create(:company_teammate, organization: organization) }

      before do
        create(:employment_tenure, teammate: cosigner, company: organization, started_at: 1.year.ago, ended_at: nil)
      end

      def create_pending_award!
        MilestoneAwards::CreateService.call(
          teammate: employee_teammate,
          ability: ability,
          official_level: 1,
          certifying_teammate: manager_teammate,
          created_by_person: manager_person,
          organization: organization,
          source: :normal,
          awarder_typed_name: manager_person.all_names_display_name,
          skip_cosign: false,
          cosign_invitee_ids: [cosigner.id],
          privacy_level: "company"
        ).value
      end

      def ensure_calibration_item!
        AbilityMilestoneCalibrationEnsureService.call(teammate: employee_teammate, organization: organization).value
        employee_teammate.reload.ability_milestone_calibration.items.find_by!(ability: ability)
      end

      it "shows award attempts to the awarder/manager and hides them from the recipient" do
        award = create_pending_award!

        get ability_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("History")
        expect(response.body).to include("Milestone 1 award attempt")
        expect(response.body).to include("Awaiting co-sign")
        expect(response.body).to include(
          organization_teammate_ability_milestone_award_path(organization, employee_teammate, ability, award)
        )

        sign_in_as_teammate_for_request(employee_person, organization)
        get ability_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("History")
        expect(response.body).not_to include("Milestone 1 award attempt")
        expect(response.body).not_to include("Awaiting co-sign")
      end

      it "hides the other calibration rating until both sides have rated" do
        item = ensure_calibration_item!
        item.assign_side_rating!(role: :employee, value: 2)

        sign_in_as_teammate_for_request(employee_person, organization)
        get ability_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Calibration")
        expect(response.body).to include("Your rating saved")
        expect(response.body).to include("Waiting on #{manager_person.casual_name}")
        expect(response.body).to include("You:")
        expect(response.body).to include("Milestone 2")
        expect(response.body).not_to include("#{manager_person.casual_name}:")

        sign_in_as_teammate_for_request(manager_person, organization)
        get ability_show_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("#{employee_person.casual_name} has rated")
        expect(response.body).not_to include("You:")
        expect(response.body).not_to include("#{employee_person.casual_name}:")

        item.assign_side_rating!(role: :manager, value: 3)
        get ability_show_path
        expect(response.body).to include("Ready to submit certification")
        expect(response.body).to include("You:")
        expect(response.body).to include("Milestone 3")
        expect(response.body).to include("#{employee_person.casual_name}:")
        expect(response.body).to include("Milestone 2")
      end
    end
  end
end
