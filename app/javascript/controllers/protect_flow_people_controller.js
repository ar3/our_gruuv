import { Controller } from "@hotwired/stimulus"

// Collapsed person cards (5 signal boxes) ↔ expanded 3-column rows.
// Page-level Expand all / Collapse all toggles every card.
export default class extends Controller {
  static targets = ["card"]

  toggle(event) {
    event.preventDefault()
    const card = event.currentTarget.closest("[data-protect-flow-people-target='card']")
    if (!card) return

    this.#setExpanded(card, card.dataset.expanded !== "true")
  }

  expandAll(event) {
    event.preventDefault()
    this.cardTargets.forEach((card) => this.#setExpanded(card, true))
  }

  collapseAll(event) {
    event.preventDefault()
    this.cardTargets.forEach((card) => this.#setExpanded(card, false))
  }

  #setExpanded(card, expanded) {
    card.dataset.expanded = expanded ? "true" : "false"

    const summary = card.querySelector("[data-protect-flow-summary]")
    const details = card.querySelector("[data-protect-flow-details]")
    if (summary) summary.classList.toggle("d-none", expanded)
    if (details) details.classList.toggle("d-none", !expanded)

    card.querySelectorAll("[data-protect-flow-toggle]").forEach((toggle) => {
      toggle.textContent = expanded ? "Hide details" : "Show details"
      toggle.setAttribute("aria-expanded", expanded ? "true" : "false")
    })
  }
}
