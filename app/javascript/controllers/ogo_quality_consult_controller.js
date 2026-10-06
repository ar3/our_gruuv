import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "linkLabel", "runButton", "hint"]
  static values = {
    open: { type: Boolean, default: false },
    hasConsult: { type: Boolean, default: false }
  }

  connect() {
    this.storyField = document.getElementById("observation_story")
    this.syncOpen()
    this.syncRunEnabled()
    this.storyField?.addEventListener("input", this.boundSync)
    document.addEventListener("change", this.boundSync)
  }

  disconnect() {
    this.storyField?.removeEventListener("input", this.boundSync)
    document.removeEventListener("change", this.boundSync)
  }

  boundSync = () => this.syncRunEnabled()

  toggle(event) {
    event.preventDefault()
    this.openValue = !this.openValue
    this.syncOpen()
  }

  syncOpen() {
    if (!this.hasPanelTarget) return

    this.panelTarget.classList.toggle("d-none", !this.openValue)
    if (this.hasLinkLabelTarget) {
      this.linkLabelTarget.textContent = this.hasConsultValue
        ? "Consult OG again"
        : "Consult OG about this OGO"
    }
  }

  syncRunEnabled() {
    if (!this.hasRunButtonTarget) return

    const storyOk = (this.storyField?.value || "").trim().length > 0
    const observeeOk = this.observeeCount() > 0
    const enabled = storyOk && observeeOk
    this.runButtonTarget.disabled = !enabled
    if (this.hasHintTarget) {
      this.hintTarget.classList.toggle("d-none", enabled)
    }
  }

  observeeCount() {
    const hidden = document.querySelectorAll('input[name="observee_ids[]"][value]:not([value=""])')
    return hidden.length
  }
}
