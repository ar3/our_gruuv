# frozen_string_literal: true

class StartHere::Widgets::AboutCompletePictureWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "about_complete_picture",
    group: "About Me",
    icon: "bi-graph-up",
    selection_title: "Active Job View",
    selection_description: "Role, assignments, and job context.",
    label: "Active Job View",
    path: ->(c) { c.view.complete_picture_organization_company_teammate_path(c.organization, c.company_teammate) },
    description: nil,
    button_label: "Active Job View"
  }.freeze

  def dashboard_content
    ct = context.company_teammate
    return ActiveSupport::SafeBuffer.new if ct.blank?

    count = ct.active_assignments.count
    total_pct = ct.active_assignment_tenures.sum(:anticipated_energy_percentage).to_i
    name = ERB::Util.html_escape(context.casual_name.to_s)
    assign_phrase = view.pluralize(count, "active assignment")
    represent_verb = count == 1 ? "represents" : "represent"
    lead = "#{name}, you have #{assign_phrase}, that #{represent_verb} a total of #{total_pct}% of your energy allocated."

    view.tag.p(class: "small mb-0") { lead.html_safe }
  end
end
