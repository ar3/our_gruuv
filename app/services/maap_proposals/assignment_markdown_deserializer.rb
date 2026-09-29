# frozen_string_literal: true

require "yaml"

module MaapProposals
  class AssignmentMarkdownDeserializer
    SECTION_HEADERS = {
      "title" => :title,
      "tagline" => :tagline,
      "required activities" => :required_activities,
      "handbook" => :handbook,
      "outcomes" => :outcomes,
      "ability milestones" => :ability_milestones,
      "consumer assignments" => :consumer_assignments,
      "supplier assignments" => :supplier_assignments
    }.freeze

    def self.call(markdown:, organization:, assignment: nil)
      new(markdown: markdown, organization: organization, assignment: assignment).call
    end

    def initialize(markdown:, organization:, assignment:)
      @markdown = markdown.to_s
      @organization = organization
      @assignment = assignment
    end

    def call
      front_matter, body = split_front_matter(@markdown)
      meta = parse_front_matter(front_matter)
      identity_error = validate_identity(meta)
      return Result.err(identity_error) if identity_error

      sections = parse_sections(body)
      outcomes_result = parse_outcomes(sections[:outcomes].to_s)
      return outcomes_result unless outcomes_result.ok?

      abilities_result = parse_ability_milestones(sections[:ability_milestones].to_s)
      return abilities_result unless abilities_result.ok?

      payload = AssignmentPayload.from_hash(
        {
          "schema_version" => meta["maap_proposal_schema_version"] || AssignmentPayload::SCHEMA_VERSION,
          "title" => sections[:title],
          "tagline" => sections[:tagline],
          "required_activities" => sections[:required_activities],
          "handbook" => sections[:handbook],
          "department_id" => meta["department_id"],
          "outcomes" => outcomes_result.value,
          "ability_milestones" => abilities_result.value,
          "consumer_assignment_ids" => parse_assignment_id_list(sections[:consumer_assignments].to_s),
          "supplier_assignment_ids" => parse_assignment_id_list(sections[:supplier_assignments].to_s)
        }
      )

      errors = payload.validate!(company: @organization)
      return Result.err(errors) if errors.any?

      kind = meta["kind"].presence || (@assignment ? "edit" : "create")
      Result.ok(
        payload: payload,
        kind: kind,
        create_key: meta["create_key"].presence,
        based_on_semantic_version: meta["based_on_semantic_version"].presence || @assignment&.semantic_version
      )
    rescue Psych::SyntaxError => e
      Result.err("Invalid YAML front matter: #{e.message}")
    end

    private

    def split_front_matter(text)
      if text.start_with?("---")
        parts = text.split(/^---\s*$/, 3)
        return [parts[1].to_s, parts[2].to_s] if parts.length >= 3
      end

      ["", text]
    end

    def parse_front_matter(raw)
      return {} if raw.strip.empty?

      parsed = YAML.safe_load(raw, permitted_classes: [Date, Time], aliases: false)
      (parsed || {}).deep_stringify_keys
    end

    def validate_identity(meta)
      type = meta["proposable_type"].to_s
      kind = meta["kind"].to_s.presence || (@assignment ? "edit" : "create")
      id = meta["proposable_id"].to_i

      return "proposable_type must be Assignment" if type.present? && type != "Assignment"

      if kind == "create"
        return "create markdown must not include proposable_id" if id.positive?
        return nil
      end

      return "edit markdown requires an assignment context" unless @assignment
      return "proposable_id does not match this assignment" if id.positive? && id != @assignment.id

      nil
    end

    def parse_sections(body)
      sections = SECTION_HEADERS.values.index_with { nil }
      current = nil
      buffer = []

      flush = lambda do
        return if current.nil?

        sections[current] = buffer.join("\n").strip
        buffer = []
      end

      body.each_line do |line|
        header = line.strip.sub(/\A\#{1,3}\s+/, "").downcase
        if line.strip.match?(/\A\#{1,3}\s+/) && SECTION_HEADERS.key?(header)
          flush.call
          current = SECTION_HEADERS[header]
          next
        end

        buffer << line.rstrip if current
      end
      flush.call

      sections
    end

    def parse_outcomes(raw)
      return Result.ok([]) if raw.strip.empty?

      blocks = raw.split(/^###\s+/).drop(1)
      outcomes = blocks.filter_map do |block|
        lines = block.lines.map(&:rstrip)
        heading = lines.shift.to_s.strip
        next if heading.blank?

        meta = { "id" => nil, "outcome_type" => "quantitative" }
        body_lines = []
        lines.each do |line|
          if body_lines.empty? && line.match?(/\A(id|outcome_type):\s*/)
            key, value = line.split(":", 2)
            meta[key.strip] = value.to_s.strip.presence
          elsif line.strip.present? || body_lines.any?
            body_lines << line
          end
        end

        description = [heading, body_lines.join("\n").strip.presence].compact.join("\n").strip

        {
          "id" => meta["id"],
          "description" => description,
          "outcome_type" => meta["outcome_type"] || "quantitative"
        }
      end

      Result.ok(outcomes)
    end

    def parse_ability_milestones(raw)
      return Result.ok([]) if raw.strip.empty?

      blocks = raw.split(/^###\s+/).drop(1)
      milestones = blocks.filter_map do |block|
        lines = block.lines.map(&:rstrip)
        lines.shift # heading / name commentary
        meta = { "ability_id" => nil, "milestone_level" => nil }
        lines.each do |line|
          next unless line.match?(/\A(ability_id|milestone_level):\s*/)

          key, value = line.split(":", 2)
          meta[key.strip] = value.to_s.strip.presence
        end
        next if meta["ability_id"].blank?

        meta
      end

      Result.ok(milestones)
    end

    def parse_assignment_id_list(raw)
      return [] if raw.strip.empty?

      raw.each_line.filter_map do |line|
        match = line.strip.match(/\A-?\s*assignment_id:\s*(\d+)\z/)
        match && match[1].to_i
      end.uniq
    end
  end
end
