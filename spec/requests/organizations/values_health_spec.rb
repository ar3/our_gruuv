# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Values Health", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/values_health" do
    it "returns success and shows key sections" do
      aspiration = create(:aspiration, company: company, name: "Clarity Value")
      AspirationExpectationAlignmentScore.create!(
        aspiration: aspiration,
        organization: company,
        score: 88.0,
        cells: [],
        check_in_teammate_count: 2,
        calculated_at: Time.current
      )

      get organization_values_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Values Health")
      expect(response.body).to include("valuesHealthPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Score distribution")
      expect(response.body).to include("10 best")
      expect(response.body).to include("10 worst")
      expect(response.body).to include("Clarity Value")
      expect(response.body).to include("Switch object")
      expect(response.body).to include(organization_aspirations_path(company))
      expect(response.body).to include(organization_insights_values_path(company))
      expect(response.body).to include("Refresh missing &amp; stale")
      expect(response.body).to include("Values check-in clarity")
    end

    it "lists missing scores for refresh" do
      create(:aspiration, company: company, name: "Needs Score")

      get organization_values_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Missing &amp; stale scores")
      expect(response.body).to include("Needs Score")
      expect(response.body).to include("Missing")
    end
  end

  describe "POST /organizations/:organization_id/values_health_refresh" do
    it "queues a refresh for one value" do
      aspiration = create(:aspiration, company: company, name: "Refresh Me")

      expect {
        post organization_values_health_refresh_path(company, aspiration_id: aspiration.id)
      }.to have_enqueued_job(AspirationExpectationAlignmentScoreRefreshJob).with(aspiration.id)

      expect(response).to redirect_to(organization_values_health_path(company))
      follow_redirect!
      expect(response.body).to include("Expectation Alignment Score refresh queued for Refresh Me")
    end
  end

  describe "POST /organizations/:organization_id/values_health_refresh_missing_and_stale" do
    it "queues refresh for missing and stale values only" do
      fresh = create(:aspiration, company: company, name: "Fresh")
      stale = create(:aspiration, company: company, name: "Stale")
      missing = create(:aspiration, company: company, name: "Missing")

      AspirationExpectationAlignmentScore.create!(
        aspiration: fresh,
        organization: company,
        score: 90,
        cells: [],
        check_in_teammate_count: 2,
        calculated_at: 1.hour.ago
      )
      AspirationExpectationAlignmentScore.create!(
        aspiration: stale,
        organization: company,
        score: 40,
        cells: [],
        check_in_teammate_count: 2,
        calculated_at: 2.days.ago
      )

      expect {
        post organization_values_health_refresh_missing_and_stale_path(company)
      }.to have_enqueued_job(AspirationExpectationAlignmentScoreRefreshJob).with(stale.id)
        .and have_enqueued_job(AspirationExpectationAlignmentScoreRefreshJob).with(missing.id)

      expect(response).to redirect_to(organization_values_health_path(company))
      follow_redirect!
      expect(response.body).to include("Expectation Alignment Score refresh queued for 2 values")
    end
  end

  context "values check-in clarity redaction" do
    let(:organization) { company }
    let!(:aspiration) { create(:aspiration, company: company, name: "Integrity", sort_order: 1) }
    let(:manager_person) { create(:person, first_name: "Mgr", last_name: "Boss") }
    let!(:manager_teammate) do
      create(
        :company_teammate,
        :assigned_employee,
        person: manager_person,
        organization: organization,
        first_employed_at: 1.year.ago,
        last_terminated_at: nil
      )
    end
    let(:ic_person) { create(:person, first_name: "Clarity", last_name: "Subject") }
    let!(:ic_teammate) do
      create(
        :company_teammate,
        :assigned_employee,
        person: ic_person,
        organization: organization,
        first_employed_at: 1.year.ago,
        last_terminated_at: nil
      )
    end

    before do
      allow_any_instance_of(OrganizationPolicy).to receive(:manage_employment?).and_return(false)
      create(:employment_tenure, company_teammate: ic_teammate, company: organization, manager_teammate: manager_teammate)
      create(
        :aspiration_check_in,
        :finalized,
        teammate: ic_teammate,
        aspiration: aspiration,
        employee_rating: "meeting",
        manager_rating: "meeting",
        official_rating: "exceeding"
      )
    end

    it "shows Dots/Names toggle and always uses dots by default" do
      get organization_values_health_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Values check-in clarity")
      expect(response.body).to include('aria-label="Marker style"')
      expect(response.body).to include("talent-density-viz-dot")
      expect(response.body).not_to include(ic_person.casual_name)
    end

    it "keeps dots for managers and subjects when dots mode is selected" do
      name_badge = /badge rounded-pill[^>]*>\s*#{Regexp.escape(ic_person.casual_name)}\s*</

      sign_in_as_teammate_for_request(manager_person, organization)
      get organization_values_health_path(organization, display: "dots")
      expect(response.body).to include("talent-density-viz-dot")
      expect(response.body).not_to match(name_badge)

      sign_in_as_teammate_for_request(ic_person, organization)
      get organization_values_health_path(organization, display: "dots")
      expect(response.body).to include("talent-density-viz-dot")
      expect(response.body).not_to match(name_badge)
    end

    it "in names mode reveals the subject to their manager but not to unrelated viewers" do
      get organization_values_health_path(organization, display: "names")
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(ic_person.casual_name)

      sign_in_as_teammate_for_request(manager_person, organization)
      get organization_values_health_path(organization, display: "names")
      expect(response.body).to include(ic_person.casual_name)

      sign_in_as_teammate_for_request(ic_person, organization)
      get organization_values_health_path(organization, display: "names")
      expect(response.body).to include(ic_person.casual_name)
    end

    context "when viewer can manage employment" do
      before do
        allow_any_instance_of(OrganizationPolicy).to receive(:manage_employment?).and_return(true)
      end

      it "unredacts all names when display=names" do
        get organization_values_health_path(organization, display: "names")

        expect(response).to have_http_status(:success)
        expect(response.body).to include(ic_person.casual_name)
      end
    end
  end
end
