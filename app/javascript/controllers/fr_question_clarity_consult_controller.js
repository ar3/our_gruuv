import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["suggestion", "linkLabel"]
  static values = {
    open: { type: Boolean, default: false },
    hasCompleted: { type: Boolean, default: false }
  }

  connect() {
    this.syncOpen()
  }

  toggle(event) {
    event.preventDefault()
    this.openValue = !this.openValue
    this.syncOpen()
  }

  syncOpen() {
    this.suggestionTargets.forEach((el) => {
      el.classList.toggle("d-none", !this.openValue)
    })
    if (this.hasLinkLabelTarget && this.hasCompletedValue) {
      this.linkLabelTarget.textContent = this.openValue
        ? "Hide what OG thinks about making these questions more specific / easier to respond to"
        : "Show what OG thinks will make the questions a bit more specific / easier to respond to"
    }
  }
}
