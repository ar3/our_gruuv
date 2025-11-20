require 'rails_helper'

RSpec.describe "Organizations Slack", type: :request do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  let(:slack_config) { create(:slack_configuration, organization: company) }

  before do
    create(:teammate, person: person, organization: company)
    sign_in_as_teammate_for_request(person, company)
    slack_config
  end

  describe "GET /organizations/:organization_id/slack" do
    context "when organization is a company" do
      it "returns http success" do
        get organization_slack_path(company)
        expect(response).to have_http_status(:success)
      end

      it "renders the slack configuration page" do
        get organization_slack_path(company)
        expect(response.body).to include("Slack Configuration")
        expect(response.body).to include("Slack Setup")
      end
    end

    context "when organization is not a company" do
      before do
        create(:teammate, person: person, organization: team)
        sign_in_as_teammate_for_request(person, team)
      end

      it "redirects to organization path" do
        get organization_slack_path(team)
        expect(response).to redirect_to(organization_path(team))
        expect(flash[:alert]).to include("Slack configuration is only available for companies")
      end
    end
  end

  describe "GET /organizations/:organization_id/slack/teammates" do
    context "when organization is a company" do
      it "returns http success" do
        get teammates_organization_slack_path(company)
        expect(response).to have_http_status(:success)
      end

      it "renders the teammates associations page" do
        get teammates_organization_slack_path(company)
        expect(response.body).to include("Manage Teammate Associations")
        expect(response.body).to include("Teammate to Slack User Associations")
      end
    end

    context "when organization is not a company" do
      before do
        create(:teammate, person: person, organization: team)
        sign_in_as_teammate_for_request(person, team)
      end

      it "redirects to organization path" do
        get teammates_organization_slack_path(team)
        expect(response).to redirect_to(organization_path(team))
      end
    end
  end

  describe "GET /organizations/:organization_id/slack/channels" do
    context "when organization is a company" do
      it "returns http success" do
        get channels_organization_slack_path(company)
        expect(response).to have_http_status(:success)
      end

      it "renders the channels associations page" do
        get channels_organization_slack_path(company)
        expect(response.body).to include("Manage Channel & Group Associations")
        expect(response.body).to include("Organization Channel & Group Associations")
      end
    end

    context "when organization is not a company" do
      before do
        create(:teammate, person: person, organization: team)
        sign_in_as_teammate_for_request(person, team)
      end

      it "redirects to organization path" do
        get channels_organization_slack_path(team)
        expect(response).to redirect_to(organization_path(team))
      end
    end
  end

  describe "PATCH /organizations/:organization_id/slack/update_configuration" do
    it "updates configuration and redirects" do
      patch update_configuration_organization_slack_path(company), params: {
        slack_configuration: {
          default_channel: "#test-channel",
          bot_username: "TestBot",
          bot_emoji: ":rocket:"
        }
      }
      expect(response).to redirect_to(organization_slack_path(company))
      expect(flash[:notice]).to include("updated successfully")
    end
  end

  describe "POST /organizations/:organization_id/slack/refresh_channels" do
    let(:mock_channels_service) { instance_double(SlackChannelsService) }

    before do
      allow(SlackChannelsService).to receive(:new).with(kind_of(Organization)).and_return(mock_channels_service)
      allow(mock_channels_service).to receive(:refresh_channels).and_return(true)
    end

    it "refreshes channels and redirects" do
      post refresh_channels_organization_slack_path(company)
      expect(response).to redirect_to(channels_organization_slack_path(company))
      expect(flash[:notice]).to include("refreshed successfully")
    end
  end

  describe "POST /organizations/:organization_id/slack/refresh_groups" do
    let(:mock_groups_service) { instance_double(SlackGroupsService) }

    before do
      allow(SlackGroupsService).to receive(:new).with(kind_of(Organization)).and_return(mock_groups_service)
      allow(mock_groups_service).to receive(:refresh_groups).and_return(true)
    end

    it "refreshes groups and redirects" do
      post refresh_groups_organization_slack_path(company)
      expect(response).to redirect_to(channels_organization_slack_path(company))
      expect(flash[:notice]).to include("refreshed successfully")
    end
  end
end

