import { Controller } from "@hotwired/stimulus"

// Polls external project sync status (1:1 Hub phase 1; reusable for team links later).
export default class extends Controller {
  static values = {
    statusUrl: String,
    sourceLabel: String
  }

  connect() {
    if (this.pollTimer) return

    this.poll()
    this.pollTimer = window.setInterval(() => this.poll(), 3000)
  }

  disconnect() {
    if (this.pollTimer) {
      window.clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async poll() {
    if (!this.statusUrlValue) return

    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const data = await response.json()
      this.updateBanner(data)

      if (data.status === "completed" || data.status === "failed") {
        window.location.href = `${window.location.pathname}${window.location.search}#sync`
        window.location.reload()
      }
    } catch (_error) {
      // Keep polling; transient failures are expected.
    }
  }

  updateBanner(data) {
    const statusText = this.element.querySelector("[data-sync-status-text]")
    const elapsedText = this.element.querySelector("[data-sync-elapsed]")
    const slowWarning = this.element.querySelector("[data-sync-slow-warning]")
    const lastChecked = this.element.querySelector("[data-sync-last-checked]")

    if (statusText) {
      const label = data.status === "pending" ? "pending" : "running"
      statusText.textContent = `Syncing ${this.sourceLabelValue} project (${label})…`
    }

    if (elapsedText) {
      elapsedText.textContent = `(${this.formatElapsed(data.elapsed_seconds)})`
    }

    if (slowWarning) {
      slowWarning.classList.toggle("d-none", !data.slow)
      if (data.stale) {
        slowWarning.textContent = "Possible stall detected. Try refreshing the page."
      }
    }

    if (lastChecked) {
      lastChecked.textContent = `Last checked: ${this.formatTime(new Date())}`
    }
  }

  formatElapsed(seconds) {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return m > 0 ? `${m}m ${s}s` : `${s}s`
  }

  formatTime(date) {
    return date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
  }
}
