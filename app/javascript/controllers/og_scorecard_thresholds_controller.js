import { Controller } from "@hotwired/stimulus"
import * as bootstrapNs from "bootstrap"

// Toggle threshold + "More or less" columns; when hidden, row info buttons show threshold popovers.
export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.popoverInstances = []
    this.bs = bootstrapNs.Popover ? bootstrapNs : bootstrapNs.default || {}
    this.PopoverCtor = this.bs.Popover
    this.syncFromToggle()
    // Defer so layout and Turbo paint complete; importmap bootstrap may use default export.
    this.scheduleRefreshPopovers()
  }

  disconnect() {
    if (this._popoverSchedule) {
      clearTimeout(this._popoverSchedule)
      this._popoverSchedule = null
    }
    this.disposePopovers()
    this.popoverInstances = []
  }

  thresholdsToggled() {
    this.syncFromToggle()
    this.scheduleRefreshPopovers()
  }

  scheduleRefreshPopovers() {
    if (this._popoverSchedule) clearTimeout(this._popoverSchedule)
    this._popoverSchedule = setTimeout(() => {
      this._popoverSchedule = null
      this.refreshPopovers()
    }, 0)
  }

  syncFromToggle() {
    if (!this.hasToggleTarget) return

    if (this.toggleTarget.checked) {
      this.element.classList.remove("og-scorecard--thresholds-hidden")
    } else {
      this.element.classList.add("og-scorecard--thresholds-hidden")
    }
  }

  refreshPopovers() {
    this.disposePopovers()
    if (!this.hasToggleTarget || this.toggleTarget.checked) return

    const Popover = this.PopoverCtor
    if (!Popover) return

    this.element.querySelectorAll("[data-og-scorecard-popover-button]").forEach((btn) => {
      const sourceId = btn.dataset.ogScorecardPopoverSourceId
      if (!sourceId) return
      const source = document.getElementById(sourceId)
      if (!source) return

      const html = source.innerHTML.trim()
      if (!html) return

      try {
        const pop = new Popover(btn, {
          html: true,
          sanitize: false,
          trigger: "hover focus",
          placement: "auto",
          container: "body",
          customClass: "og-scorecard-threshold-popover",
          content: html
        })
        this.popoverInstances.push(pop)
      } catch (_e) {
        // ignore init failures
      }
    })
  }

  disposePopovers() {
    if (!this.popoverInstances?.length) return
    this.popoverInstances.forEach((p) => {
      try {
        p.dispose()
      } catch (_e) {
        // ignore
      }
    })
    this.popoverInstances = []
  }
}
