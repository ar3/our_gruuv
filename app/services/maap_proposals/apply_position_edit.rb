# frozen_string_literal: true

module MaapProposals
  class ApplyPositionEdit
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
      return Result.err("Only Position edit proposals are supported") unless @proposal.edit_kind? && @proposal.proposable_type == "Position"

      position = @proposal.proposable
      payload = PositionPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate_for_apply!(company: position.company)
      return Result.err(errors) if errors.any?

      if payload.position_level_id.present?
        level = PositionLevel.find_by(id: payload.position_level_id)
        return Result.err(["position_level_id is invalid"]) if level.nil?
        unless position.title.position_major_level.position_levels.include?(level)
          return Result.err(["position_level must belong to this title's major level"])
        end
      end

      baseline_payload = PositionPayload.from_position(position).to_h

      ApplicationRecord.transaction do
        position.assign_attributes(
          position_summary: payload.position_summary,
          position_level_id: payload.position_level_id.presence || position.position_level_id
        )
        unless position.save
          raise ApplyFailed.new(position.errors.full_messages.presence || ["Failed to save position"])
        end

        sync_assignment_links!(position, payload)

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: nil,
          baseline_payload: baseline_payload,
          decision_warnings: []
        )
      end

      Result.ok(@proposal.reload)
    rescue ApplyFailed => e
      Result.err(e.messages)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end

    private

    def sync_assignment_links!(position, payload)
      desired = Array(payload.assignment_links).filter_map do |link|
        next if link["assignment_id"].blank?

        link
      end
      desired_ids = desired.map { |link| link["assignment_id"].to_i }

      position.position_assignments.where.not(assignment_id: desired_ids).destroy_all

      desired.each do |link|
        pa = PositionAssignment.find_or_initialize_by(position: position, assignment_id: link["assignment_id"])
        pa.assignment_type = link["assignment_type"].presence || "required"
        if link["energy_percentage"].present?
          energy = link["energy_percentage"].to_i
          pa.min_estimated_energy = energy
          pa.max_estimated_energy = energy
        else
          pa.min_estimated_energy = nil
          pa.max_estimated_energy = nil
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
