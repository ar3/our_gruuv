# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::OpenStallFinder do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:reference_time) { Time.zone.parse("2026-11-14 12:00:00") }

  def eh_item(check_in:, name: "Frontend Craft", status: EngagementHealth::WARNING)
    EngagementHealthStatus.create!(
      teammate: teammate,
      organization: organization,
      level: "item",
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      entity_type: "Assignment",
      entity_id: check_in.assignment_id,
      status: status,
      inputs: {
        "name" => name,
        "open_check_in_present" => true,
        "open_check_in_id" => check_in.id,
        "open_employee_completed" => check_in.employee_completed_at.present?,
        "open_manager_completed" => check_in.manager_completed_at.present?,
        "open_ready_for_finalization" => check_in.employee_completed_at.present? && check_in.manager_completed_at.present?
      },
      computed_at: reference_time
    )
  end

  describe ".worst_for" do
    it "returns nil when there is no open check-in stall" do
      check_in = create(:assignment_check_in, teammate: teammate, assignment: assignment)
      records = [eh_item(check_in: check_in)]

      expect(described_class.worst_for(records, reference_time: reference_time)).to be_nil
    end

    it "returns nil when one-sided wait is under the asymmetric threshold" do
      check_in = create(
        :assignment_check_in,
        :employee_completed,
        teammate: teammate,
        assignment: assignment,
        employee_completed_at: reference_time - 4.days
      )
      records = [eh_item(check_in: check_in)]

      expect(described_class.worst_for(records, reference_time: reference_time)).to be_nil
    end

    it "returns an asymmetric stall when one side has been waiting long enough" do
      check_in = create(
        :assignment_check_in,
        :employee_completed,
        teammate: teammate,
        assignment: assignment,
        employee_completed_at: reference_time - 6.days
      )
      records = [eh_item(check_in: check_in)]

      stall = described_class.worst_for(records, reference_time: reference_time)
      expect(stall.kind).to eq(:asymmetric)
      expect(stall.waiting_on).to eq(:manager)
      expect(stall.days).to eq(6)
      expect(stall.object_name).to eq("Frontend Craft")
    end

    it "returns a stale review stall when both sides are done long enough" do
      check_in = create(
        :assignment_check_in,
        :ready_for_finalization,
        teammate: teammate,
        assignment: assignment,
        employee_completed_at: reference_time - 5.days,
        manager_completed_at: reference_time - 4.days
      )
      records = [eh_item(check_in: check_in)]

      stall = described_class.worst_for(records, reference_time: reference_time)
      expect(stall.kind).to eq(:stale_review)
      expect(stall.waiting_on).to eq(:review)
      expect(stall.days).to eq(4)
    end

    it "prefers a stale review over an older asymmetric stall" do
      older_assignment = create(:assignment, company: organization, title: "Older Side")
      asymmetric = create(
        :assignment_check_in,
        :employee_completed,
        teammate: teammate,
        assignment: older_assignment,
        employee_completed_at: reference_time - 10.days
      )
      review_assignment = create(:assignment, company: organization, title: "Review Item")
      stale_review = create(
        :assignment_check_in,
        :ready_for_finalization,
        teammate: teammate,
        assignment: review_assignment,
        employee_completed_at: reference_time - 4.days,
        manager_completed_at: reference_time - 3.days
      )
      records = [
        eh_item(check_in: asymmetric, name: "Older Side"),
        eh_item(check_in: stale_review, name: "Review Item")
      ]

      stall = described_class.worst_for(records, reference_time: reference_time)
      expect(stall.kind).to eq(:stale_review)
      expect(stall.object_name).to eq("Review Item")
      expect(stall.days).to eq(3)
    end

    it "within a tier picks the longest wait" do
      first = create(
        :assignment_check_in,
        :employee_completed,
        teammate: teammate,
        assignment: create(:assignment, company: organization, title: "A"),
        employee_completed_at: reference_time - 6.days
      )
      second = create(
        :assignment_check_in,
        :manager_completed,
        teammate: teammate,
        assignment: create(:assignment, company: organization, title: "B"),
        manager_completed_at: reference_time - 9.days
      )
      records = [
        eh_item(check_in: first, name: "A"),
        eh_item(check_in: second, name: "B")
      ]

      stall = described_class.worst_for(records, reference_time: reference_time)
      expect(stall.kind).to eq(:asymmetric)
      expect(stall.object_name).to eq("B")
      expect(stall.days).to eq(9)
      expect(stall.waiting_on).to eq(:employee)
    end

    it "ignores finalized check-ins even if EH still points at them" do
      check_in = create(
        :assignment_check_in,
        :officially_completed,
        teammate: teammate,
        assignment: assignment,
        employee_completed_at: reference_time - 10.days,
        manager_completed_at: reference_time - 10.days,
        official_check_in_completed_at: reference_time - 1.day
      )
      records = [eh_item(check_in: check_in)]

      expect(described_class.worst_for(records, reference_time: reference_time)).to be_nil
    end
  end
end
