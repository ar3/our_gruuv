# frozen_string_literal: true

class StartHere::Widgets::InsightsPromptsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "insights_prompts",
    group: "Insights",
    icon: "bi-journal-text",
    selection_title: "Prompts Insights",
    selection_description: "Prompt insights.",
    label: "Prompts Insights",
    path: ->(c) { c.view.organization_insights_prompts_path(c.organization) },
    description: "Prompt insights.",
    button_label: "Open Insights"
  }.freeze
end
