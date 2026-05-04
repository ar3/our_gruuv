# frozen_string_literal: true

module PositionAssignments
  # Compares two positions' position_assignments and returns a structured diff.
  #
  # - added:   PositionAssignment rows present on `source` but missing on `destination`
  # - removed: PositionAssignment rows present on `destination` but missing on `source`
  # - changed: hashes with :source and :destination PositionAssignments for the same
  #            assignment that differ in assignment_type, min_estimated_energy, or
  #            max_estimated_energy.
  class Diff
    Result = Struct.new(:added, :removed, :changed, keyword_init: true) do
      def total_count
        added.size + removed.size + changed.size
      end

      def empty?
        total_count.zero?
      end
    end

    def self.call(source:, destination:)
      src = source.position_assignments.includes(:assignment).index_by(&:assignment_id)
      dst = destination.position_assignments.includes(:assignment).index_by(&:assignment_id)

      added = (src.keys - dst.keys).map { |id| src[id] }
      removed = (dst.keys - src.keys).map { |id| dst[id] }
      changed = (src.keys & dst.keys).filter_map do |id|
        next if equivalent?(src[id], dst[id])
        { source: src[id], destination: dst[id] }
      end

      Result.new(added: added, removed: removed, changed: changed)
    end

    def self.equivalent?(a, b)
      a.assignment_type == b.assignment_type &&
        a.min_estimated_energy == b.min_estimated_energy &&
        a.max_estimated_energy == b.max_estimated_energy
    end
  end
end
