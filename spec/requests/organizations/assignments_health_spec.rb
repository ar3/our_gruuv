# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Assignments Health", type: :request do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, company)
  end

  describe "GET /organizations/:organization_id/assignments_health" do
    it "returns success and shows key sections" do
      assignment = create(:assignment, company: company, title: "Clarity Assignment")
      AssignmentExpectationAlignmentScore.create!(
        assignment: assignment,
        organization: company,
        score: 88.0,
        cells: [],
        check_in_teammate_count: 2,
        survey_respondent_count: 2,
        calculated_at: Time.current
      )

      get organization_assignments_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Assignments Health")
      expect(response.body).to include("assignmentsHealthPageHelp")
      expect(response.body).to include("Goal of this page")
      expect(response.body).to include("Score distribution")
      expect(response.body).to include("10 best")
      expect(response.body).to include("10 worst")
      expect(response.body).to include("Clarity Assignment")
      expect(response.body).to include("Switch object")
      expect(response.body).to include("Switch page type")
      expect(response.body).to include(organization_assignments_path(company))
      expect(response.body).to include(organization_insights_assignments_path(company))
      expect(response.body).to include("Refresh missing &amp; stale")
    end

    it "lists missing scores for refresh" do
      create(:assignment, company: company, title: "Needs Score")

      get organization_assignments_health_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Missing &amp; stale scores")
      expect(response.body).to include("Needs Score")
      expect(response.body).to include("Missing")
    end
  end

  describe "POST /organizations/:organization_id/assignments_health_refresh" do
    it "queues a refresh for one assignment" do
      assignment = create(:assignment, company: company, title: "Refresh Me")

      expect {
        post organization_assignments_health_refresh_path(company, assignment_id: assignment.id)
      }.to have_enqueued_job(AssignmentExpectationAlignmentScoreRefreshJob).with(assignment.id)

      expect(response).to redirect_to(organization_assignments_health_path(company))
      follow_redirect!
      expect(response.body).to include("Expectation Alignment Score refresh queued for Refresh Me")
    end
  end

  describe "POST /organizations/:organization_id/assignments_health_refresh_missing_and_stale" do
    it "queues refresh for missing and stale assignments only" do
      fresh = create(:assignment, company: company, title: "Fresh")
      stale = create(:assignment, company: company, title: "Stale")
      missing = create(:assignment, company: company, title: "Missing")

      AssignmentExpectationAlignmentScore.create!(
        assignment: fresh,
        organization: company,
        score: 90,
        cells: [],
        check_in_teammate_count: 2,
        survey_respondent_count: 2,
        calculated_at: 1.hour.ago
      )
      AssignmentExpectationAlignmentScore.create!(
        assignment: stale,
        organization: company,
        score: 40,
        cells: [],
        check_in_teammate_count: 2,
        survey_respondent_count: 2,
        calculated_at: 2.days.ago
      )

      expect {
        post organization_assignments_health_refresh_missing_and_stale_path(company)
      }.to have_enqueued_job(AssignmentExpectationAlignmentScoreRefreshJob).with(stale.id)
        .and have_enqueued_job(AssignmentExpectationAlignmentScoreRefreshJob).with(missing.id)

      expect(response).to redirect_to(organization_assignments_health_path(company))
      follow_redirect!
      expect(response.body).to include("Expectation Alignment Score refresh queued for 2 assignments")
    end
  end
end
