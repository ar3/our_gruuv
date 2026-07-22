# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthDashboardsHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  before do
    allow(helper).to receive(:policy).with(organization).and_return(
      double(check_ins_health?: true, goals_health?: true, observations_health?: true, protect_flow?: true)
    )
  end

  describe "#health_dashboard_switcher_pages" do
    it "returns paths with manager_id preserved" do
      pages = helper.health_dashboard_switcher_pages(organization, manager_id: "just_me")
      check_ins = pages.find { |p| p[:key] == :check_ins_health }
      expect(check_ins[:path]).to eq(organization_check_ins_health_path(organization, manager_id: "just_me"))
      protect_flow = pages.find { |p| p[:key] == :protect_flow }
      expect(protect_flow[:path]).to eq(organization_protect_flow_path(organization, manager_id: "just_me"))
    end

    it "filters to pages the user can access" do
      allow(helper).to receive(:policy).with(organization).and_return(
        double(check_ins_health?: true, goals_health?: false, observations_health?: true, protect_flow?: false)
      )
      keys = helper.health_dashboard_switcher_pages(organization, manager_id: "everyone").map { |p| p[:key] }
      expect(keys).to eq([:check_ins_health, :observations_health])
    end

    it "lists Protect Flow before the other health dashboards when allowed" do
      keys = helper.health_dashboard_switcher_pages(organization, manager_id: "my_direct_employees").map { |p| p[:key] }
      expect(keys.first).to eq(:protect_flow)
    end
  end

  describe "#health_dashboard_switcher_button_class" do
    it "marks the current page as primary" do
      expect(helper.health_dashboard_switcher_button_class(:goals_health, :goals_health)).to include("btn-primary")
      expect(helper.health_dashboard_switcher_button_class(:check_ins_health, :goals_health)).to include("btn-outline-primary")
    end
  end
end
