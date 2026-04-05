import { Controller } from "@hotwired/stimulus"

// Hides the "Add new widgets" trigger while the panel is open; shows it again when collapsed.
export default class extends Controller {
  static targets = ["trigger"]

  connect() {
    this.panel = document.getElementById("start-here-add-widgets")
    if (!this.panel || !this.hasTriggerTarget) return

    this._onShown = () => {
      this.triggerTarget.classList.add("d-none")
      this.triggerTarget.setAttribute("aria-expanded", "true")
    }
    this._onHidden = () => {
      this.triggerTarget.classList.remove("d-none")
      this.triggerTarget.setAttribute("aria-expanded", "false")
    }

    this.panel.addEventListener("shown.bs.collapse", this._onShown)
    this.panel.addEventListener("hidden.bs.collapse", this._onHidden)

    if (this.panel.classList.contains("show")) {
      this.triggerTarget.classList.add("d-none")
      this.triggerTarget.setAttribute("aria-expanded", "true")
    }
  }

  disconnect() {
    if (!this.panel) return
    this.panel.removeEventListener("shown.bs.collapse", this._onShown)
    this.panel.removeEventListener("hidden.bs.collapse", this._onHidden)
  }
}
