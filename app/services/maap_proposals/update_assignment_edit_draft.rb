# frozen_string_literal: true

module MaapProposals
  class UpdateAssignmentEditDraft
    def self.call(
      proposal:,
      attributes: {},
      outcomes: nil,
      ability_milestones: nil,
      consumer_assignment_ids: nil,
      supplier_assignment_ids: nil,
      source_markdown: nil
    )
      new(
        proposal: proposal,
        attributes: attributes,
        outcomes: outcomes,
        ability_milestones: ability_milestones,
        consumer_assignment_ids: consumer_assignment_ids,
        supplier_assignment_ids: supplier_assignment_ids,
        source_markdown: source_markdown
      ).call
    end

    def initialize(
      proposal:,
      attributes:,
      outcomes:,
      ability_milestones:,
      consumer_assignment_ids:,
      supplier_assignment_ids:,
      source_markdown:
    )
      @proposal = proposal
      @attributes = attributes
      @outcomes = outcomes
      @ability_milestones = ability_milestones
      @consumer_assignment_ids = consumer_assignment_ids
      @supplier_assignment_ids = supplier_assignment_ids
      @source_markdown = source_markdown
    end

    def call
      return Result.err("Only draft proposals can be edited") unless @proposal.editable?
      unless @proposal.proposable_type == "Assignment" || @proposal.create_kind?
        return Result.err("Only Assignment proposals are supported")
      end

      current = AssignmentPayload.from_hash(@proposal.proposed_payload).to_h
      merged = current.merge(@attributes.deep_stringify_keys.slice(*AssignmentPayload::ATTR_KEYS))
      if @outcomes
        merged["outcomes"] = Array(@outcomes).filter_map do |row|
          hash = row.deep_stringify_keys
          next if hash["description"].to_s.strip.blank?

          hash
        end
      end
      if @ability_milestones
        merged["ability_milestones"] = Array(@ability_milestones).filter_map do |row|
          hash = row.deep_stringify_keys
          next if hash["ability_id"].to_s.strip.blank?

          hash
        end
      end
      merged["consumer_assignment_ids"] = Array(@consumer_assignment_ids) unless @consumer_assignment_ids.nil?
      merged["supplier_assignment_ids"] = Array(@supplier_assignment_ids) unless @supplier_assignment_ids.nil?

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
