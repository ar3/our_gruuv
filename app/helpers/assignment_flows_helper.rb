# frozen_string_literal: true

module AssignmentFlowsHelper
  # Build Mermaid flowchart DSL for assignment supply relationships.
  # Node IDs are safe (n_<id>); labels are escaped for Mermaid (quotes, backslashes).
  # Optional organization for click hrefs to assignment show pages.
  def mermaid_flowchart_dsl(assignments, supply_relationships, organization: nil)
    return '' if assignments.blank?

    lines = []
    lines << 'flowchart TB'
    lines << '%% Assignment supply flow: supplier --> consumer'

    assignment_ids = assignments.map(&:id).to_set

    # Node definitions: n_<id>["Label"]
    assignments.each do |a|
      node_id = "n_#{a.id}"
      label = a.title.to_s.truncate(50)
      escaped_label = label.gsub('\\', '\\\\').gsub('"', '\\"')
      lines << "  #{node_id}[\"#{escaped_label}\"]"
    end

    # Edges: supplier --> consumer
    supply_relationships.each do |rel|
      sid = rel.supplier_assignment_id
      cid = rel.consumer_assignment_id
      next unless assignment_ids.include?(sid) && assignment_ids.include?(cid)
      lines << "  n_#{sid} --> n_#{cid}"
    end

    # Click links to assignment pages (Mermaid supports click nodeId href "url")
    if organization.present?
      assignments.each do |a|
        url = organization_assignment_path(organization, a)
        lines << "  click n_#{a.id} href \"#{url}\""
      end
    end

    lines.join("\n")
  end
end
