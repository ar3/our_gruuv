import { Controller } from "@hotwired/stimulus"

// Prompts "Did you save?" when user clicks a link that would navigate away (GET, same tab).
// Used on check-ins and finalization pages so form submits (POST/PATCH) are not intercepted.
export default class extends Controller {
  static values = {
    message: {
      type: String,
      default: "Did you save? Your unsaved changes may be lost if you leave."
    }
  }

  connect() {
    this.boundHandleClick = this.handleClick.bind(this)
    document.addEventListener("click", this.boundHandleClick, true)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClick, true)
  }

  handleClick(event) {
    const link = event.target.closest("a[href]")
    if (!link || !this.isNavigatingLink(link)) return

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
