import { Controller } from "@hotwired/stimulus"

// Shows the Back + divider group only when history may allow a meaningful back (heuristic).
export default class extends Controller {
  connect() {
    if (window.history.length > 1) {
      this.element.classList.remove("d-none")
      this.element.classList.add("d-flex")
      this.element.removeAttribute("aria-hidden")
    } else {
      this.element.classList.add("d-none")
      this.element.classList.remove("d-flex")
      this.element.setAttribute("aria-hidden", "true")
    }
  }

  goBack() {
    window.history.back()
  }
}
