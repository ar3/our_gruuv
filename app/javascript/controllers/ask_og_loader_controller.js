import { Controller } from "@hotwired/stimulus"

// Lazy-loads the Ask OG panel HTML into the search empty state (keeps search TTFB clean).
export default class extends Controller {
  static values = {
    url: String
  }

  connect() {
    this.load()
  }

  async load() {
    if (!this.urlValue) return

    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "text/html" } })
      if (!response.ok) {
        this.element.innerHTML = `<div class="alert alert-warning mb-0">Could not load Ask OG.</div>`
        return
      }
      const html = await response.text()
      this.element.innerHTML = html
    } catch (e) {
      this.element.innerHTML = `<div class="alert alert-warning mb-0">Could not load Ask OG.</div>`
    }
  }
}
