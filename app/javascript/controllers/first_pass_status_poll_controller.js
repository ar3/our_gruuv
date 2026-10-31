import { Controller } from "@hotwired/stimulus"

// Polls first-pass status and reloads when the cheap cue pass finishes.
export default class extends Controller {
  static values = {
    url: String,
    intervalMs: { type: Number, default: 2000 }
  }

  connect() {
    this.timer = setInterval(() => this.tick(), this.intervalMsValue)
    this.tick()
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  async tick() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) return
      const data = await response.json()
      if (data.reload) {
        clearInterval(this.timer)
        window.location.reload()
      }
    } catch (_error) {
      // Keep polling; transient network blips are fine.
    }
  }
}
