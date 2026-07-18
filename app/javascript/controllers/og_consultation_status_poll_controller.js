import { Controller } from "@hotwired/stimulus"

// Shared poller for Consult OG / OGO search wait banners (elapsed, last checked, ETA).
// Remaining = max(0, estimated_duration_seconds - elapsed). Estimate is stable across polls.
export default class extends Controller {
  static values = {
    statusUrl: String,
    label: { type: String, default: "Consultation" },
    timeZone: String
  }

  static targets = ["statusText", "elapsed", "eta", "units", "slowWarning", "lastChecked"]

  connect() {
    if (this.pollTimer) return

    this.elapsedBaseSeconds = 0
    this.elapsedBaseAt = Date.now()
    this.estimatedDurationSeconds = null
    this.inFlight = true

    this.poll()
    this.pollTimer = window.setInterval(() => this.poll(), 3000)
    this.tickTimer = window.setInterval(() => this.tickClocks(), 1000)
  }

  disconnect() {
    if (this.pollTimer) {
      window.clearInterval(this.pollTimer)
      this.pollTimer = null
    }
    if (this.tickTimer) {
      window.clearInterval(this.tickTimer)
      this.tickTimer = null
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
        window.location.reload()
      }
    } catch (_error) {
      // Keep polling; transient failures are expected.
    }
  }

  updateBanner(data) {
    this.inFlight = ["pending", "processing"].includes(data.status)

    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = `${this.labelValue} is ${data.status}…`
    }

    const elapsedSeconds = Math.max(parseInt(data.elapsed_seconds || 0, 10), 0)
    this.elapsedBaseSeconds = elapsedSeconds
    this.elapsedBaseAt = Date.now()

    if (this.hasUnitsTarget) {
      const total = parseInt(data.units_total || 0, 10)
      const completed = parseInt(data.units_completed || 0, 10)
      if (total > 1) {
        this.unitsTarget.textContent = `${completed} of ${total}`
        this.unitsTarget.classList.remove("d-none")
      } else {
        this.unitsTarget.textContent = ""
        this.unitsTarget.classList.add("d-none")
      }
    }

    if (this.hasEtaTarget) {
      const estimate = data.estimated_duration_seconds
      if (estimate != null && Number.isFinite(Number(estimate))) {
        this.estimatedDurationSeconds = Math.max(Number(estimate), 0)
        this.etaTarget.classList.remove("d-none")
      } else if (this.inFlight) {
        this.estimatedDurationSeconds = null
        this.etaTarget.textContent = "Estimating…"
        this.etaTarget.classList.remove("d-none")
      } else {
        this.estimatedDurationSeconds = null
        this.etaTarget.textContent = ""
        this.etaTarget.classList.add("d-none")
      }
    }

    if (this.hasSlowWarningTarget) {
      this.slowWarningTarget.classList.toggle("d-none", !data.slow)
      if (data.stale) {
        this.slowWarningTarget.textContent = "Possible stall detected. Try refreshing or run again."
      } else {
        this.slowWarningTarget.textContent = "Taking longer than expected."
      }
    }

    if (this.hasLastCheckedTarget) {
      this.lastCheckedTarget.textContent = `Last checked: ${this.formatTime(new Date())}`
    }

    this.tickClocks()
  }

  tickClocks() {
    const elapsed = this.elapsedBaseSeconds + Math.floor((Date.now() - this.elapsedBaseAt) / 1000)

    if (this.hasElapsedTarget) {
      this.elapsedTarget.textContent = `(${this.formatElapsed(elapsed)})`
    }

    if (!this.hasEtaTarget || !this.inFlight) return

    if (this.estimatedDurationSeconds == null) return

    const remaining = Math.max(0, Math.ceil(this.estimatedDurationSeconds - elapsed))
    if (remaining > 0) {
      this.etaTarget.textContent = `About ${this.formatElapsed(remaining)} remaining`
    } else {
      this.etaTarget.textContent = "Almost done…"
    }
  }

  formatElapsed(seconds) {
    const s = Math.max(parseInt(seconds || 0, 10), 0)
    const mins = Math.floor(s / 60)
    const rem = s % 60
    return mins > 0 ? `${mins}m ${rem}s` : `${rem}s`
  }

  formatTime(date) {
    const options = {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      second: "2-digit",
      timeZoneName: "short"
    }
    if (this.hasTimeZoneValue && this.timeZoneValue) {
      options.timeZone = this.timeZoneValue
    }
    try {
      return date.toLocaleString([], options)
    } catch (_error) {
      return date.toLocaleString([], {
        year: "numeric",
        month: "short",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit",
        second: "2-digit",
        timeZoneName: "short"
      })
    }
  }
}
