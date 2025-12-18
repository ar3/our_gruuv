module DecoratorSemanticVersionable
  extend ActiveSupport::Concern

  def new_version_options
    [
      {
        value: "ready",
        label: "Ready for Use",
        version_text: "Version 1.0.0",
        text_class: "text-success",
        description: "Complete and ready for team use",
        checked: true
      },
      {
        value: "nearly_ready",
        label: "Nearly Ready",
        version_text: "Version 0.1.0",
        text_class: "text-warning",
        description: "Almost complete, minor tweaks needed",
        checked: false
      },
      {
        value: "early_draft",
        label: "Early Draft",
        version_text: "Version 0.0.1",
        text_class: "text-secondary",
        description: "Initial concept, needs development",
        checked: false
      }
    ]
  end

  def edit_version_options
    major, minor, patch = __getobj__.semantic_version.split('.').map(&:to_i)
    
    [
      {
        value: "fundamental",
        label: "Fundamental Change",
        version_text: "Version #{major + 1}.0.0",
        text_class: "text-danger",
        description: "Major changes, new capabilities",
        checked: false
      },
      {
        value: "clarifying",
        label: "Clarifying Change",
        version_text: "Version #{major}.#{minor + 1}.0",
        text_class: "text-warning",
        description: "Improvements, clarifications",
        checked: false
      },
      {
        value: "insignificant",
        label: "Insignificant Change",
        version_text: "Version #{major}.#{minor}.#{patch + 1}",
        text_class: "text-info",
        description: "Small fixes, minor updates",
        checked: true
      }
    ]
  end

  def version_section_title_for_context(model_name)
    if __getobj__.persisted?
      "Change Type & Version"
    else
      "#{model_name} Status & Version"
    end
  end

  def version_section_description_for_context(model_name)
    if __getobj__.persisted?
      "Current version: #{__getobj__.semantic_version}. Choose the type of change you're making:"
    else
      "Choose the readiness level for this #{model_name.downcase}. The version number will be set automatically:"
    end
  end
end

