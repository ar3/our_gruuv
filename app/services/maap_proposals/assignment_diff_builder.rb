# frozen_string_literal: true

module MaapProposals
  # Field-level diffs between a before/after AssignmentPayload (for Diffy HTML).
  # Open proposals: before = live assignment. Decided: before = stored baseline_payload.
  class AssignmentDiffBuilder
    FieldDiff = Data.define(:key, :label, :before, :after, :html)

    SCALAR_FIELDS = [
      [:title, "Title"],
      [:tagline, "Tagline"],
      [:required_activities, "Required activities"],
      [:handbook, "Handbook"]
    ].freeze

    def self.call(before: nil, after: nil, assignment: nil, payload: nil)
      before_payload = coerce_before(before: before, assignment: assignment)
      after_payload = coerce_after(after: after, payload: payload)
      new(before: before_payload, after: after_payload).call
    end

    def self.coerce_before(before:, assignment:)
      return AssignmentPayload.from_assignment(assignment) if before.nil? && assignment
      return before if before.is_a?(AssignmentPayload)
      return AssignmentPayload.from_hash(before) if before.present?

      raise ArgumentError, "before or assignment is required"
    end
    private_class_method :coerce_before

    def self.coerce_after(after:, payload:)
      source = after || payload
      raise ArgumentError, "after or payload is required" if source.nil?
      return source if source.is_a?(AssignmentPayload)

      AssignmentPayload.from_hash(source)
    end
    private_class_method :coerce_after

    def initialize(before:, after:)
      @before = before
      @after = after
    end

    def call
      diffs = []

      SCALAR_FIELDS.each do |key, label|
        before_value = normalize(@before.public_send(key))
        after_value = normalize(@after.public_send(key))
        next if before_value == after_value

        diffs << build_field(key, label, before_value, after_value)
      end

      before_dept = department_label(@before.department_id)
      after_dept = department_label(@after.department_id)
      if before_dept != after_dept
        diffs << build_field(:department, "Department", before_dept, after_dept)
      end

      before_outcomes = outcomes_text(@before.outcomes)
      after_outcomes = outcomes_text(@after.outcomes)
      if before_outcomes != after_outcomes
        diffs << build_field(:outcomes, "Outcomes", before_outcomes, after_outcomes)
      end

      before_abilities = ability_milestones_text(@before.ability_milestones)
      after_abilities = ability_milestones_text(@after.ability_milestones)
      if before_abilities != after_abilities
        diffs << build_field(:ability_milestones, "Ability milestones", before_abilities, after_abilities)
      end

      before_consumers = assignment_ids_text(@before.consumer_assignment_ids, "consumer")
      after_consumers = assignment_ids_text(@after.consumer_assignment_ids, "consumer")
      if before_consumers != after_consumers
        diffs << build_field(:consumer_assignments, "Consumer assignments", before_consumers, after_consumers)
      end

      before_suppliers = assignment_ids_text(@before.supplier_assignment_ids, "supplier")
      after_suppliers = assignment_ids_text(@after.supplier_assignment_ids, "supplier")
      if before_suppliers != after_suppliers
        diffs << build_field(:supplier_assignments, "Supplier assignments", before_suppliers, after_suppliers)
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

    def ability_milestones_text(rows)
      Array(rows).map do |row|
        ability = Ability.find_by(id: row["ability_id"])
        name = ability&.name || "ability #{row['ability_id']}"
        "ability_id: #{row['ability_id']} (#{name}) milestone_level: #{row['milestone_level']}"
      end.join("\n")
    end

    def assignment_ids_text(ids, role)
      Array(ids).map do |id|
        asg = Assignment.find_by(id: id)
        title = asg&.title || "missing"
        "#{role}_assignment_id: #{id} (#{title})"
      end.join("\n")
    end
  end
end
