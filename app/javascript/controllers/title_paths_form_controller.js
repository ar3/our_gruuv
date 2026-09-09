import { Controller } from "@hotwired/stimulus"

// When End-cap is checked on manage title paths, disable outbound radios and
// force any checked outbound back to No Association.
export default class extends Controller {
  static targets = ["endCap"]

  connect() {
    this.toggleEndCap()
  }

  toggleEndCap() {
    if (!this.hasEndCapTarget) return

    const endCap = this.endCapTarget.checked
    this.element.querySelectorAll('input[type="radio"][value="outbound"]').forEach((radio) => {
      radio.disabled = endCap
      const label = this.element.querySelector(`label[for="${radio.id}"]`)
      if (label) label.classList.toggle("disabled", endCap)

      if (endCap && radio.checked) {
        const noneRadio = this.element.querySelector(
          `input[type="radio"][name="${radio.name}"][value="none"]`
        )
        if (noneRadio) {
          noneRadio.checked = true
          noneRadio.dispatchEvent(new Event("change", { bubbles: true }))
        }
      }
    })
  }
}
