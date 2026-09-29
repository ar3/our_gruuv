import { Controller } from "@hotwired/stimulus"

// Add/remove row cards on MAAP assignment proposal edit (outcomes, abilities, reliance).
export default class extends Controller {
  static targets = ["list", "template"]

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasListTarget) return

    const node = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(node)
  }

  remove(event) {
    event.preventDefault()
    const card = event.currentTarget.closest("[data-maap-proposal-rows-target='row']")
    if (card) card.remove()
  }
}
