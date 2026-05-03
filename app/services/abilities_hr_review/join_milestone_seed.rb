# frozen_string_literal: true

module AbilitiesHrReview
  # Seeds join AssignmentAbility#milestone_level: Ability milestone CSV column → proposer → default 1.
  class JoinMilestoneSeed
    def self.call(assignment:, ability_milestone_cell:)
      new(assignment: assignment, ability_milestone_cell: ability_milestone_cell).call
    end

    def initialize(assignment:, ability_milestone_cell:)
      @assignment = assignment
      @ability_milestone_cell = ability_milestone_cell
    end

    def call
      from_csv = parse_csv_milestone(@ability_milestone_cell)
      return { 'level' => from_csv, 'proposed_level' => nil, 'rationale' => nil } if from_csv

      unless @assignment
        return { 'level' => 1, 'proposed_level' => nil, 'rationale' => nil }
      end

      proposed = MilestoneProposer.call(assignment: @assignment)
      level = proposed['level'].presence&.to_i
      level = nil unless level && (1..5).cover?(level)

      draft = level || 1
      {
        'level' => draft,
        'proposed_level' => proposed['level'],
        'rationale' => proposed['rationale']
      }
    end

    private

    def parse_csv_milestone(value)
      s = value.to_s.strip
      return nil if s.blank?

      n = s[/\A(\d)\z/, 1]&.to_i || s[/milestone\s*(\d)/i, 1]&.to_i
      return n if n && (1..5).cover?(n)

      nil
    end
  end
end
