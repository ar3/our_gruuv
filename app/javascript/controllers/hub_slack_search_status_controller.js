import { Controller } from "@hotwired/stimulus"

// Polls hub Slack-search status rows while any search/extract is in flight.
export default class extends Controller {
  static values = { url: String }
  static targets = ["row"]

  connect() {
    if (!this.urlValue) return
    this.poll()
    this.timer = window.setInterval(() => this.poll(), 3000)
  }

  disconnect() {
    if (this.timer) {
      window.clearInterval(this.timer)
      this.timer = null
    }
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const data = await response.json()
      const byId = {}
      ;(data.searches || []).forEach((entry) => {
        byId[String(entry.id)] = entry
      })

      this.element.querySelectorAll("[data-hub-slack-search-status-row]").forEach((row) => {
        const entry = byId[row.dataset.searchId]
        if (!entry) return
        const phase = row.querySelector("[data-hub-phase]")
        if (phase) phase.textContent = entry.phase
        const pogo = row.querySelector("[data-hub-pogo-count]")
        if (pogo) pogo.textContent = entry.pogo_count
        const dismissed = row.querySelector("[data-hub-dismissed-count]")
        if (dismissed) dismissed.textContent = entry.dismissed_pogo_count
        const promoted = row.querySelector("[data-hub-promoted-count]")
        if (promoted) promoted.textContent = entry.promoted_pogo_count
      })

      if (!data.polling) {
        this.disconnect()
      }
    } catch (_error) {
      // Keep polling through transient errors.
    }
  }
}
