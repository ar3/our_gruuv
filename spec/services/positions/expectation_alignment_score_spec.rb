# frozen_string_literal: true

require "rails_helper"

RSpec.describe Positions::ExpectationAlignmentScore do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:viewer) { create(:teammate, :assigned_employee, organization: organization, can_manage_maap: true) }
  let(:reference_time) { Time.zone.parse("2026-09-09 12:00:00") }

  def create_required_assignment(assignment_title:)
    assignment = create(:assignment, company: organization, title: assignment_title)
    create(:position_assignment, :required, position: position, assignment: assignment)
    assignment
  end

  describe ".recalculate!" do
    it "scores 0 when there are no required assignments" do
      create(:position_assignment, :suggested,
             position: position,
             assignment: create(:assignment, company: organization, title: "Suggested Only"))

      record = described_class.recalculate!(position: position, reference_time: reference_time)

      expect(record.score.to_f).to eq(0.0)
      expect(record.required_assignments_count).to eq(0)
      expect(record.cells).to eq([])
    end

    it "scores 0 for a required assignment with abilities but no outcomes" do
      assignment = create_required_assignment(assignment_title: "No Outcomes")
      ability = create(:ability, company: organization, created_by: viewer.person, updated_by: viewer.person)
      create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
      create(:assignment_ability,
             assignment: assignment,
             ability: create(:ability, company: organization, created_by: viewer.person, updated_by: viewer.person),
             milestone_level: 1)

      record = described_class.recalculate!(position: position, reference_time: reference_time)

      expect(record.score.to_f).to eq(0.0)
      expect(record.cells.first["blocker"]).to eq("missing_outcomes")
      expect(record.cells.first["completeness_pct"]).to eq(0)
    end

    it "averages equal weights across required assignments using 0/50/100 ability completeness" do
      full = create_required_assignment(assignment_title: "Full")
      create(:assignment_outcome, assignment: full)
      2.times do
        create(:assignment_ability,
               assignment: full,
               ability: create(:ability, company: organization, created_by: viewer.person, updated_by: viewer.person),
               milestone_level: 2)
      end

      partial = create_required_assignment(assignment_title: "Partial")
      create(:assignment_outcome, assignment: partial)
      create(:assignment_ability,
             assignment: partial,
             ability: create(:ability, company: organization, created_by: viewer.person, updated_by: viewer.person),
             milestone_level: 1)

      record = described_class.recalculate!(position: position, reference_time: reference_time)

      expect(record.score.to_f).to eq(75.0)
      expect(record.required_assignments_count).to eq(2)
      expect(record.cells.map { |c| c["completeness_pct"] }).to contain_exactly(100, 50)
    end

    it "ignores PositionAbility rows when scoring" do
      assignment = create_required_assignment(assignment_title: "Outcomes only")
      create(:assignment_outcome, assignment: assignment)
      create(:position_ability,
             position: position,
             ability: create(:ability, company: organization, created_by: viewer.person, updated_by: viewer.person),
             milestone_level: 3)
      create(:position_ability,
             position: position,
             ability: create(:ability, company: organization, created_by: viewer.person, updated_by: viewer.person),
             milestone_level: 2)

      record = described_class.recalculate!(position: position, reference_time: reference_time)

      expect(record.score.to_f).to eq(0.0)
      expect(record.cells.first["abilities_count"]).to eq(0)
      expect(record.cells.first["blocker"]).to eq("missing_abilities")
    end
  end

  describe ".for_viewer" do
    it "shows the card to everyone and refresh only to MAAP managers" do
      described_class.recalculate!(position: position, reference_time: reference_time)
      regular = create(:teammate, :assigned_employee, organization: organization, can_manage_maap: false)

      privileged = described_class.for_viewer(
        position: position,
        viewer: viewer,
        organization: organization
      )
      public_view = described_class.for_viewer(
        position: position,
        viewer: regular,
        organization: organization
      )

      expect(privileged.show_card?).to be(true)
      expect(privileged.can_refresh?).to be(true)
      expect(privileged.can_see_score?).to be(true)
      expect(public_view.show_card?).to be(true)
      expect(public_view.can_refresh?).to be(false)
      expect(public_view.can_see_score?).to be(true)
    end
  end
end
