# frozen_string_literal: true

module Goals
  # After a status filter, keep parent lineage for matching goals so hierarchical
  # views still show draft parents of active children (and vice versa).
  class IncludeAncestorGoals
    def self.expanded_ids(matching:, candidates:)
      new(matching: matching, candidates: candidates).expanded_ids
    end

    def initialize(matching:, candidates:)
      @matching = matching
      @candidates = candidates
    end

    def expanded_ids
      matching_ids = ids_for(@matching)
      return matching_ids if matching_ids.empty?

      candidate_ids = ids_for(@candidates).to_set
      return matching_ids if candidate_ids.empty?

      included = matching_ids.to_set
      queue = matching_ids.dup

      while queue.any?
        child_id = queue.pop
        GoalLink.where(child_id: child_id).pluck(:parent_id).each do |parent_id|
          next unless candidate_ids.include?(parent_id)
          next if included.include?(parent_id)

          included.add(parent_id)
          queue << parent_id
        end
      end

      included.to_a
    end

    private

    def ids_for(scope_or_array)
      if scope_or_array.respond_to?(:unscope)
        scope_or_array.unscope(:order, :includes, :preload, :eager_load, :select).distinct.pluck(:id)
      else
        Array(scope_or_array).map { |goal| goal.respond_to?(:id) ? goal.id : goal }.compact
      end
    end
  end
end
