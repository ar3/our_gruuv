# frozen_string_literal: true

require "yaml"

module MaapProposals
  class AbilityMarkdownDeserializer
    SECTION_HEADERS = {
      "name" => :name,
      "description" => :description,
      "milestone 1" => :milestone_1_description,
      "milestone 2" => :milestone_2_description,
      "milestone 3" => :milestone_3_description,
      "milestone 4" => :milestone_4_description,
      "milestone 5" => :milestone_5_description
    }.freeze

    def self.call(markdown:, organization:, ability: nil)
      new(markdown: markdown, organization: organization, ability: ability).call
    end

    def initialize(markdown:, organization:, ability:)
      @markdown = markdown.to_s
      @organization = organization
      @ability = ability
    end

    def call
      front_matter, body = split_front_matter(@markdown)
      meta = parse_front_matter(front_matter)
      identity_error = validate_identity(meta)
      return Result.err(identity_error) if identity_error

      sections = parse_sections(body)
      payload = AbilityPayload.from_hash(
        {
          "schema_version" => meta["maap_proposal_schema_version"] || AbilityPayload::SCHEMA_VERSION,
          "name" => sections[:name],
          "description" => sections[:description],
          "department_id" => meta["department_id"],
          "milestone_1_description" => sections[:milestone_1_description],
          "milestone_2_description" => sections[:milestone_2_description],
          "milestone_3_description" => sections[:milestone_3_description],
          "milestone_4_description" => sections[:milestone_4_description],
          "milestone_5_description" => sections[:milestone_5_description]
        }
      )

      errors = payload.validate!(company: @organization)
      return Result.err(errors) if errors.any?

      kind = meta["kind"].presence || (@ability ? "edit" : "create")
      Result.ok(
        payload: payload,
        kind: kind,
        create_key: meta["create_key"].presence,
        based_on_semantic_version: meta["based_on_semantic_version"].presence || @ability&.semantic_version
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
      kind = meta["kind"].to_s.presence || (@ability ? "edit" : "create")
      id = meta["proposable_id"].to_i

      return "proposable_type must be Ability" if type.present? && type != "Ability"

      if kind == "create"
        return "create markdown must not include proposable_id" if id.positive?

        return nil
      end

      return "edit markdown requires an ability context" unless @ability
      return "proposable_id does not match this ability" if id.positive? && id != @ability.id

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
  end
end
