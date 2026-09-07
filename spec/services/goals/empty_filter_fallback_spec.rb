# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::EmptyFilterFallback do
  let(:organization) { create(:organization, :company) }
  let(:viewer_person) { create(:person, first_name: "Pat", last_name: "Viewer") }
  let(:viewer) { create(:company_teammate, person: viewer_person, organization: organization) }

  describe "person owner" do
    it "nudges create for the person when the viewer can create for them" do
      result = described_class.call(
        organization: organization,
        viewer: viewer,
        owner_type: "CompanyTeammate",
        owner_id: viewer.id,
        can_create_goals: true
      )

      expect(result.kind).to eq(:person)
      expect(result.message).to include("Create a goal for Pat")
      expect(result.cta_disabled).to eq(false)
      expect(result.cta_path).to include("select_create")
      person_segment = result.message_segments.find { |part| part[:text].to_s.start_with?("Pat") }
      expect(person_segment[:path]).to eq(
        Rails.application.routes.url_helpers.internal_organization_company_teammate_path(organization, viewer)
      )
    end

    it "disables the CTA when the viewer cannot create for that person" do
      peer_person = create(:person, first_name: "Sam", last_name: "Peer")
      peer = create(:company_teammate, person: peer_person, organization: organization)

      result = described_class.call(
        organization: organization,
        viewer: viewer,
        owner_type: "CompanyTeammate",
        owner_id: peer.id,
        can_create_goals: true
      )

      expect(result.cta_disabled).to eq(true)
      expect(result.cta_disabled_reason).to include("can't create goals for Sam")
    end
  end

  describe "all my teams" do
    it "asks who can add team membership when the viewer is on no teams" do
      adder_person = create(:person, first_name: "Alex", last_name: "Adder")
      adder = create(
        :company_teammate,
        person: adder_person,
        organization: organization,
        can_manage_departments_and_teams: true
      )

      result = described_class.call(
        organization: organization,
        viewer: viewer,
        all_my_teams_filter: true,
        viewer_teams: [],
        can_create_goals: true
      )

      expect(result.kind).to eq(:not_on_teams)
      expect(result.message).to include("What team(s) is Pat")
      expect(result.message).to include("Reach out to someone who can add people to teams")
      expect(result.reach_out_people.map { |p| p[:name] }.join).to include("Alex")
      expect(result.reach_out_people.first[:path]).to include("/company_teammates/#{adder.id}/internal")
    end

    it "lists team names and offers create when teams have no goals" do
      team = create(:team, company: organization, name: "Platform")

      result = described_class.call(
        organization: organization,
        viewer: viewer,
        all_my_teams_filter: true,
        viewer_teams: [team],
        can_create_goals: true
      )

      expect(result.kind).to eq(:teams_without_goals)
      expect(result.message).to include("Platform")
      expect(result.message).to include("no goals attached")
      team_segment = result.message_segments.find { |part| part[:text] == "Platform" }
      expect(team_segment[:path]).to eq(
        Rails.application.routes.url_helpers.organization_team_path(organization, team)
      )
      expect(result.cta_disabled).to eq(false)
      expect(result.cta_path).to include("owner_id=Team_#{team.id}")
    end
  end

  describe "generic owner" do
    it "offers create for a company owner label" do
      result = described_class.call(
        organization: organization,
        viewer: viewer,
        owner_type: "Organization",
        owner_id: organization.id,
        can_create_goals: true
      )

      expect(result.kind).to eq(:generic)
      expect(result.message).to include("Create a goal for")
      expect(result.cta_path).to include("owner_id=Company_#{organization.id}")
      org_segment = result.message_segments.find { |part| part[:path].present? }
      expect(org_segment[:path]).to eq(
        Rails.application.routes.url_helpers.organization_path(organization)
      )
    end

    it "links a department owner name to the department show page" do
      department = create(:department, company: organization, name: "Engineering")

      result = described_class.call(
        organization: organization,
        viewer: viewer,
        owner_type: "Department",
        owner_id: department.id,
        can_create_goals: true
      )

      dept_segment = result.message_segments.find { |part| part[:text] == "Engineering" }
      expect(dept_segment[:path]).to eq(
        Rails.application.routes.url_helpers.organization_department_path(organization, department)
      )
    end
  end

  describe "my employees" do
    it "shows a privacy legend when the viewer has no direct reports" do
      result = described_class.call(
        organization: organization,
        viewer: viewer,
        my_employees_filter: true,
        can_view_goals_health: true
      )

      expect(result.kind).to eq(:employee_no_reports)
      expect(result.message).to include("Managers only see employees' personal goals when privacy allows")
      expect(result.privacy_legend.map { |e| e[:key] }).to include(
        "only_creator_owner_and_managers",
        "everyone_in_company",
        "only_creator",
        "only_creator_and_owner"
      )
      expect(result.privacy_legend.select { |e| e[:allowed] }.map { |e| e[:key] }).to eq(
        %w[only_creator_owner_and_managers everyone_in_company]
      )
    end

    it "links to Goals Health when the viewer has reports but no matching goals" do
      report_person = create(:person, first_name: "Dana")
      report = create(:company_teammate, person: report_person, organization: organization)
      create(
        :employment_tenure,
        company: organization,
        company_teammate: report,
        manager_teammate: viewer,
        ended_at: nil
      )

      result = described_class.call(
        organization: organization,
        viewer: viewer,
        my_employees_filter: true,
        can_view_goals_health: true
      )

      expect(result.kind).to eq(:employee_no_matching_goals)
      expect(result.cta_label).to eq("Open Goals Health")
      expect(result.cta_disabled).to eq(false)
      expect(result.cta_path).to include("goals_health")
      expect(result.cta_path).to include("CompanyTeammate_#{viewer.id}")
    end
  end
end
