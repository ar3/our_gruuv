import { Controller } from "@hotwired/stimulus"

// Conversational Ask OG: thread bubbles, composer, poll, confirm actions.
export default class extends Controller {
  static values = {
    createUrl: String,
    query: String,
    csrfToken: String,
    autoStart: { type: Boolean, default: false },
    consultationId: Number,
    statusUrl: String,
    replyUrl: String
  }

  static targets = ["thread", "waiting", "phaseLabel", "error", "composer", "input", "sendButton"]

  connect() {
    this.pollTimer = null
    if (this.hasConsultationIdValue && this.consultationIdValue && this.statusUrlValue) {
      this.startPolling()
    } else if (this.autoStartValue && this.queryValue) {
      this.start()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  async start() {
    this.clearError()
    this.showWaiting("Asking OG…")
    this.setComposerEnabled(false)

    try {
      const body = new URLSearchParams()
      body.set("q", this.queryValue)

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
        this.showError(data.error || "Could not start Ask OG.")
        this.hideWaiting()
        this.setComposerEnabled(true)
        return
      }

      this.consultationIdValue = data.consultation_id
      this.statusUrlValue = data.status_url
      this.replyUrlValue = data.reply_url
      this.startPolling()
    } catch (e) {
      this.showError("Could not start Ask OG.")
      this.hideWaiting()
      this.setComposerEnabled(true)
    }
  }

  handleEnter(event) {
    if (event.key !== "Enter" || event.shiftKey) return
    event.preventDefault()
    this.send(event)
  }

  async send(event) {
    event?.preventDefault()
    if (!this.hasInputTarget) return

    const message = this.inputTarget.value.trim()
    if (!message) return

    if (!this.replyUrlValue) {
      if (!this.queryValue) this.queryValue = message
      this.inputTarget.value = ""
      await this.start()
      return
    }

    this.clearError()
    this.setComposerEnabled(false)
    this.appendOptimisticUserBubble(message)
    this.inputTarget.value = ""
    this.showWaiting("Thinking…")

    try {
      const body = new URLSearchParams()
      body.set("message", message)

      const response = await fetch(this.replyUrlValue, {
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
        this.showError(data.error || "Could not send message.")
        this.hideWaiting()
        this.setComposerEnabled(true)
        return
      }

      this.statusUrlValue = data.status_url || this.statusUrlValue
      this.replyUrlValue = data.reply_url || this.replyUrlValue
      this.startPolling()
    } catch (e) {
      this.showError("Could not send message.")
      this.hideWaiting()
      this.setComposerEnabled(true)
    }
  }

  startPolling() {
    this.stopPolling()
    this.pollTimer = setInterval(() => this.fetchStatus(), 2000)
    this.fetchStatus()
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async fetchStatus() {
    if (!this.statusUrlValue) return

    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      const data = await response.json()
      if (!response.ok) {
        this.showError("Could not load Ask OG status.")
        this.stopPolling()
        this.hideWaiting()
        this.setComposerEnabled(true)
        return
      }

      if (data.reply_url) this.replyUrlValue = data.reply_url
      this.renderThread(data)

      if (data.status === "pending" || data.status === "processing") {
        this.showWaiting(data.status === "pending" ? "Queued…" : "Thinking…")
        this.setComposerEnabled(false)
        return
      }

      this.stopPolling()
      this.hideWaiting()
      this.setComposerEnabled(true)

      if (data.status === "failed") {
        this.showError(data.error_message || "Ask OG failed.")
      }
    } catch (e) {
      this.showError("Could not load Ask OG status.")
      this.stopPolling()
      this.hideWaiting()
      this.setComposerEnabled(true)
    }
  }

  renderThread(data) {
    if (!this.hasThreadTarget) return
    this.threadTarget.innerHTML = ""
    const messages = Array.isArray(data.messages) ? data.messages : []

    messages.forEach((message, messageIndex) => {
      const row = document.createElement("div")
      row.className = `ask-og-bubble-row ask-og-bubble-row--${message.role}`

      const bubble = document.createElement("div")
      bubble.className = `ask-og-bubble ask-og-bubble--${message.role}`

      if (message.role === "assistant" && message.body_html) {
        bubble.innerHTML = message.body_html
        bubble.classList.add("markdown-content")
      } else {
        bubble.textContent = message.body || ""
      }

      row.appendChild(bubble)
      this.threadTarget.appendChild(row)

      const isLatest = messageIndex === messages.length - 1
      if (isLatest && message.role === "assistant" && Array.isArray(message.proposed_actions)) {
        message.proposed_actions.forEach((action, index) => {
          const wrap = document.createElement("div")
          wrap.className = "ask-og-action-card"
          const summary = document.createElement("p")
          summary.className = "mb-2 small mb-0"
          summary.textContent = action.summary || action.label || "Proposed action"
          const button = document.createElement("button")
          button.type = "button"
          button.className = "btn btn-sm btn-primary mt-2"
          button.textContent = action.label || "Confirm"
          button.addEventListener("click", () => this.confirm(index, button))
          wrap.appendChild(summary)
          wrap.appendChild(button)
          this.threadTarget.appendChild(wrap)
        })
      }
    })

    this.threadTarget.scrollTop = this.threadTarget.scrollHeight
  }

  appendOptimisticUserBubble(message) {
    if (!this.hasThreadTarget) return
    const row = document.createElement("div")
    row.className = "ask-og-bubble-row ask-og-bubble-row--user"
    const bubble = document.createElement("div")
    bubble.className = "ask-og-bubble ask-og-bubble--user"
    bubble.textContent = message
    row.appendChild(bubble)
    this.threadTarget.appendChild(row)
    this.threadTarget.scrollTop = this.threadTarget.scrollHeight
  }

  async confirm(actionIndex, button) {
    if (!this.statusUrlValue) return
    button.disabled = true
    this.clearError()

    const url = this.statusUrlValue.replace(/\/status$/, "/confirm")
    try {
      const body = new URLSearchParams()
      body.set("action_index", String(actionIndex))

      const response = await fetch(url, {
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
        this.showError(data.error || "Could not confirm action.")
        button.disabled = false
        return
      }
      if (data.redirect_path) {
        window.location.href = data.redirect_path
      }
    } catch (e) {
      this.showError("Could not confirm action.")
      button.disabled = false
    }
  }

  setComposerEnabled(enabled) {
    if (this.hasInputTarget) this.inputTarget.disabled = !enabled
    if (this.hasSendButtonTarget) this.sendButtonTarget.disabled = !enabled
  }

  showWaiting(label) {
    if (this.hasWaitingTarget) this.waitingTarget.classList.remove("d-none")
    if (this.hasPhaseLabelTarget) this.phaseLabelTarget.textContent = label
  }

  hideWaiting() {
    if (this.hasWaitingTarget) this.waitingTarget.classList.add("d-none")
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("d-none")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("d-none")
  }
}
