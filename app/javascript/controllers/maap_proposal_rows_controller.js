import { Controller } from "@hotwired/stimulus"

// Add/remove row cards on MAAP assignment proposal edit (outcomes, abilities, reliance).
// New rows prepend so they stay visible when the list is long.
export default class extends Controller {
  static targets = ["list", "template"]

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasListTarget) return

    const node = this.templateTarget.content.cloneNode(true)
    const firstChild = node.firstElementChild
    this.listTarget.prepend(node)

    if (firstChild) {
      firstChild.scrollIntoView({ behavior: "smooth", block: "nearest" })
      const focusable = firstChild.querySelector("select, input, textarea")
      if (focusable) focusable.focus({ preventScroll: true })
    }
  }

  remove(event) {
    event.preventDefault()
    const card = event.currentTarget.closest("[data-maap-proposal-rows-target='row']")
    if (card) card.remove()
  }
}
