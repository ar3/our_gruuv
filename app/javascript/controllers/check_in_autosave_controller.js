import { Controller } from "@hotwired/stimulus"

// Debounced background save for check-in forms. Intercepts navigation when changes
// are dirty, in-flight, or the last auto-save failed.
export default class extends Controller {
  static targets = ["status"]

  static values = {
    debounceMs: { type: Number, default: 2500 },
    message: {
      type: String,
      default: "Did you save? Your unsaved changes may be lost if you leave."
    }
  }

  connect() {
    this.dirty = false
    this.saving = false
    this.lastError = null
    this.debounceTimer = null
    this.retryTimer = null
    this.boundHandleClick = this.handleClick.bind(this)
    document.addEventListener("click", this.boundHandleClick, true)
  }

  disconnect() {
    this.clearDebounce()
    this.clearRetry()
    document.removeEventListener("click", this.boundHandleClick, true)
  }

  markDirty() {
    this.dirty = true
    if (!this.saving) {
      this.updateStatus("")
    }
    this.scheduleSave()
  }

  handleSubmit() {
    this.clearDebounce()
    this.clearRetry()
    this.saving = true
    this.updateStatus("Saving…")
  }

  scheduleSave() {
    this.clearDebounce()
    this.debounceTimer = window.setTimeout(() => this.save(), this.debounceMsValue)
  }

  async save(retryAttempt = 0) {
    if (!this.dirty || this.saving) return

    this.saving = true
    this.updateStatus("Saving…")

    const formData = new FormData(this.element)
    formData.append("autosave", "1")
    formData.append("save_and_continue_editing", "1")

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.element.action, {
        method: (this.element.method || "patch").toUpperCase(),
        headers: {
          Accept: "application/json",
          ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
        },
        body: formData
      })

      const data = await response.json().catch(() => ({}))

      if (response.ok && data.ok) {
        this.dirty = false
        this.lastError = null
        this.saving = false
        this.updateStatus(`Saved ${this.formatTime(data.saved_at)}`)
        return
      }

      this.lastError = data.errors || "Save failed"
      this.saving = false
      this.showSaveError(retryAttempt)
    } catch (_error) {
      this.lastError = "Network error"
      this.saving = false
      this.showSaveError(retryAttempt)
    }
  }

  showSaveError(retryAttempt) {
    if (retryAttempt === 0) {
      this.updateStatus("Couldn't save — retrying…", true)
      this.retryTimer = window.setTimeout(() => this.save(1), 5000)
    } else {
      this.updateStatus("Couldn't save — please try again", true)
    }
  }

  isUnsafeToLeave() {
    return this.dirty || this.saving || this.lastError
  }

  handleClick(event) {
    const link = event.target.closest("a[href]")
    if (!link || !this.isNavigatingLink(link)) return
    if (!this.isUnsafeToLeave()) return

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

  formatTime(isoString) {
    if (!isoString) return "just now"
    try {
      return new Date(isoString).toLocaleTimeString([], {
        hour: "numeric",
        minute: "2-digit",
        second: "2-digit"
      })
    } catch (_error) {
      return "just now"
    }
  }

  updateStatus(text, isError = false) {
    if (!this.hasStatusTarget) return
    const visible = text.length > 0
    this.statusTarget.textContent = text
    this.statusTarget.classList.toggle("d-none", !visible)
    this.statusTarget.classList.toggle("text-danger", isError)
    this.statusTarget.classList.toggle("text-muted", !isError)
  }

  clearDebounce() {
    if (this.debounceTimer) {
      window.clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }
  }

  clearRetry() {
    if (this.retryTimer) {
      window.clearTimeout(this.retryTimer)
      this.retryTimer = null
    }
  }
}
