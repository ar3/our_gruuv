import { Controller } from "@hotwired/stimulus"

// Appends muted caption text (summary / why) into the OGO story textarea.
export default class extends Controller {
  static targets = ["story"]

  copy(event) {
    event.preventDefault()
    const text = event.currentTarget.dataset.copyText
    if (!text || !this.hasStoryTarget) return

    const story = this.storyTarget
    if (story.disabled) return

    const existing = story.value.toString()
    story.value = existing.trim().length ? `${existing.trimEnd()}\n\n${text}` : text
    story.dispatchEvent(new Event("input", { bubbles: true }))
    story.focus()
  }
}
