# frozen_string_literal: true

module MaapProposals
  class AbilityMarkdownSerializer
    def self.call(ability:, payload:, based_on_semantic_version:)
      new(
        ability: ability,
        payload: payload,
        based_on_semantic_version: based_on_semantic_version
      ).call
    end

    def initialize(ability:, payload:, based_on_semantic_version:)
      @ability = ability
      @payload = payload.is_a?(AbilityPayload) ? payload : AbilityPayload.from_hash(payload)
      @based_on_semantic_version = based_on_semantic_version
    end

    def call
      [front_matter, body].join("\n")
    end

    private

    def front_matter
      lines = ["---"]
      lines << "maap_proposal_schema_version: #{AbilityPayload::SCHEMA_VERSION}"
      lines << "proposable_type: Ability"
      lines << "proposable_id: #{@ability.id}"
      lines << "kind: edit"
      lines << "based_on_semantic_version: #{yaml_scalar(@based_on_semantic_version)}"
      lines << "department_id: #{yaml_scalar(@payload.department_id)}"
      lines << "---"
      lines.join("\n")
    end

    def body
      parts = []
      parts << "# Name"
      parts << ""
      parts << @payload.name.to_s
      parts << ""
      parts << "## Description"
      parts << ""
      parts << @payload.description.to_s
      parts << ""

      (1..5).each do |level|
        parts << "## Milestone #{level}"
        parts << ""
        parts << @payload.public_send("milestone_#{level}_description").to_s
        parts << ""
      end

      parts.join("\n").rstrip + "\n"
    end

    def yaml_scalar(value)
      value.nil? || value.to_s.strip.empty? ? "" : value.to_s
    end
  end
end
