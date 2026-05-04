# frozen_string_literal: true

module PositionAssignments
  # Replaces destination's position_assignments with copies mirroring the source's
  # (assignment, assignment_type, min/max energy), then bumps the destination's
  # paper trail version via Position#record_version_for_assignment_changes!.
  #
  # Wrapped in a transaction so a partial failure rolls back to the prior state.
  class CopyConfiguration
    def self.call(source:, destination:, change_context: nil)
      raise ArgumentError, 'source and destination must be different positions' if source.id == destination.id

      ActiveRecord::Base.transaction do
        destination.position_assignments.destroy_all

        source.position_assignments.find_each do |pa|
          destination.position_assignments.create!(
            assignment_id: pa.assignment_id,
            assignment_type: pa.assignment_type,
            min_estimated_energy: pa.min_estimated_energy,
            max_estimated_energy: pa.max_estimated_energy
          )
        end

        destination.reload.record_version_for_assignment_changes!(
          change_context: change_context || "Copied position assignments from #{source.display_name}"
        )
      end

      destination
    end
  end
end
