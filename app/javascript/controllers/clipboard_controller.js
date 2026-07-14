import { Controller } from "@hotwired/stimulus"

// Copies text from a target element (or a value) to the clipboard with button feedback.
export default class extends Controller {
  static targets = ["source", "button", "buttonLabel"]
  static values = {
    successMessage: { type: String, default: "Copied!" },
    idleLabel: { type: String, default: "Copy prompt" }
  }

  async copy(event) {
    event.preventDefault()

    const text = this.hasSourceTarget
      ? this.sourceTarget.innerText || this.sourceTarget.textContent || ""
      : ""

    if (!text.trim()) return

    try {
      await navigator.clipboard.writeText(text)
      this.showCopiedFeedback()
    } catch (_err) {
      this.fallbackCopy(text)
    }
  }

  fallbackCopy(text) {
    const textArea = document.createElement("textarea")
    textArea.value = text
    textArea.setAttribute("readonly", "")
    textArea.style.position = "absolute"
    textArea.style.left = "-9999px"
    document.body.appendChild(textArea)
    textArea.select()

    try {
      document.execCommand("copy")
      this.showCopiedFeedback()
    } finally {
      document.body.removeChild(textArea)
    }
  }

  showCopiedFeedback() {
    if (this.hasButtonLabelTarget) {
      this.buttonLabelTarget.textContent = this.successMessageValue
    } else if (this.hasButtonTarget) {
      this.buttonTarget.textContent = this.successMessageValue
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.classList.remove("btn-outline-secondary")
      this.buttonTarget.classList.add("btn-success")
    }

    window.clearTimeout(this._resetTimer)
    this._resetTimer = window.setTimeout(() => this.resetButton(), 2000)
  }

  resetButton() {
    if (this.hasButtonLabelTarget) {
      this.buttonLabelTarget.textContent = this.idleLabelValue
    } else if (this.hasButtonTarget) {
      this.buttonTarget.textContent = this.idleLabelValue
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.classList.remove("btn-success")
      this.buttonTarget.classList.add("btn-outline-secondary")
    }
  }

  disconnect() {
    window.clearTimeout(this._resetTimer)
  }
}
