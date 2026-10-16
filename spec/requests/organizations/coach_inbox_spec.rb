# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Coach Inbox", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/coach_inbox" do
    it "renders the beta inbox with sections and coming-soon nudge" do
      get organization_coach_inbox_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Coach Inbox")
      expect(response.body).to include("Beta")
      expect(response.body).to include("Check-ins")
      expect(response.body).to include("OGOs")
      expect(response.body).to include("Goals")
      expect(response.body).to include("Expectation Alignment")
      expect(response.body).to include("Milestones")
      expect(response.body).to include("Skipped co-sign")
      expect(response.body).to include("Who to show")
      expect(response.body).to include("Coming soon")
      expect(response.body).to include("Show")
    end

    it "lists a skipped co-sign award for someone with manage employment" do
      teammate.update!(can_manage_employment: true)
      create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      recipient = create(:teammate, :assigned_employee, organization: organization)
      create(:employment_tenure, teammate: recipient, company: organization, started_at: 1.year.ago, ended_at: nil)
      ability = create(:ability, company: organization, name: "SkippedAbility")

      MilestoneAwards::CreateService.call(
        teammate: recipient,
        ability: ability,
        official_level: 1,
        certifying_teammate: teammate,
        created_by_person: person,
        organization: organization,
        source: :normal,
        awarder_typed_name: person.all_names_display_name,
        skip_cosign: true,
        privacy_level: "company"
      )

      get organization_coach_inbox_path(organization, expand: ["milestone_skipped_cosign"])

      expect(response).to have_http_status(:success)
      expect(response.body).to include("SkippedAbility")
      expect(response.body).to include("Skipped co-sign")
    end

    it "expands a sub-section to show item rows" do
      get organization_coach_inbox_path(organization, expand: ["open_feedback_responses"])

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hide")
      expect(response.body).to include("No outstanding items in this sub-section")
    end

    it "is linked from Beta navigation" do
      get organization_start_here_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_coach_inbox_path(organization))
      expect(response.body).to include("Coach Inbox")
    end
  end
end
