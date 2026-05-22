# frozen_string_literal: true

module AssignmentFlowsHelper
  include MermaidFlowchartEscaping
  # Build Mermaid flowchart DSL for assignment supply relationships.
  # Node IDs are safe (n_<id>); labels are escaped for Mermaid (quotes, backslashes).
  # Optional organization for click hrefs to assignment show pages.
  def mermaid_flowchart_dsl(assignments, supply_relationships, organization: nil)
    return '' if assignments.blank?

    lines = []
    lines << 'flowchart TB'
    lines << '%% Assignment supply flow: supplier --> consumer'

    assignment_ids = assignments.map(&:id).to_set

    # Node definitions: n_<id>("Label") — round nodes; avoids [ ] label syntax issues.
    assignments.each do |a|
      node_id = "n_#{a.id}"
      label = mermaid_normalize_flowchart_text(a.title).truncate(50)
      escaped_label = mermaid_escape_flowchart_label(label)
      lines << "  #{node_id}(\"#{escaped_label}\")"
    end

    # Edges: supplier --> consumer
    supply_relationships.each do |rel|
      sid = rel.supplier_assignment_id
      cid = rel.consumer_assignment_id
      next unless assignment_ids.include?(sid) && assignment_ids.include?(cid)
      lines << "  n_#{sid} --> n_#{cid}"
    end

    lines.join("\n")
  end

  # Node id => assignment URL for post-render click binding (kept out of Mermaid DSL).
  def mermaid_assignment_click_urls(assignments, organization:)
    return {} if organization.blank?

    assignments.to_h do |assignment|
      ["n_#{assignment.id}", organization_assignment_path(organization, assignment)]
    end
  end
end
