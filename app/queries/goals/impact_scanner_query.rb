# frozen_string_literal: true

module Goals
  # Builds the company-visible goal hierarchy with an advisory descendant confidence
  # distribution (D2 full tree + F3 latest-check-in bands). Does not write parent check-ins.
  #
  # Latest-check-in bands (high / mid / low) are separate from a goal's initial_confidence
  # designation (commit / stretch / transform).
  class ImpactScannerQuery
    HIGH_MIN = 80
    MID_MIN = 50

    BandCounts = Data.define(:high, :mid, :low, :no_check_in) do
      def total
        high + mid + low + no_check_in
      end
    end

    Rollup = Data.define(:bands, :average_confidence, :descendant_count, :checked_in_count)

    def initialize(goals:, current_person:, organization:, sort: "most_likely_target_date", direction: "asc")
      @goals = goals
      @current_person = current_person
      @organization = organization
      @sort = sort
      @direction = direction
    end

    def call
      hierarchy = Goals::HierarchyWithCheckInsQuery.new(
        goals: @goals,
        current_person: @current_person,
        organization: @organization,
        sort: @sort,
        direction: @direction
      ).call

      root_goals = hierarchy[:root_goals].map { |node| enrich_with_rollup(node) }

      {
        root_goals: root_goals,
        parent_child_map: hierarchy[:parent_child_map],
        most_recent_check_ins_by_goal: hierarchy[:most_recent_check_ins_by_goal],
        current_week_check_ins_by_goal: hierarchy[:current_week_check_ins_by_goal]
      }
    end

    def self.latest_confidence_band_for(confidence_percentage)
      return :no_check_in if confidence_percentage.nil?

      pct = confidence_percentage.to_i
      return :high if pct >= HIGH_MIN
      return :mid if pct >= MID_MIN

      :low
    end

    private

    def enrich_with_rollup(node)
      children = (node[:children] || []).map { |child| enrich_with_rollup(child) }
      descendants = flatten_descendants(children)
      percentages = descendants.map { |d| d[:most_recent_check_in]&.confidence_percentage }

      bands = BandCounts.new(
        high: percentages.count { |p| self.class.latest_confidence_band_for(p) == :high },
        mid: percentages.count { |p| self.class.latest_confidence_band_for(p) == :mid },
        low: percentages.count { |p| self.class.latest_confidence_band_for(p) == :low },
        no_check_in: percentages.count { |p| self.class.latest_confidence_band_for(p) == :no_check_in }
      )

      numeric = percentages.compact
      average = if numeric.any?
        (numeric.sum.to_f / numeric.size).round(1)
      end

      node.merge(
        children: children,
        direct_children_count: children.length,
        total_descendants_count: descendants.length,
        confidence_rollup: Rollup.new(
          bands: bands,
          average_confidence: average,
          descendant_count: descendants.length,
          checked_in_count: numeric.size
        )
      )
    end

    def flatten_descendants(children)
      children.flat_map do |child|
        [child] + flatten_descendants(child[:children] || [])
      end
    end
  end
end
