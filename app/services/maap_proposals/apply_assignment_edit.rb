# frozen_string_literal: true

module MaapProposals
  class ApplyAssignmentEdit
    def self.call(proposal:, decided_by:, version_type:, decision_note: nil)
      new(
        proposal: proposal,
        decided_by: decided_by,
        version_type: version_type,
        decision_note: decision_note
      ).call
    end

    def initialize(proposal:, decided_by:, version_type:, decision_note:)
      @proposal = proposal
      @decided_by = decided_by
      @version_type = version_type.to_s
      @decision_note = decision_note
      @warnings = []
    end

    def call
      return Result.err("Only submitted proposals can be applied") unless @proposal.decidable?
      return Result.err("Only Assignment edit proposals are supported") unless @proposal.proposable_type == "Assignment"
      unless MaapProposal::VERSION_TYPES.include?(@version_type)
        return Result.err("version_type must be fundamental, clarifying, or insignificant")
      end

      assignment = @proposal.proposable
      payload = AssignmentPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: assignment.company)
      return Result.err(errors) if errors.any?

      baseline_payload = AssignmentPayload.from_assignment(assignment).to_h

      form = AssignmentForm.new(assignment)
      form.current_person = @decided_by.person
      form_attrs = {
        title: payload.title,
        tagline: payload.tagline,
        required_activities: payload.required_activities,
        handbook: payload.handbook,
        department_id: payload.department_id,
        version_type: @version_type
      }
      return Result.err(form.errors.full_messages) unless form.validate(form_attrs)

      ApplicationRecord.transaction do
        unless form.save
          raise ApplyFailed.new(Array(form.errors.full_messages).presence || ["Failed to save assignment"])
        end

        assignment = assignment.reload
        replace_outcomes!(assignment, payload)
        replace_ability_milestones!(assignment, payload)
        replace_reliance!(assignment, payload)

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: @version_type,
          baseline_payload: baseline_payload,
          decision_warnings: @warnings
        )
      end

      Result.ok(@proposal.reload)
    rescue ApplyFailed => e
      Result.err(e.messages)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end

    private

    class ApplyFailed < StandardError
      attr_reader :messages

      def initialize(messages)
        @messages = Array(messages)
        super(@messages.join(", "))
      end
    end

    def replace_outcomes!(assignment, payload)
      keep_ids = []

      payload.outcomes.each do |outcome_attrs|
        description = outcome_attrs["description"]
        outcome_type = outcome_attrs["outcome_type"]
        existing = find_existing_outcome(assignment, outcome_attrs["id"])

        if existing
          existing.update!(description: description, outcome_type: outcome_type)
          keep_ids << existing.id
        else
          created = assignment.assignment_outcomes.create!(
            description: description,
            outcome_type: outcome_type
          )
          keep_ids << created.id
        end
      end

      assignment.assignment_outcomes.where.not(id: keep_ids).find_each(&:destroy!)
      assignment.refresh_outcomes_audit_snapshot_column!
    end

    def replace_ability_milestones!(assignment, payload)
      keep_ids = []

      payload.ability_milestones.each do |row|
        ability = Ability.find_by(id: row["ability_id"], company_id: assignment.company_id)
        unless ability
          @warnings << "Skipped ability milestone ability_id=#{row['ability_id']}: ability not found in this company"
          next
        end

        level = row["milestone_level"].to_i
        unless (1..5).cover?(level)
          @warnings << "Skipped ability milestone ability_id=#{row['ability_id']}: milestone_level must be 1-5"
          next
        end

        record = assignment.assignment_abilities.find_or_initialize_by(ability: ability)
        record.milestone_level = level
        record.save!
        keep_ids << record.id
      end

      assignment.assignment_abilities.where.not(id: keep_ids).find_each(&:destroy!)
    end

    def replace_reliance!(assignment, payload)
      applied_consumer_ids = apply_side(
        assignment: assignment,
        desired_ids: payload.consumer_assignment_ids,
        role: :consumer
      )
      applied_supplier_ids = apply_side(
        assignment: assignment,
        desired_ids: payload.supplier_assignment_ids,
        role: :supplier
      )

      # Remove stale consumer links (this assignment as supplier)
      assignment.supplier_supply_relationships
                .where.not(consumer_assignment_id: applied_consumer_ids)
                .find_each(&:destroy!)

      # Remove stale supplier links (this assignment as consumer)
      assignment.consumer_supply_relationships
                .where.not(supplier_assignment_id: applied_supplier_ids)
                .find_each(&:destroy!)
    end

    def apply_side(assignment:, desired_ids:, role:)
      applied = []

      desired_ids.each do |raw_id|
        other = Assignment.find_by(id: raw_id)
        unless other
          @warnings << "Skipped #{role} assignment_id=#{raw_id}: assignment not found"
          next
        end

        if other.id == assignment.id
          @warnings << "Skipped #{role} assignment_id=#{raw_id}: cannot link an assignment to itself"
          next
        end

        unless same_company_hierarchy?(assignment.company, other.company)
          @warnings << "Skipped #{role} assignment_id=#{raw_id}: not in the same company hierarchy"
          next
        end

        relation = if role == :consumer
          AssignmentSupplyRelationship.find_or_initialize_by(
            supplier_assignment: assignment,
            consumer_assignment: other
          )
        else
          AssignmentSupplyRelationship.find_or_initialize_by(
            supplier_assignment: other,
            consumer_assignment: assignment
          )
        end

        begin
          relation.save!
          applied << other.id
        rescue ActiveRecord::RecordInvalid => e
          @warnings << "Skipped #{role} assignment_id=#{raw_id}: #{e.record.errors.full_messages.to_sentence}"
        end
      end

      applied
    end

    def same_company_hierarchy?(company_a, company_b)
      a_ids = company_a.self_and_descendants.map(&:id)
      b_ids = company_b.self_and_descendants.map(&:id)
      a_ids.include?(company_b.id) || b_ids.include?(company_a.id)
    end

    def find_existing_outcome(assignment, raw_id)
      return nil if raw_id.blank?

      assignment.assignment_outcomes.find_by(id: raw_id.to_i)
    end
  end
end
