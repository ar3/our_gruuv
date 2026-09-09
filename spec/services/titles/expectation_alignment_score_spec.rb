# frozen_string_literal: true

require "rails_helper"

RSpec.describe Titles::ExpectationAlignmentScore do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: organization, position_major_level: major_level, external_title: "Engineer") }
  let(:viewer) { create(:teammate, :assigned_employee, organization: organization, can_manage_maap: true) }
  let(:reference_time) { Time.zone.parse("2026-09-09 12:00:00") }
  let!(:level_1) { create(:position_level, position_major_level: major_level, level: "1.1") }
  let!(:level_2) { create(:position_level, position_major_level: major_level, level: "1.2") }
  let!(:level_3) { create(:position_level, position_major_level: major_level, level: "1.3") }

  def create_full_position_eas(position)
    assignment = create(:assignment, company: organization, title: "Ready #{position.id}")
    create(:position_assignment, :required, position: position, assignment: assignment)
    create(:assignment_outcome, assignment: assignment)
    person = create(:person)
    2.times do
      create(:assignment_ability,
             assignment: assignment,
             ability: create(:ability, company: organization, created_by: person, updated_by: person),
             milestone_level: 2)
    end
    Positions::ExpectationAlignmentScore.recalculate!(position: position, reference_time: reference_time)
  end

  describe ".recalculate!" do
    it "scores path clarity and each L1–L3 position EAS at 25 points" do
      title.update!(end_cap: true)
      p1 = create(:position, title: title, position_level: level_1)
      p2 = create(:position, title: title, position_level: level_2)
      p3 = create(:position, title: title, position_level: level_3)
      create_full_position_eas(p1)
      create_full_position_eas(p2)
      create_full_position_eas(p3)

      record = described_class.recalculate!(title: title, reference_time: reference_time, refresh_positions: false)

      expect(record.path_clarity).to be(true)
      expect(record.score.to_f).to eq(100.0)
      expect(record.cells.size).to eq(4)
    end

    it "gives 0 for path clarity without end-cap or outbound paths" do
      create(:position, title: title, position_level: level_1)

      record = described_class.recalculate!(title: title, reference_time: reference_time, refresh_positions: true)

      path_cell = record.cells.find { |c| c["key"] == "path_clarity" }
      expect(path_cell["contribution"]).to eq(0.0)
      expect(record.path_clarity).to be(false)
    end

    it "gives 0 for a missing minor level" do
      title.update!(end_cap: true)
      p1 = create(:position, title: title, position_level: level_1)
      create_full_position_eas(p1)

      record = described_class.recalculate!(title: title, reference_time: reference_time, refresh_positions: false)

      expect(record.score.to_f).to eq(50.0) # path 25 + L1 25 + L2 0 + L3 0
      level_2_cell = record.cells.find { |c| c["key"] == "level_2" }
      expect(level_2_cell["blocker"]).to eq("missing_position")
      expect(level_2_cell["contribution"]).to eq(0.0)
    end

    it "awards path clarity for outbound paths" do
      other = create(:title, company: organization, position_major_level: major_level, external_title: "Manager")
      create(:title_path, from_title: title, to_title: other, path_type: "natural_progression")

      record = described_class.recalculate!(title: title, reference_time: reference_time, refresh_positions: false)

      expect(record.path_clarity).to be(true)
      expect(record.cells.find { |c| c["key"] == "path_clarity" }["contribution"]).to eq(25.0)
    end

    it "synchronously refreshes position EAS when refresh_positions is true" do
      p1 = create(:position, title: title, position_level: level_1)
      assignment = create(:assignment, company: organization, title: "Later")
      create(:position_assignment, :required, position: p1, assignment: assignment)
      create(:assignment_outcome, assignment: assignment)
      person = create(:person)
      2.times do
        create(:assignment_ability,
               assignment: assignment,
               ability: create(:ability, company: organization, created_by: person, updated_by: person),
               milestone_level: 2)
      end

      expect(p1.expectation_alignment_score_cache).to be_nil

      described_class.recalculate!(title: title, reference_time: reference_time, refresh_positions: true)

      expect(p1.reload.expectation_alignment_score_cache.score.to_f).to eq(100.0)
    end
  end
end
