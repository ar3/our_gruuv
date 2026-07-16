# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teammate OGOs page", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/company_teammates/:id/ogos" do
    it "allows the teammate to view their own OGOs page" do
      get ogos_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(person.casual_name)
      expect(response.body).to include("s OGOs")
      expect(response.body).to include("About #{person.casual_name}")
      expect(response.body).to include("OGO health (last 30 days)")
    end

    it "includes a link to all observations involving the teammate" do
      get ogos_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("All OGOs involving #{person.casual_name}")
      expect(response.body).to include("involving_teammate_id=#{teammate.id}")
      expect(response.body).to include("view=large_list")
    end

    it "includes the Source from Slack tab on the OGOs page" do
      get ogos_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("Source from Slack")
      expect(response.body).to include("/ogos/source_from_slack")
    end
  end

  describe "GET /organizations/:organization_id/company_teammates/:id/ogos/from" do
    it "renders the from tab" do
      get ogos_from_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("From #{person.casual_name}")
    end
  end

  describe "GET /organizations/:organization_id/company_teammates/:id/ogos/source_from_slack" do
    it "renders the Source from Slack Beta tab with page help" do
      get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Source from Slack")
      expect(response.body).to include("Beta")
      expect(response.body).to include("sourceFromSlackPageHelp")
      expect(response.body).to include("missed reinforcement is partly on you")
      expect(response.body).not_to include("OGO health (last 30 days)")
    end

    it "prompts the viewer to connect Slack (search) when not connected" do
      get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("Connect Slack (search)")
      expect(response.body).to include("/slack_search/oauth/authorize")
    end

    context "when the viewer has a Slack search identity" do
      before { create(:teammate_identity, :slack_search, teammate: teammate) }

      it "shows connected status with reconnect and disconnect" do
        get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include("Slack (search) is connected")
        expect(response.body).to include("Reconnect Slack (search)")
        expect(response.body).to include("Disconnect")
      end
    end
  end

  describe "GET /organizations/:organization_id/company_teammates/:id/ogos/feedback_requests" do
    it "renders the feedback requests tab" do
      get ogos_feedback_requests_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Feedback Requests")
      expect(response.body).to include("Feedback requests about #{person.casual_name}")
    end

    context "when the viewer owes a response about the subject" do
      let(:requestor_person) { create(:person) }
      let(:requestor) { create(:company_teammate, person: requestor_person, organization: organization) }
      let!(:feedback_request) do
        create(:feedback_request, company: organization, requestor_teammate: requestor, subject_of_feedback_teammate: teammate)
      end

      before do
        create(:employment_tenure, teammate: requestor, company: organization, started_at: 1.year.ago, ended_at: nil)
        feedback_request.responders << teammate
      end

      it "shows an open respondent banner on the feedback requests tab only" do
        get ogos_organization_company_teammate_path(organization, teammate)
        expect(response.body).not_to include("You have open feedback requests to answer")

        get ogos_feedback_requests_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include("You have open feedback requests to answer")
        expect(response.body).to include("Respond")
      end
    end
  end

  describe "authorization" do
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }

    before do
      create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      other_teammate.update!(first_employed_at: 1.year.ago)
      sign_in_as_teammate_for_request(other_person, organization)
    end

    it "denies access when viewing another teammate without permission" do
      get ogos_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:redirect)
    end
  end
end
