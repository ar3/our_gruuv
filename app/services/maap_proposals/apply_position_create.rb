# frozen_string_literal: true

module MaapProposals
  class ApplyPositionCreate
    def self.call(proposal:, decided_by:, decision_note: nil)
      new(proposal: proposal, decided_by: decided_by, decision_note: decision_note).call
    end

    def initialize(proposal:, decided_by:, decision_note:)
      @proposal = proposal
      @decided_by = decided_by
      @decision_note = decision_note
    end

    def call
      return Result.err("Only submitted proposals can be applied") unless @proposal.decidable?
      return Result.err("Only Position create proposals are supported") unless @proposal.position_create?

      payload = PositionPayload.from_hash(@proposal.proposed_payload)
      if payload.title_id.blank? && payload.title_proposal_id.present?
        title_proposal = MaapProposal.find_by(id: payload.title_proposal_id)
        if title_proposal&.applied? && title_proposal.proposable.is_a?(Title)
          payload = PositionPayload.from_hash(payload.to_h.merge("title_id" => title_proposal.proposable_id))
        end
      end

      errors = payload.validate_for_apply!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      title = Title.find(payload.title_id)
      level = resolve_position_level(title, payload)
      return Result.err(["Could not resolve a level-1 position level for this title"]) if level.nil?

      position = nil
      ApplicationRecord.transaction do
        position = Position.find_or_initialize_by(title: title, position_level: level)
        position.position_summary = payload.position_summary if payload.position_summary.present?
        unless position.save
          raise ApplyFailed, position.errors.full_messages
        end

        attach_assignments!(position, payload)

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: nil,
          baseline_payload: {},
          decision_warnings: [],
          proposable: position
        )
      end

      Result.ok(@proposal.reload)
    rescue ApplyFailed => e
      Result.err(e.messages)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end

    private

    def resolve_position_level(title, payload)
      return PositionLevel.find_by(id: payload.position_level_id) if payload.position_level_id.present?

      major = title.position_major_level
      hint = payload.position_level_hint.to_s
      major.position_levels.find { |pl| pl.level.to_s == hint } ||
        major.position_levels.find { |pl| pl.level.to_s.start_with?("1") } ||
        major.position_levels.order(:level).first ||
        PositionLevel.create!(position_major_level: major, level: hint.presence || "1.1")
    end

    def attach_assignments!(position, payload)
      Array(payload.assignment_links).each do |link|
        assignment_id = link["assignment_id"]
        if assignment_id.blank? && link["assignment_proposal_id"].present?
          child = MaapProposal.find_by(id: link["assignment_proposal_id"])
          assignment_id = child.proposable_id if child&.applied? && child.proposable.is_a?(Assignment)
        end
        next if assignment_id.blank?

        pa = PositionAssignment.find_or_initialize_by(position: position, assignment_id: assignment_id)
        pa.assignment_type = link["assignment_type"].presence || "required"
        if link["energy_percentage"].present?
          energy = link["energy_percentage"].to_i
          pa.min_estimated_energy = energy
          pa.max_estimated_energy = energy
        end
        pa.save!
      end
    end

    class ApplyFailed < StandardError
      attr_reader :messages

      def initialize(messages)
        @messages = Array(messages)
        super(@messages.join(", "))
      end
    end
  end
end
