# frozen_string_literal: true

module MaapProposals
  class UpdateAssignmentEditDraft
    def self.call(proposal:, attributes: {}, outcomes: nil, source_markdown: nil)
      new(
        proposal: proposal,
        attributes: attributes,
        outcomes: outcomes,
        source_markdown: source_markdown
      ).call
    end

    def initialize(proposal:, attributes:, outcomes:, source_markdown:)
      @proposal = proposal
      @attributes = attributes
      @outcomes = outcomes
      @source_markdown = source_markdown
    end

    def call
      return Result.err("Only draft proposals can be edited") unless @proposal.editable?
      return Result.err("Only Assignment edit proposals are supported") unless @proposal.proposable_type == "Assignment"

      current = AssignmentPayload.from_hash(@proposal.proposed_payload).to_h
      merged = current.merge(@attributes.deep_stringify_keys.slice(*AssignmentPayload::ATTR_KEYS))
      if @outcomes
        merged["outcomes"] = Array(@outcomes).filter_map do |row|
          hash = row.deep_stringify_keys
          next if hash["description"].to_s.strip.blank?

          hash
        end
      end
      payload = AssignmentPayload.from_hash(merged)

      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      attrs = {
        proposed_payload: payload.to_h,
        content_schema_version: AssignmentPayload::SCHEMA_VERSION
      }
      attrs[:source_markdown] = @source_markdown unless @source_markdown.nil?

      if @proposal.update(attrs)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
