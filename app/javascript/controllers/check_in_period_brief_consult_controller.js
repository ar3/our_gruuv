import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel",
    "link",
    "linkLabel",
    "waiting",
    "waitingText",
    "elapsed",
    "error",
    "errorText",
    "results",
    "completedAt",
    "copySource",
    "copyButton",
    "copyFeedback",
    "appendButton",
    "appendFeedback",
    "copyActions",
    "actions",
    "rerunButton",
    "positionFormula"
  ]

  static values = {
    open: { type: Boolean, default: false },
    hasConsult: { type: Boolean, default: false },
    summarizeLabel: { type: String, default: "Consult OG to summarize this period" },
    createUrl: String,
    statusUrl: String,
    checkInKind: String,
    checkInId: String,
    csrfToken: String,
    autoPoll: { type: Boolean, default: false },
    notesFieldSuffix: String,
    appendHeader: String
  }

  connect() {
    this.syncOpen()
    this.syncLinkLabel()
    if (this.autoPollValue) this.startPolling()
  }

  disconnect() {
    this.stopPolling()
    this.stopElapsed()
  }

  linkClick(event) {
    event.preventDefault()

    if (!this.hasConsultValue) {
      this.openValue = true
      this.syncOpen()
      this.start()
      return
    }

    this.openValue = !this.openValue
    this.syncOpen()
  }

  rerun(event) {
    event.preventDefault()
    this.openValue = true
    this.syncOpen()
    this.start()
  }

  async start() {
    this.clearError()
    this.hideResults()
    this.hideActions()
    this.showWaiting("pending")
    this.hasConsultValue = true
    this.syncLinkLabel()

    try {
      const body = new URLSearchParams()
      body.set("check_in_kind", this.checkInKindValue)
      body.set("check_in_id", this.checkInIdValue)

      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "X-CSRF-Token": this.csrfTokenValue
        },
        body: body.toString()
      })
      const data = await response.json()

      if (!response.ok || data.ok === false) {
        this.showError(data.error || "Could not start period brief.")
        this.hideWaiting()
        return
      }

      this.applyStatus(data)
      if (data.polling) this.startPolling()
    } catch (_error) {
      this.showError("Could not start period brief.")
      this.hideWaiting()
    }
  }

  startPolling() {
    this.stopPolling()
    this.poll()
    this.pollTimer = window.setInterval(() => this.poll(), 3000)
  }

  stopPolling() {
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
      this.applyStatus(data)

      if (data.status === "completed" || data.status === "failed" || data.status === "none") {
        this.stopPolling()
      } else if (!this.pollTimer) {
        this.startPolling()
      }
    } catch (_error) {
      // Keep polling; transient failures are expected.
    }
  }

  applyStatus(data) {
    const status = data.status

    if (status === "pending" || status === "processing") {
      this.showWaiting(status)
      this.hideResults()
      this.hideActions()
      this.clearError()
      this.updateElapsed(data.elapsed_seconds)
      this.startElapsed(data.elapsed_seconds)
      return
    }

    this.stopElapsed()
    this.hideWaiting()

    if (status === "failed") {
      this.showError(data.error_message ? `Consultation failed: ${data.error_message}` : "Consultation failed.")
      this.hideResults()
      this.showActions({ showCopy: false })
      return
    }

    if (status === "completed") {
      this.clearError()
      this.showResults(data)
      this.showActions({ showCopy: true })
      this.hasConsultValue = true
      this.syncLinkLabel()
    }
  }

  showWaiting(status) {
    if (!this.hasWaitingTarget) return
    this.waitingTarget.classList.remove("d-none")
    if (this.hasWaitingTextTarget) {
      this.waitingTextTarget.textContent = `Period brief is ${status}…`
    }
  }

  hideWaiting() {
    if (!this.hasWaitingTarget) return
    this.waitingTarget.classList.add("d-none")
  }

  showResults(data) {
    if (this.hasPositionFormulaTarget) this.positionFormulaTarget.classList.add("d-none")
    if (!this.hasResultsTarget) return
    this.resultsTarget.classList.remove("d-none")
    if (this.hasCopySourceTarget && data.output_text) {
      this.copySourceTarget.textContent = data.output_text
    }
    if (this.hasCompletedAtTarget) {
      this.completedAtTarget.textContent = data.completed_at_display || ""
    }
  }

  hideResults() {
    if (this.hasPositionFormulaTarget) this.positionFormulaTarget.classList.remove("d-none")
    if (!this.hasResultsTarget) return
    this.resultsTarget.classList.add("d-none")
  }

  showActions({ showCopy }) {
    if (this.hasActionsTarget) this.actionsTarget.classList.remove("d-none")
    if (this.hasCopyActionsTarget) {
      this.copyActionsTarget.classList.toggle("d-none", !showCopy)
    }
  }

  hideActions() {
    if (this.hasActionsTarget) this.actionsTarget.classList.add("d-none")
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.classList.remove("d-none")
    if (this.hasErrorTextTarget) this.errorTextTarget.textContent = message
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.classList.add("d-none")
    if (this.hasErrorTextTarget) this.errorTextTarget.textContent = ""
  }

  syncOpen() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.toggle("d-none", !this.openValue)
  }

  syncLinkLabel() {
    if (!this.hasLinkLabelTarget) return
    this.linkLabelTarget.textContent = this.hasConsultValue
      ? "Consult OG again"
      : this.summarizeLabelValue
  }

  updateElapsed(seconds) {
    if (!this.hasElapsedTarget) return
    const value = Math.max(parseInt(seconds || 0, 10), 0)
    this.elapsedBaseSeconds = value
    this.elapsedBaseAt = Date.now()
    this.elapsedTarget.textContent = this.formatElapsed(value)
  }

  startElapsed(seconds) {
    this.updateElapsed(seconds)
    this.stopElapsedTick()
    this.elapsedTickTimer = window.setInterval(() => {
      const base = this.elapsedBaseSeconds || 0
      const startedAt = this.elapsedBaseAt || Date.now()
      const elapsed = base + Math.floor((Date.now() - startedAt) / 1000)
      if (this.hasElapsedTarget) this.elapsedTarget.textContent = this.formatElapsed(elapsed)
    }, 1000)
  }

  stopElapsed() {
    this.stopElapsedTick()
  }

  stopElapsedTick() {
    if (this.elapsedTickTimer) {
      window.clearInterval(this.elapsedTickTimer)
      this.elapsedTickTimer = null
    }
  }

  formatElapsed(totalSeconds) {
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = totalSeconds % 60
    return `(${minutes}:${String(seconds).padStart(2, "0")})`
  }

  async copy(event) {
    event.preventDefault()
    if (!this.hasCopySourceTarget) return

    const text = this.copySourceTarget.innerText || this.copySourceTarget.textContent || ""
    if (!text.trim()) return

    try {
      await navigator.clipboard.writeText(text.trim())
      this.showCopied()
    } catch (_error) {
      this.fallbackCopy(text.trim())
    }
  }

  appendToNotes(event) {
    event.preventDefault()
    if (!this.hasCopySourceTarget) return

    const brief = (this.copySourceTarget.innerText || this.copySourceTarget.textContent || "").trim()
    if (!brief) return

    const notesField = this.findNotesField()
    if (!notesField) {
      this.showAppendFeedback("Notes field not found")
      return
    }

    const header = this.appendHeaderValue || "<Notes>"
    const separator = "=========="
    const block = `${header}\n\n\n${separator}\n${brief}`
    const existing = notesField.value || ""
    notesField.value = existing.trim().length > 0 ? `${existing.replace(/\s+$/, "")}\n\n${block}` : block
    notesField.dispatchEvent(new Event("input", { bubbles: true }))
    notesField.dispatchEvent(new Event("change", { bubbles: true }))
    this.showAppendFeedback("Appended")
  }

  findNotesField() {
    const suffix = this.notesFieldSuffixValue
    if (!suffix) return null

    const fields = Array.from(document.querySelectorAll("textarea[name]"))
    return fields.find((field) => {
      const name = field.getAttribute("name") || ""
      return name.endsWith(`[${suffix}]`) || name.endsWith(suffix)
    }) || null
  }

  fallbackCopy(text) {
    const area = document.createElement("textarea")
    area.value = text
    area.setAttribute("readonly", "")
    area.style.position = "absolute"
    area.style.left = "-9999px"
    document.body.appendChild(area)
    area.select()
    try {
      document.execCommand("copy")
      this.showCopied()
    } finally {
      document.body.removeChild(area)
    }
  }

  showCopied() {
    if (!this.hasCopyFeedbackTarget) return
    this.copyFeedbackTarget.classList.remove("d-none")
    window.clearTimeout(this.copyTimer)
    this.copyTimer = window.setTimeout(() => {
      this.copyFeedbackTarget.classList.add("d-none")
    }, 2000)
  }

  showAppendFeedback(message) {
    if (!this.hasAppendFeedbackTarget) return
    this.appendFeedbackTarget.textContent = message
    this.appendFeedbackTarget.classList.remove("d-none")
    window.clearTimeout(this.appendTimer)
    this.appendTimer = window.setTimeout(() => {
      this.appendFeedbackTarget.classList.add("d-none")
    }, 2000)
  }
}
