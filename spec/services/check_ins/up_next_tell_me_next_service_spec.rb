# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::UpNextTellMeNextService do
  include Rails.application.routes.url_helpers

  let(:organization) { create(:organization, :company) }
  let(:employee_person) { create(:person, first_name: "Alex", preferred_name: "Alex") }
  let(:manager_person) { create(:person, first_name: "Morgan", preferred_name: "Morgan") }
  let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization) }
  let!(:employment_tenure) do
    create(
      :employment_tenure,
      teammate: employee_teammate,
      company: organization,
      manager: manager_teammate,
      started_at: 1.year.ago
    )
  end

  def refresh!
    EngagementHealth::Refresher.call(employee_teammate)
  end

  def call_as(person:, teammate:)
    described_class.call(
      teammate: employee_teammate,
      organization: organization,
      viewing_person: person,
      viewing_teammate: teammate
    )
  end

  def finalize_position!(at: 5.days.ago)
    create(
      :position_check_in,
      :closed,
      teammate: employee_teammate,
      employment_tenure: employment_tenure,
      official_check_in_completed_at: at
    )
  end

  describe "all_clear" do
    it "points to the hub when every required clarity item is healthy" do
      aspiration = create(:aspiration, company: organization, name: "Healthy Value")
      create(
        :aspiration_check_in,
        :finalized,
        teammate: employee_teammate,
        aspiration: aspiration,
        official_check_in_completed_at: 5.days.ago
      )
      finalize_position!
      refresh!

      result = call_as(person: manager_person, teammate: manager_teammate)

      expect(result[:state]).to eq(:all_clear)
      expect(result[:button_label]).to include("All clear here!")
      expect(result[:button_label]).to include("Alex")
      expect(result[:button_url]).to eq(
        hub_organization_company_teammate_check_ins_path(organization, employee_teammate)
      )
    end
  end

  describe "review" do
    it "wins when both sides are done on an unhealthy item" do
      finalize_position!
      aspiration = create(:aspiration, company: organization, name: "Ready Value")
      create(
        :aspiration_check_in,
        :ready_for_finalization,
        teammate: employee_teammate,
        aspiration: aspiration,
        manager_completed_by_teammate: manager_teammate
      )
      refresh!

      result = call_as(person: manager_person, teammate: manager_teammate)

      expect(result[:state]).to eq(:review)
      expect(result[:button_label]).to match(/Review \d+ check-ins? together/)
      expect(result[:note]).to include("go review them together right now")
      expect(result[:button_url]).to eq(
        organization_company_teammate_finalization_path(organization, employee_teammate)
      )
    end
  end

  describe "incomplete" do
    it "links to the next-item one-by-one page when the viewer still owes a side" do
      finalize_position!
      aspiration = create(:aspiration, company: organization, name: "Urgent Value")
      AspirationCheckIn.find_or_create_open_for(employee_teammate, aspiration)
      refresh!

      result = call_as(person: manager_person, teammate: manager_teammate)

      expect(result[:state]).to eq(:incomplete)
      expect(result[:button_label]).to include("Check-in on Alex and the Aspirational Value Urgent Value")
      expect(result[:button_url]).to eq(
        organization_teammate_aspiration_path(organization, employee_teammate, aspiration.id)
      )
    end
  end

  describe "nudge" do
    it "offers a Slack send when the viewer is done and the other person is not" do
      finalize_position!
      aspiration = create(:aspiration, company: organization, name: "Waiting Value")
      create(
        :aspiration_check_in,
        :employee_completed,
        teammate: employee_teammate,
        aspiration: aspiration
      )
      refresh!

      result = call_as(person: employee_person, teammate: employee_teammate)

      expect(result[:state]).to eq(:nudge)
      expect(result[:button_method]).to eq(:post)
      expect(result[:button_label]).to include("Send Slack nudge")
      expect(result[:preview_text]).to include("Tag you're it")
      expect(result[:button_url]).to eq(
        waiting_nudge_organization_company_teammate_check_ins_path(organization, employee_teammate)
      )
    end

    it "uses Send Again when this pair already received the nudge" do
      finalize_position!
      aspiration = create(:aspiration, company: organization, name: "Waiting Value")
      create(
        :aspiration_check_in,
        :employee_completed,
        teammate: employee_teammate,
        aspiration: aspiration
      )
      refresh!

      employee_teammate.notifications.create!(
        notification_type: CheckIns::UpNextWaitingNudgeService::NOTIFICATION_TYPE,
        status: "sent_successfully",
        message_id: "111.222",
        metadata: {
          "pair_company_teammate_ids" => [employee_teammate.id, manager_teammate.id].sort,
          "channel" => "G1"
        },
        fallback_text: "prior"
      )

      result = call_as(person: employee_person, teammate: employee_teammate)

      expect(result[:state]).to eq(:nudge)
      expect(result[:button_label]).to eq("Send Again")
      expect(result[:last_nudge]).to be_present
    end
  end

  describe "viewer rule" do
    it "treats a non-employee viewer as the manager perspective" do
      finalize_position!
      aspiration = create(:aspiration, company: organization, name: "Manager Owes")
      create(
        :aspiration_check_in,
        :employee_completed,
        teammate: employee_teammate,
        aspiration: aspiration
      )
      refresh!

      other_person = create(:person)
      other_teammate = create(:teammate, person: other_person, organization: organization)
      result = call_as(person: other_person, teammate: other_teammate)

      expect(result[:state]).to eq(:incomplete)
      expect(result[:button_label]).to include("Manager Owes")
    end
  end
end
