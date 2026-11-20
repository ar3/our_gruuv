# frozen_string_literal: true

module Goals
  # Builds Highcharts payloads for goals index Prize styles.
  # Tree/org layouts: one canonical node per goal (primary parent) plus duplicate
  # nodes for additional parents, marked as multi-parent duplicates.
  class HighchartsVizData
    CHART_KINDS = %w[
      hc-networkgraph
      hc-treegraph
      hc-treegraph-boxes
      hc-sankey-horizontal
      hc-sankey-vertical
      hc-organization-vertical
      hc-organization-horizontal
    ].freeze

    def initialize(goals:, organization:, soft_statuses: {})
      @goals = Array(goals)
      @organization = organization
      @soft_statuses = soft_statuses || {}
      @goal_by_id = @goals.index_by(&:id)
      @goal_ids = @goal_by_id.keys.to_set
      @links = load_links
      @parents_by_child = @links.group_by(&:child_id)
    end

    def payload_for(chart_kind)
      case chart_kind.to_s
      when "hc-networkgraph"
        networkgraph_payload
      when "hc-treegraph", "hc-treegraph-boxes"
        treegraph_payload(boxes: chart_kind.to_s == "hc-treegraph-boxes")
      when "hc-sankey-horizontal", "hc-sankey-vertical"
        sankey_payload(vertical: chart_kind.to_s == "hc-sankey-vertical")
      when "hc-organization-vertical", "hc-organization-horizontal"
        organization_payload(vertical: chart_kind.to_s == "hc-organization-vertical")
      else
        { chart_kind: chart_kind, nodes: [], links: [], data: [] }
      end
    end

    private

    def load_links
      return [] if @goal_ids.empty?

      GoalLink.where(parent_id: @goal_ids, child_id: @goal_ids).to_a
    end

    def soft_for(goal_id)
      @soft_statuses[goal_id] || @soft_statuses[goal_id.to_s] || {}
    end

    def parents_in_slice(goal_id)
      Array(@parents_by_child[goal_id]).filter_map { |link| @goal_by_id[link.parent_id] }.sort_by(&:id)
    end

    def networkgraph_payload
      nodes = @goals.map do |goal|
        soft = soft_for(goal.id)
        {
          id: node_id(goal.id),
          name: goal.title.to_s.truncate(40),
          color: soft[:stroke].presence || "#6c757d",
          marker: { radius: confidence_radius(soft) },
          url: soft[:path].presence || goal_url(goal),
          softLabel: soft[:label]
        }
      end

      links = @links.map do |link|
        { from: node_id(link.parent_id), to: node_id(link.child_id) }
      end

      {
        chart_kind: "hc-networkgraph",
        series_type: "networkgraph",
        nodes: nodes,
        links: links
      }
    end

    def treegraph_payload(boxes:)
      nodes = []
      @goals.each do |goal|
        parents = parents_in_slice(goal.id)
        soft = soft_for(goal.id)
        primary, *extras = parents

        nodes << tree_node(
          id: node_id(goal.id),
          parent: primary ? node_id(primary.id) : "",
          goal: goal,
          soft: soft,
          duplicated: false,
          parent_count: parents.size,
          multi_parent: parents.size > 1
        )

        extras.each do |parent|
          nodes << tree_node(
            id: duplicate_node_id(goal.id, parent.id),
            parent: node_id(parent.id),
            goal: goal,
            soft: soft,
            duplicated: true,
            parent_count: parents.size,
            multi_parent: true
          )
        end
      end

      {
        chart_kind: boxes ? "hc-treegraph-boxes" : "hc-treegraph",
        series_type: "treegraph",
        boxes: boxes,
        nodes: nodes
      }
    end

    def tree_node(id:, parent:, goal:, soft:, duplicated:, parent_count:, multi_parent:)
      name = goal.title.to_s.truncate(36)
      if duplicated
        name = "#{name} ⧉×#{parent_count}"
      elsif multi_parent
        name = "#{name} ⧉"
      end

      subtitle_bits = [soft[:label]]
      subtitle_bits << "multi-parent (duplicated)" if duplicated
      subtitle_bits << "multi-parent" if !duplicated && multi_parent

      {
        id: id,
        parent: parent,
        name: name,
        subtitle: subtitle_bits.compact.join(" · "),
        color: soft[:stroke].presence || "#6c757d",
        url: soft[:path].presence || goal_url(goal),
        duplicated: duplicated,
        parentCount: parent_count
      }
    end

    def organization_payload(vertical:)
      nodes = []
      links = []

      @goals.each do |goal|
        parents = parents_in_slice(goal.id)
        soft = soft_for(goal.id)
        primary, *extras = parents

        nodes << org_node(
          id: node_id(goal.id),
          goal: goal,
          soft: soft,
          duplicated: false,
          parent_count: parents.size,
          multi_parent: parents.size > 1
        )
        links << { from: node_id(primary.id), to: node_id(goal.id) } if primary

        extras.each do |parent|
          dup_id = duplicate_node_id(goal.id, parent.id)
          nodes << org_node(
            id: dup_id,
            goal: goal,
            soft: soft,
            duplicated: true,
            parent_count: parents.size,
            multi_parent: true
          )
          links << { from: node_id(parent.id), to: dup_id }
        end
      end

      {
        chart_kind: vertical ? "hc-organization-vertical" : "hc-organization-horizontal",
        series_type: "organization",
        inverted: vertical,
        nodes: nodes.uniq { |n| n[:id] },
        links: links
      }
    end

    def org_node(id:, goal:, soft:, duplicated:, parent_count:, multi_parent:)
      name = goal.title.to_s.truncate(28)
      name = duplicated ? "#{name} ⧉" : (multi_parent ? "#{name} ⧉" : name)
      title_bits = [soft[:label]]
      title_bits << "×#{parent_count} parents" if parent_count > 1
      title_bits << "duplicated" if duplicated
      {
        id: id,
        name: name,
        title: title_bits.compact.join(" · "),
        color: soft[:stroke].presence || "#6c757d",
        url: soft[:path].presence || goal_url(goal),
        duplicated: duplicated
      }
    end

    def sankey_payload(vertical:)
      nodes = @goals.map do |goal|
        soft = soft_for(goal.id)
        name = goal.title.to_s.truncate(36)
        parent_count = parents_in_slice(goal.id).size
        name = "#{name} ⧉" if parent_count > 1
        {
          id: node_id(goal.id),
          name: name,
          color: soft[:stroke].presence || "#6c757d",
          url: soft[:path].presence || goal_url(goal),
          softLabel: soft[:label]
        }
      end

      data = @links.map do |link|
        soft = soft_for(link.child_id)
        weight = soft[:status].to_s == "red" || soft[:label].to_s.match?(/Off Track|Barely/i) ? 2 : 1
        [node_id(link.parent_id), node_id(link.child_id), weight]
      end

      {
        chart_kind: vertical ? "hc-sankey-vertical" : "hc-sankey-horizontal",
        series_type: "sankey",
        inverted: vertical,
        nodes: nodes,
        data: data
      }
    end

    def confidence_radius(soft)
      return 18 if soft[:kind].to_s == "completed"
      return 10 if soft[:kind].to_s == "draft"

      soft[:kind].to_s == "on_track" ? 14 : 12
    end

    def node_id(goal_id)
      "g#{goal_id}"
    end

    def duplicate_node_id(goal_id, parent_id)
      "g#{goal_id}:p#{parent_id}"
    end

    def goal_url(goal)
      return nil if @organization.blank?

      Rails.application.routes.url_helpers.organization_goal_path(@organization, goal)
    end
  end
end
