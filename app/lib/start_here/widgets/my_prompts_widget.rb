# frozen_string_literal: true

class StartHere::Widgets::MyPromptsWidget < StartHere::Widget::Base
  START_HERE_WIDGET = {
    id: "my_prompts",
    group: "About Me",
    icon: "bi-journal-text",
    selection_title: "My Prompts",
    selection_description: "Your growth plan prompts.",
    label: ->(c) { "My #{c.view.company_label_plural('prompt', 'Prompts')}" },
    path: ->(c) { c.view.organization_prompts_path(c.organization) },
    description: "Your growth plan prompts.",
    button_label: ->(c) { "Open #{c.view.company_label_plural('prompt', 'Prompts')}" }
  }.freeze
end
