import { Controller } from "@hotwired/stimulus"

// After the form is edited, prompts "Did you save?" when the user clicks a link that would
// navigate away (GET, same tab). Form submits (POST/PATCH) are not intercepted.
export default class extends Controller {
  static values = {
    message: {
      type: String,
      default: "Did you save? Your unsaved changes may be lost if you leave."
    }
  }

  connect() {
    this.dirty = false
    this.boundHandleClick = this.handleClick.bind(this)
    document.addEventListener("click", this.boundHandleClick, true)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClick, true)
  }

  markDirty() {
    this.dirty = true
  }

  markCleanOnSuccess(event) {
    if (event.detail?.success) {
      this.dirty = false
    }
  }

  handleClick(event) {
    const link = event.target.closest("a[href]")
    if (!link || !this.isNavigatingLink(link)) return
    if (!this.dirty) return

    event.preventDefault()
    event.stopPropagation()

    if (!confirm(this.messageValue)) return

    if (window.Turbo && typeof window.Turbo.visit === "function") {
      window.Turbo.visit(link.href)
    } else {
      window.location.href = link.href
    }
  }

  isNavigatingLink(link) {
    const href = (link.getAttribute("href") || "").trim()
    if (!href || href === "#" || href.startsWith("#") || href.toLowerCase().startsWith("javascript:")) {
      return false
    }
    if (link.target && link.target !== "_self") {
      return false
    }
    const method = (link.getAttribute("data-method") || link.getAttribute("data-turbo-method") || "get").toLowerCase()
    if (method !== "get") {
      return false
    }
    return true
  }
}
