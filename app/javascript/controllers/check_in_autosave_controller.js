import { Controller } from "@hotwired/stimulus"

// Debounced background save for check-in forms. Intercepts navigation when changes
// are dirty, in-flight, or the last auto-save failed.
export default class extends Controller {
  static targets = ["status"]

  static values = {
    debounceMs: { type: Number, default: 2500 },
    timeoutMs: { type: Number, default: 30000 },
    message: {
      type: String,
      default: "Did you save? Your unsaved changes may be lost if you leave."
    }
  }

  connect() {
    this.dirty = false
    this.saving = false
    this.saveGeneration = 0
    this.lastError = null
    this.debounceTimer = null
    this.retryTimer = null
    this.abortController = null
    this.boundHandleClick = this.handleClick.bind(this)
    document.addEventListener("click", this.boundHandleClick, true)
  }

  disconnect() {
    this.clearDebounce()
    this.clearRetry()
    this.abortInFlight()
    document.removeEventListener("click", this.boundHandleClick, true)
  }

  // Typing (input): debounce. Selects/dates/etc (change): save immediately so one
  // field change is not blocked by continued typing in another field.
  markDirty() {
    this.noteDirty()
    this.scheduleSave(this.debounceMsValue)
  }

  markDirtyAndSaveNow() {
    this.noteDirty()
    this.scheduleSave(0)
  }

  noteDirty() {
    this.dirty = true
    this.saveGeneration += 1
    if (!this.saving) {
      this.updateStatus("")
    }
  }

  handleSubmit() {
    this.clearDebounce()
    this.clearRetry()
    this.abortInFlight()
    this.saving = true
    this.updateStatus("Saving…")
  }

  scheduleSave(delayMs = this.debounceMsValue) {
    this.clearDebounce()
    this.debounceTimer = window.setTimeout(() => this.save(), delayMs)
  }

  async save(retryAttempt = 0) {
    if (!this.dirty || this.saving) return

    const form = this.formElement()
    if (!form) return

    this.clearRetry()
    this.saving = true
    this.updateStatus("Saving…")

    const generationAtStart = this.saveGeneration
    const controller = new AbortController()
    this.abortController = controller
    let abortedByTimeout = false
    const timeoutId = window.setTimeout(() => {
      abortedByTimeout = true
      controller.abort()
    }, this.timeoutMsValue)

    let succeeded = false

    try {
      const formData = new FormData(form)
      formData.append("autosave", "1")
      formData.append("save_and_continue_editing", "1")

      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      const response = await fetch(form.action, {
        method: (form.method || "patch").toUpperCase(),
        headers: {
          Accept: "application/json",
          ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
        },
        body: formData,
        signal: controller.signal
      })

      const data = await response.json().catch(() => ({}))

      if (response.ok && data.ok) {
        // Only clear dirty if nothing changed since we captured FormData.
        if (this.saveGeneration === generationAtStart) {
          this.dirty = false
        }
        this.lastError = null
        succeeded = true
        this.updateStatus(`Saved ${this.formatTime(data.saved_at)}`)
        this.applySheetRowChrome(data.sheet_row)
      } else {
        this.lastError = data.errors || "Save failed"
        this.showSaveError(retryAttempt)
      }
    } catch (_error) {
      // Disconnect (or handleSubmit) aborted the request — don't surface an error.
      if (controller.signal.aborted && !abortedByTimeout) return

      this.lastError = abortedByTimeout ? "Save timed out" : "Network error"
      this.showSaveError(retryAttempt)
    } finally {
      window.clearTimeout(timeoutId)
      if (this.abortController === controller) {
        this.abortController = null
      }
      this.saving = false
    }

    // Debounced saves that fired while `saving` were no-ops; re-schedule if still dirty.
    if (succeeded && this.dirty) {
      this.scheduleSave(this.debounceMsValue)
    }
  }

  formElement() {
    if (this.element.tagName === "FORM") return this.element
    return this.element.querySelector("form")
  }

  showSaveError(retryAttempt) {
    if (retryAttempt === 0) {
      this.updateStatus("Couldn't save — retrying…", true)
      this.retryTimer = window.setTimeout(() => this.save(1), 5000)
    } else {
      const detail = this.lastError && this.lastError !== "Save failed" ? `: ${this.lastError}` : ""
      this.updateStatus(`Couldn't save — please try again${detail}`, true)
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

  // Bulk Edit Goals: refresh the left status strip color/popover after save.
  applySheetRowChrome(sheetRow) {
    if (!sheetRow || !sheetRow.row_classes) return

    const row = this.element.closest(".goals-sheet-row")
    if (!row) return

    row.className = sheetRow.row_classes

    const statusBtn = row.querySelector(".goals-sheet-row__status")
    if (!statusBtn) return

    if (sheetRow.popover_title != null) {
      statusBtn.setAttribute("aria-label", sheetRow.popover_title)
      statusBtn.setAttribute("title", sheetRow.popover_title)
      statusBtn.setAttribute("data-bs-title", sheetRow.popover_title)
    }
    if (sheetRow.popover_content != null) {
      statusBtn.setAttribute("data-bs-content", sheetRow.popover_content)
    }

    const Popover = window.bootstrap?.Popover
    if (!Popover) return

    const existing = Popover.getInstance(statusBtn)
    if (existing) existing.dispose()
    new Popover(statusBtn, { html: true, sanitize: false })
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

  abortInFlight() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
  }
}
