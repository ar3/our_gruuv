# frozen_string_literal: true

module MaapProposals
  # Best-effort outcomes / ability milestones / reliance apply with skip+warnings.
  class AssignmentAssociationsApplier
    def initialize(assignment:, payload:)
      @assignment = assignment
      @payload = payload
      @warnings = []
    end

    def call
      replace_outcomes!
      replace_ability_milestones!
      replace_reliance!
      @warnings
    end

    private

    def replace_outcomes!
      keep_ids = []

      @payload.outcomes.each do |outcome_attrs|
        description = outcome_attrs["description"]
        outcome_type = outcome_attrs["outcome_type"]
        existing = find_existing_outcome(outcome_attrs["id"])

        if existing
          existing.update!(description: description, outcome_type: outcome_type)
          keep_ids << existing.id
        else
          created = @assignment.assignment_outcomes.create!(
            description: description,
            outcome_type: outcome_type
          )
          keep_ids << created.id
        end
      end

      @assignment.assignment_outcomes.where.not(id: keep_ids).find_each(&:destroy!)
      @assignment.refresh_outcomes_audit_snapshot_column!
    end

    def replace_ability_milestones!
      keep_ids = []

      @payload.ability_milestones.each do |row|
        ability = Ability.find_by(id: row["ability_id"], company_id: @assignment.company_id)
        unless ability
          @warnings << "Skipped ability milestone ability_id=#{row['ability_id']}: ability not found in this company"
          next
        end

        level = row["milestone_level"].to_i
        unless (1..5).cover?(level)
          @warnings << "Skipped ability milestone ability_id=#{row['ability_id']}: milestone_level must be 1-5"
          next
        end

        record = @assignment.assignment_abilities.find_or_initialize_by(ability: ability)
        record.milestone_level = level
        record.save!
        keep_ids << record.id
      end

      @assignment.assignment_abilities.where.not(id: keep_ids).find_each(&:destroy!)
    end

    def replace_reliance!
      applied_consumer_ids = apply_side(
        desired_ids: @payload.consumer_assignment_ids,
        role: :consumer
      )
      applied_supplier_ids = apply_side(
        desired_ids: @payload.supplier_assignment_ids,
        role: :supplier
      )

      @assignment.supplier_supply_relationships
                 .where.not(consumer_assignment_id: applied_consumer_ids)
                 .find_each(&:destroy!)

      @assignment.consumer_supply_relationships
                 .where.not(supplier_assignment_id: applied_supplier_ids)
                 .find_each(&:destroy!)
    end

    def apply_side(desired_ids:, role:)
      applied = []

      desired_ids.each do |raw_id|
        other = Assignment.find_by(id: raw_id)
        unless other
          @warnings << "Skipped #{role} assignment_id=#{raw_id}: assignment not found"
          next
        end

        if other.id == @assignment.id
          @warnings << "Skipped #{role} assignment_id=#{raw_id}: cannot link an assignment to itself"
          next
        end

        unless same_company_hierarchy?(@assignment.company, other.company)
          @warnings << "Skipped #{role} assignment_id=#{raw_id}: not in the same company hierarchy"
          next
        end

        relation = if role == :consumer
          AssignmentSupplyRelationship.find_or_initialize_by(
            supplier_assignment: @assignment,
            consumer_assignment: other
          )
        else
          AssignmentSupplyRelationship.find_or_initialize_by(
            supplier_assignment: other,
            consumer_assignment: @assignment
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

    def find_existing_outcome(raw_id)
      return nil if raw_id.blank?

      @assignment.assignment_outcomes.find_by(id: raw_id.to_i)
    end
  end
end
