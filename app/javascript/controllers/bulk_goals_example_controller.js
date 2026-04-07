import { Controller } from "@hotwired/stimulus"

// Fills the bulk goal titles textarea from a hidden <pre> template (see shared/goals/_bulk_nested_goals_example_link).
export default class extends Controller {
  static targets = ["template"]
  static values = {
    textareaId: { type: String, default: "bulk_goal_titles" },
  }

  insert(event) {
    event?.preventDefault()
    const ta = document.getElementById(this.textareaIdValue)
    if (!ta || !this.hasTemplateTarget) return

    ta.value = this.templateTarget.textContent.replace(/\s+$/u, "")
    ta.focus()
  }
}
