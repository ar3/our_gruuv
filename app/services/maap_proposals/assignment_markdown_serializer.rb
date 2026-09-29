# frozen_string_literal: true

module MaapProposals
  class AssignmentMarkdownSerializer
    def self.call(assignment:, payload:, based_on_semantic_version:)
      new(
        assignment: assignment,
        payload: payload,
        based_on_semantic_version: based_on_semantic_version
      ).call
    end

    def initialize(assignment:, payload:, based_on_semantic_version:)
      @assignment = assignment
      @payload = payload.is_a?(AssignmentPayload) ? payload : AssignmentPayload.from_hash(payload)
      @based_on_semantic_version = based_on_semantic_version
    end

    def call
      [front_matter, body].join("\n")
    end

    private

    def front_matter
      lines = ["---"]
      lines << "maap_proposal_schema_version: #{AssignmentPayload::SCHEMA_VERSION}"
      lines << "proposable_type: Assignment"
      lines << "proposable_id: #{@assignment.id}"
      lines << "based_on_semantic_version: #{yaml_scalar(@based_on_semantic_version)}"
      lines << "department_id: #{yaml_scalar(@payload.department_id)}"
      lines << "---"
      lines.join("\n")
    end

    def body
      parts = []
      parts << "# Title"
      parts << ""
      parts << @payload.title.to_s
      parts << ""
      parts << "## Tagline"
      parts << ""
      parts << (@payload.tagline.to_s)
      parts << ""
      parts << "## Required activities"
      parts << ""
      parts << (@payload.required_activities.to_s)
      parts << ""
      parts << "## Handbook"
      parts << ""
      parts << (@payload.handbook.to_s)
      parts << ""
      parts << "## Outcomes"
      parts << ""

      @payload.outcomes.each do |outcome|
        heading, remainder = split_description(outcome["description"].to_s)
        parts << "### #{heading}"
        parts << ""
        parts << "id: #{yaml_scalar(outcome['id'])}"
        parts << "outcome_type: #{outcome['outcome_type']}"
        if remainder.present?
          parts << ""
          parts << remainder
        end
        parts << ""
      end

      parts << "## Ability milestones"
      parts << ""
      @payload.ability_milestones.each do |row|
        ability = Ability.find_by(id: row["ability_id"])
        name = ability&.name.presence || "Ability #{row['ability_id']}"
        parts << "### #{name}"
        parts << ""
        parts << "ability_id: #{yaml_scalar(row['ability_id'])}"
        parts << "milestone_level: #{yaml_scalar(row['milestone_level'])}"
        parts << ""
      end

      parts << "## Consumer assignments"
      parts << ""
      @payload.consumer_assignment_ids.each do |id|
        asg = Assignment.find_by(id: id)
        parts << "- assignment_id: #{id}"
        parts << "  title: #{yaml_scalar(asg&.title)}"
      end
      parts << ""

      parts << "## Supplier assignments"
      parts << ""
      @payload.supplier_assignment_ids.each do |id|
        asg = Assignment.find_by(id: id)
        parts << "- assignment_id: #{id}"
        parts << "  title: #{yaml_scalar(asg&.title)}"
      end
      parts << ""

      parts.join("\n").rstrip + "\n"
    end

    def split_description(description)
      lines = description.to_s.lines.map(&:rstrip)
      heading = lines.first.to_s.strip
      heading = "Untitled outcome" if heading.blank?
      remainder = lines.drop(1).join("\n").strip
      remainder = nil if remainder.blank?
      [heading, remainder]
    end

    def yaml_scalar(value)
      value.nil? || value.to_s.strip.empty? ? "" : value.to_s
    end
  end
end
