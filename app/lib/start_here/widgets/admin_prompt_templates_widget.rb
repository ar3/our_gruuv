# frozen_string_literal: true

class StartHere::Widgets::AdminPromptTemplatesWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "admin_prompt_templates",
    group: "Admin",
    icon: "bi-file-text",
    selection_title: "Prompt Templates",
    selection_description: "Prompt templates.",
    label: "Prompt Templates",
    path: ->(c) { c.view.organization_prompt_templates_path(c.organization) },
    description: "Prompt templates.",
    button_label: "Prompt Templates"
  }.freeze
end
