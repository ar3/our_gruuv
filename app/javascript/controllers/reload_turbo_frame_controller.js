import { Controller } from "@hotwired/stimulus"

// Re-fetches a lazy Turbo Frame when the page is restored from Turbo cache
// (so OG Academy progress is fresh when this is the home page).
export default class extends Controller {
  connect() {
    if (this.element.tagName !== "TURBO-FRAME") return

    this.boundMarkLoaded = this.markLoaded.bind(this)
    this.element.addEventListener("turbo:frame-load", this.boundMarkLoaded)

    if (this.element.dataset.loaded === "true" && this.element.src) {
      this.element.reload()
    }
  }

  disconnect() {
    if (this.boundMarkLoaded) {
      this.element.removeEventListener("turbo:frame-load", this.boundMarkLoaded)
    }
  }

  markLoaded() {
    this.element.dataset.loaded = "true"
  }
}
