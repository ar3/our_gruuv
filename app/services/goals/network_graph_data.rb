# frozen_string_literal: true

module Goals
  # Builds Highcharts organization + Cytoscape payloads for the Goals Network chart.
  class NetworkGraphData
    def initialize(goals:, goal_links:, organization: nil)
      @goals = Array(goals)
      @goal_links = Array(goal_links)
      @organization = organization
    end

    def highcharts_organization_data
      goal_ids = @goals.map(&:id).to_set

      nodes = @goals.map do |goal|
        {
          id: node_id(goal.id),
          name: goal.title.to_s.truncate(50),
          title: "",
          url: goal_url(goal)
        }
      end

      links = @goal_links.filter_map do |link|
        next unless goal_ids.include?(link.parent_id) && goal_ids.include?(link.child_id)

        { from: node_id(link.parent_id), to: node_id(link.child_id) }
      end

      { nodes: nodes, links: links }
    end

    def cytoscape_elements
      goal_ids = @goals.map(&:id).to_set

      nodes = @goals.map do |goal|
        {
          group: "nodes",
          data: {
            id: node_id(goal.id),
            label: goal.title.to_s.truncate(60),
            url: goal_url(goal)
          }
        }
      end

      edges = @goal_links.filter_map do |link|
        next unless goal_ids.include?(link.parent_id) && goal_ids.include?(link.child_id)

        {
          group: "edges",
          data: {
            id: "e#{link.id}",
            source: node_id(link.parent_id),
            target: node_id(link.child_id)
          }
        }
      end

      nodes + edges
    end

    def cytoscape_root_node_ids
      goal_ids = @goals.map(&:id).to_set
      child_ids = @goal_links.filter_map do |link|
        next unless goal_ids.include?(link.parent_id) && goal_ids.include?(link.child_id)

        link.child_id
      end.to_set

      roots = goal_ids - child_ids
      roots = goal_ids if roots.empty?
      roots.map { |id| node_id(id) }
    end

    private

    def node_id(goal_id)
      "g#{goal_id}"
    end

    def goal_url(goal)
      return nil if @organization.blank?

      Rails.application.routes.url_helpers.organization_goal_path(@organization, goal)
    end
  end
end
