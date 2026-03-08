import { Controller } from "@hotwired/stimulus"

// Filters a list of options (cards, rows, checkboxes, etc.) by a simple text search
// over their visible content. Add data-controller="options-filter", mark the search
// input and options container with targets, and add the filterable-option class to
// each option. See docs/UX/options-filter.md for usage.
export default class extends Controller {
  static targets = ["input", "list"]
  static values = { optionsSelector: { type: String, default: ".filterable-option" } }

  connect() {
    this.filter = this.filter.bind(this)
    this.inputTarget.addEventListener("input", this.filter)
  }

  disconnect() {
    this.inputTarget.removeEventListener("input", this.filter)
  }

  filter() {
    const q = (this.inputTarget.value || "").trim().toLowerCase()
    const options = this.listTarget.querySelectorAll(this.optionsSelectorValue)

    options.forEach((el) => {
      const text = (el.textContent || "").toLowerCase()
      el.style.display = text.includes(q) ? "" : "none"
    })
  }
}
