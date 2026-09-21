# frozen_string_literal: true

module Assignments
  # Syncs AssignmentSupplyRelationship edges from manage-reliance association params
  # (direction: upstream|downstream|none per other assignment).
  #
  # Upstream  = other supplies this assignment (other → this)
  # Downstream = this assignment supplies other (this → other)
  class RelianceManager
    Result = Struct.new(:ok?, :error, keyword_init: true)
    DIRECTIONS = %w[upstream downstream].freeze

    def self.call(assignment:, associations:)
      new(assignment: assignment, associations: associations).call
    end

    def initialize(assignment:, associations:)
      @assignment = assignment
      @associations = associations || {}
    end

    def call
      AssignmentSupplyRelationship.transaction do
        keep_ids = []

        associations.each do |other_assignment_id, attrs|
          attrs = attrs.to_h.with_indifferent_access
          direction = attrs[:direction].to_s
          next if direction.blank? || direction == "none"
          next unless DIRECTIONS.include?(direction)

          other = find_other_assignment(other_assignment_id)
          next unless other

          relationship = upsert_relationship!(other: other, direction: direction)
          keep_ids << relationship.id
        end

        involving_relationships.where.not(id: keep_ids).find_each(&:destroy!)
      end

      Result.new(ok?: true)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(ok?: false, error: e.record.errors.full_messages.to_sentence.presence || e.message)
    rescue StandardError => e
      Result.new(ok?: false, error: e.message)
    end

    private

    attr_reader :assignment, :associations

    def involving_relationships
      AssignmentSupplyRelationship
        .where(supplier_assignment_id: assignment.id)
        .or(AssignmentSupplyRelationship.where(consumer_assignment_id: assignment.id))
    end

    def find_other_assignment(other_assignment_id)
      company_hierarchy_ids = assignment.company.self_and_descendants.map(&:id)
      Assignment.unarchived
                .where(company_id: company_hierarchy_ids)
                .where.not(id: assignment.id)
                .find_by(id: other_assignment_id)
    end

    def upsert_relationship!(other:, direction:)
      if direction == "downstream"
        # This assignment supplies other (outgoing / consumer of this)
        AssignmentSupplyRelationship
          .where(supplier_assignment_id: other.id, consumer_assignment_id: assignment.id)
          .destroy_all
        relationship = AssignmentSupplyRelationship.find_or_initialize_by(
          supplier_assignment: assignment,
          consumer_assignment: other
        )
      else
        # Other supplies this assignment (incoming / supplier to this)
        AssignmentSupplyRelationship
          .where(supplier_assignment_id: assignment.id, consumer_assignment_id: other.id)
          .destroy_all
        relationship = AssignmentSupplyRelationship.find_or_initialize_by(
          supplier_assignment: other,
          consumer_assignment: assignment
        )
      end

      relationship.save!
      relationship
    end
  end
end
