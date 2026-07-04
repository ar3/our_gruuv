import { Controller } from "@hotwired/stimulus"

// Hover/focus Bootstrap popovers for per-item check-ins health bar segments.
export default class extends Controller {
  static targets = ["segment", "ehBar", "actionBar"]

  connect() {
    this.initializeSegmentPopovers()
  }

  disconnect() {
    this.disposeSegmentPopovers()
  }

  initializeSegmentPopovers() {
    const Popover = this.bootstrapPopoverClass()
    if (!Popover) return

    this.segmentTargets.forEach((element) => {
      const existing = Popover.getInstance(element)
      if (existing) existing.dispose()

      const html = element.dataset.popoverHtml
      if (!html) return

      new Popover(element, {
        trigger: "hover focus",
        placement: "top",
        html: true,
        sanitize: false,
        content: html
      })
    })
  }

  disposeSegmentPopovers() {
    const Popover = this.bootstrapPopoverClass()
    if (!Popover) return

    this.segmentTargets.forEach((element) => {
      const instance = Popover.getInstance(element)
      if (instance) instance.dispose()
    })
  }

  bootstrapPopoverClass() {
    return window.bootstrap?.Popover || null
  }
}
