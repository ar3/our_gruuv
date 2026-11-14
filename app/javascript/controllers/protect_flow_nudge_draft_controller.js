import { Controller } from "@hotwired/stimulus"

// Keeps the send form's hidden body field in sync with the editable textarea.
export default class extends Controller {
  static targets = ["textarea", "hiddenBody"]

  connect() {
    this.syncHidden()
  }

  syncHidden() {
    if (!this.hasTextareaTarget || !this.hasHiddenBodyTarget) return
    this.hiddenBodyTarget.value = this.textareaTarget.value
  }
}
