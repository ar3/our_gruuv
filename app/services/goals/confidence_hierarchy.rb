# frozen_string_literal: true

module Goals
  # Confidence overview aggregates + confidence hierarchy tree rows for a filtered
  # goal set. Primary parent = lowest parent id among parents in the set.
  class ConfidenceHierarchy
    TOLERANCE = 5
    Agreement = Data.define(:state, :child_avg, :child_min, :child_max, :child_count, :own)

    Aggregates = Data.define(
      :checked_count,
      :goal_count_below_roots,
      :least_confident,
      :least_confident_tie_count,
      :average_confidence,
      :biggest_drop,
      :age_buckets,
      :agreement_counts,
      :dots,
      :empty
    )

    TreeRow = Data.define(
      :goal,
      :depth,
      :leaf,
      :parent_count,
      :own_percentage,
      :arrow,
      :age_bucket,
      :age_label,
      :agreement,
      :first_check_in,
      :latest_check_in,
      :section_root,
      :descendants_count,
      :direct_children_count,
      :active_descendants_count,
      :active_direct_children_count
    )

    def initialize(goals:, as_of: Date.current, root_goal_ids: nil)
      @goals = goals.to_a
      @goals_by_id = @goals.index_by(&:id)
      @goal_ids = @goals_by_id.keys.to_set
      @as_of = as_of
      @forced_root_ids = Array(root_goal_ids).map(&:to_i).presence
      preload_links_and_check_ins!
    end

    def aggregates
      roots = root_goals
      root_id_set = roots.map(&:id).to_set
      below = @goals.reject { |g| root_id_set.include?(g.id) }
      checked = below.select { |g| own(g) }

      least = checked.map { |g| own(g) }.min
      least_tie = least.nil? ? 0 : checked.count { |g| own(g) == least }
      avg = mean(checked.map { |g| own(g) })

      drops = checked.filter_map do |g|
        delta = confidence_delta(g)
        delta if delta&.negative?
      end
      biggest_drop = drops.min

      age_buckets = { fresh: 0, aging: 0, stale: 0, never: 0 }
      checked.each do |g|
        age_buckets[ConfidenceAge.bucket(latest_check_in(g), as_of: @as_of)] += 1
      end

      agreement_counts = Hash.new(0)
      nodes_for_agreement = roots + below
      nodes_for_agreement.each { |g| agreement_counts[agreement(g).state] += 1 }

      Aggregates.new(
        checked_count: checked.size,
        goal_count_below_roots: below.size,
        least_confident: least,
        least_confident_tie_count: least_tie,
        average_confidence: avg,
        biggest_drop: biggest_drop,
        age_buckets: age_buckets,
        agreement_counts: agreement_counts,
        dots: build_dots(checked),
        empty: checked.empty?
      )
    end

    def tree_rows
      rows = []
      root_goals.each do |root|
        rows << build_row(root, depth: 0, section_root: true)
        append_children_rows(rows, root, depth: 1)
      end
      rows
    end

    def root_goals
      if @forced_root_ids
        @forced_root_ids.filter_map { |id| @goals_by_id[id] }
      else
        @goals.select { |g| parents_in_set(g).empty? }.sort_by(&:id)
      end
    end

    def own(goal)
      latest_check_in(goal)&.confidence_percentage
    end

    def latest_check_in(goal)
      @latest_by_goal[goal.id]
    end

    def first_check_in(goal)
      @first_by_goal[goal.id]
    end

    def confidence_delta(goal)
      first = first_check_in(goal)
      last = latest_check_in(goal)
      return nil unless first && last && first.id != last.id
      return nil if first.confidence_percentage.nil? || last.confidence_percentage.nil?

      last.confidence_percentage - first.confidence_percentage
    end

    def arrow(goal)
      delta = confidence_delta(goal)
      return :none if delta.nil?
      return :up if delta.positive?
      return :down if delta.negative?

      :flat
    end

    def checks_under(goal, seen = Set.new)
      results = []
      walk_descendants(goal, seen) do |child|
        results << child if own(child)
      end
      results
    end

    def child_values(goal)
      children_of(goal).filter_map do |child|
        own(child) || mean(checks_under(child).map { |c| own(c) })
      end
    end

    def agreement(goal)
      vals = child_values(goal)
      if vals.empty?
        return Agreement.new(state: :none, child_avg: nil, child_min: nil, child_max: nil, child_count: 0, own: own(goal))
      end

      avg = mean(vals)
      own_val = own(goal)
      if own_val.nil?
        return Agreement.new(
          state: :no_check,
          child_avg: avg,
          child_min: vals.min,
          child_max: vals.max,
          child_count: vals.size,
          own: nil
        )
      end

      diff = own_val - avg
      state =
        if diff.abs <= TOLERANCE
          :in_step
        elsif diff.negative?
          :should_be_higher
        else
          :should_be_lower
        end

      Agreement.new(
        state: state,
        child_avg: avg,
        child_min: vals.min,
        child_max: vals.max,
        child_count: vals.size,
        own: own_val
      )
    end

    def parents_in_set(goal)
      (@parents_by_child[goal.id] || []).filter_map { |id| @goals_by_id[id] }.sort_by(&:id)
    end

    def primary_parent(goal)
      parents_in_set(goal).first
    end

    def children_of(goal)
      (@children_by_parent[goal.id] || []).filter_map { |id| @goals_by_id[id] }
        .select { |child| primary_parent(child)&.id == goal.id || parents_in_set(child).empty? }
        .sort_by(&:id)
    end

    def row_for(goal, depth:, section_root: false)
      build_row(goal, depth: depth, section_root: section_root)
    end

    private

    def active_goal?(goal)
      goal.started_at.present? && goal.completed_at.blank? && goal.deleted_at.blank?
    end

    def preload_links_and_check_ins!
      links = GoalLink.where(parent_id: @goal_ids).where(child_id: @goal_ids)
      @children_by_parent = Hash.new { |h, k| h[k] = [] }
      @parents_by_child = Hash.new { |h, k| h[k] = [] }
      links.each do |link|
        @children_by_parent[link.parent_id] << link.child_id
        @parents_by_child[link.child_id] << link.parent_id
      end

      check_ins = GoalCheckIn.where(goal_id: @goal_ids).includes(:confidence_reporter).order(:check_in_week_start, :id)
      grouped = check_ins.group_by(&:goal_id)
      @first_by_goal = {}
      @latest_by_goal = {}
      grouped.each do |goal_id, rows|
        @first_by_goal[goal_id] = rows.first
        @latest_by_goal[goal_id] = rows.last
      end
    end

    def walk_descendants(goal, seen, &block)
      children_of(goal).each do |child|
        next if seen.include?(child.id)

        seen.add(child.id)
        yield child
        walk_descendants(child, seen, &block)
      end
    end

    def mean(values)
      values = values.compact
      return nil if values.empty?

      values.sum.to_f / values.size
    end

    def build_dots(checked)
      checked.each_with_index.map do |goal, index|
        latest = latest_check_in(goal)
        first = first_check_in(goal)
        {
          goal_id: goal.id,
          title: goal.title,
          confidence: own(goal),
          age_bucket: ConfidenceAge.bucket(latest, as_of: @as_of),
          lane: index % 4,
          first_confidence: first&.confidence_percentage,
          delta: confidence_delta(goal)
        }
      end
    end

    def append_children_rows(rows, parent, depth:)
      kids = children_of(parent)
      kids.each do |child|
        rows << build_row(child, depth: depth, section_root: false)
        append_children_rows(rows, child, depth: depth + 1)
      end
    end

    def build_row(goal, depth:, section_root:)
      kids = children_of(goal)
      descendants_count = 0
      active_descendants = 0
      walk_descendants(goal, Set.new) do |descendant|
        descendants_count += 1
        active_descendants += 1 if active_goal?(descendant)
      end

      TreeRow.new(
        goal: goal,
        depth: depth,
        leaf: kids.empty?,
        parent_count: parents_in_set(goal).size,
        own_percentage: own(goal),
        arrow: arrow(goal),
        age_bucket: ConfidenceAge.bucket(latest_check_in(goal), as_of: @as_of),
        age_label: ConfidenceAge.age_label(latest_check_in(goal), as_of: @as_of),
        agreement: agreement(goal),
        first_check_in: first_check_in(goal),
        latest_check_in: latest_check_in(goal),
        section_root: section_root,
        descendants_count: descendants_count,
        direct_children_count: kids.size,
        active_descendants_count: active_descendants,
        active_direct_children_count: kids.count { |child| active_goal?(child) }
      )
    end
  end
end
