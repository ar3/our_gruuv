# frozen_string_literal: true

module MaapProposals
  # Field-level diffs between live Assignment and a proposal payload (for Diffy HTML).
  class AssignmentDiffBuilder
    FieldDiff = Data.define(:key, :label, :before, :after, :html)

    SCALAR_FIELDS = [
      [:title, "Title"],
      [:tagline, "Tagline"],
      [:required_activities, "Required activities"],
      [:handbook, "Handbook"]
    ].freeze

    def self.call(assignment:, payload:)
      new(assignment: assignment, payload: payload).call
    end

    def initialize(assignment:, payload:)
      @assignment = assignment
      @payload = payload.is_a?(AssignmentPayload) ? payload : AssignmentPayload.from_hash(payload)
      @live = AssignmentPayload.from_assignment(assignment)
    end

    def call
      diffs = []

      SCALAR_FIELDS.each do |key, label|
        before = normalize(@live.public_send(key))
        after = normalize(@payload.public_send(key))
        next if before == after

        diffs << build_field(key, label, before, after)
      end

      before_dept = department_label(@live.department_id)
      after_dept = department_label(@payload.department_id)
      if before_dept != after_dept
        diffs << build_field(:department, "Department", before_dept, after_dept)
      end

      before_outcomes = outcomes_text(@live.outcomes)
      after_outcomes = outcomes_text(@payload.outcomes)
      if before_outcomes != after_outcomes
        diffs << build_field(:outcomes, "Outcomes", before_outcomes, after_outcomes)
      end

      diffs
    end

    private

    def build_field(key, label, before, after)
      html = Diffy::Diff.new(
        before,
        after,
        include_plus_and_minus_in_html: true,
        allow_empty_diff: false
      ).to_s(:html)

      FieldDiff.new(key: key, label: label, before: before, after: after, html: html)
    end

    def normalize(value)
      value.nil? ? "" : value.to_s
    end

    def department_label(department_id)
      return "" if department_id.blank?

      Department.find_by(id: department_id)&.name.to_s
    end

    def outcomes_text(outcomes)
      Array(outcomes).map do |outcome|
        [
          "id: #{outcome['id']}",
          outcome["description"].to_s,
          "outcome_type: #{outcome['outcome_type']}"
        ].join("\n")
      end.join("\n\n")
    end
  end
end
