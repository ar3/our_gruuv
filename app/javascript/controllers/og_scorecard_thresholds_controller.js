import { Controller } from "@hotwired/stimulus"

// Toggle visibility of Yellow / Green / direction columns on OG Scorecard.
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.syncFromToggle()
  }

  thresholdsToggled() {
    this.syncFromToggle()
  }

  syncFromToggle() {
    if (!this.hasToggleTarget) return

    if (this.toggleTarget.checked) {
      this.element.classList.remove("og-scorecard--thresholds-hidden")
    } else {
      this.element.classList.add("og-scorecard--thresholds-hidden")
    }
  }
}
