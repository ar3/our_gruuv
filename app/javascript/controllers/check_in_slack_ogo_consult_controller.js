import { Controller } from "@hotwired/stimulus"

// Progressive Consult OG on 1-by-1 check-in pages (Slack search + batch extractions).
export default class extends Controller {
  static values = {
    statusUrl: String,
    createUrl: String,
    rateableType: String,
    rateableId: String,
    since: String,
    csrfToken: String
  }

  static targets = [
    "waiting",
    "phaseLabel",
    "progress",
    "detailsLinkWrap",
    "detailsLink",
    "results",
    "objectList",
    "emptyObject",
    "otherLine",
    "error",
    "staleWarning",
    "primaryActions",
    "secondaryActions",
    "refreshButton",
    "strongerButton"
  ]

  connect() {
    this.searchId = null
    this.pollTimer = null
    this.loadInitial()
  }

  disconnect() {
    this.stopPolling()
  }

  async loadInitial() {
    await this.fetchStatus()
  }

  async start(event) {
    event.preventDefault()
    const mode = event.currentTarget.dataset.mode || "fresh"
    this.clearError()
    this.showWaiting("Starting OG consultation…")

    try {
      const body = new URLSearchParams()
      body.set("mode", mode)
      body.set("rateable_type", this.rateableTypeValue)
      body.set("rateable_id", this.rateableIdValue)
      if (this.sinceValue) body.set("since", this.sinceValue)
      if (this.searchId) body.set("search_id", this.searchId)

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

      if (data.needs_slack_oauth && data.oauth_url) {
        window.location.href = data.oauth_url
        return
      }

      if (!response.ok || data.ok === false) {
        this.showError(data.error || "Could not start OG consultation.")
        this.hideWaiting()
        return
      }

      this.render(data)
      if (data.polling) this.startPolling()
    } catch (_error) {
      this.showError("Could not start OG consultation.")
      this.hideWaiting()
    }
  }

  startPolling() {
    this.stopPolling()
    this.pollTimer = window.setInterval(() => this.fetchStatus(), 3000)
  }

  stopPolling() {
    if (this.pollTimer) {
      window.clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async fetchStatus() {
    if (!this.statusUrlValue) return

    try {
      const url = new URL(this.statusUrlValue, window.location.origin)
      url.searchParams.set("rateable_type", this.rateableTypeValue)
      url.searchParams.set("rateable_id", this.rateableIdValue)
      if (this.sinceValue) url.searchParams.set("since", this.sinceValue)
      if (this.searchId) url.searchParams.set("search_id", this.searchId)

      const response = await fetch(url.toString(), { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const data = await response.json()
      this.render(data)
      if (data.polling) {
        if (!this.pollTimer) this.startPolling()
      } else {
        this.stopPolling()
        this.hideWaiting()
      }
    } catch (_error) {
      // Keep polling through transient errors.
    }
  }

  render(data) {
    if (data.search_id) this.searchId = data.search_id

    if (data.polling) {
      const phase =
        data.phase === "searching"
          ? "Searching Slack…"
          : `Running OG consultations… (${data.batches_completed || 0} of ${data.batches_total || 0} complete)`
      this.showWaiting(phase)
    } else if (data.phase === "failed") {
      this.showError(data.search_error || "OG consultation failed.")
      this.hideWaiting()
    } else {
      this.hideWaiting()
    }

    if (this.hasProgressTarget) {
      if (data.batches_total > 0 && data.polling) {
        this.progressTarget.textContent = `${data.batches_completed || 0} of ${data.batches_total} consultations complete`
        this.progressTarget.classList.remove("d-none")
      } else {
        this.progressTarget.classList.add("d-none")
      }
    }

    if (this.hasDetailsLinkWrapTarget && this.hasDetailsLinkTarget) {
      if (data.polling && data.full_results_url) {
        this.detailsLinkTarget.href = data.full_results_url
        this.detailsLinkWrapTarget.classList.remove("d-none")
      } else {
        this.detailsLinkWrapTarget.classList.add("d-none")
      }
    }

    const matches = data.object_matches || []
    const showResults =
      Boolean(data.search_id) &&
      ["extracting", "completed", "failed"].includes(data.phase)
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.toggle("d-none", !showResults)
    }

    if (this.hasObjectListTarget) {
      if (matches.length === 0) {
        this.objectListTarget.innerHTML = ""
      } else {
        this.objectListTarget.innerHTML = matches
          .map((match) => {
            const link = match.batch_url
              ? `<a href="${this.escape(match.batch_url)}" class="small">Open consultation</a>`
              : ""
            const permalink = match.permalink
              ? `<a href="${this.escape(match.permalink)}" target="_blank" rel="noopener" class="small ms-2">Slack</a>`
              : ""
            return `<li class="mb-2">
              <span class="badge text-bg-success me-1">${match.confidence_pct}%</span>
              <span class="text-break">${this.escape(match.short_quote || match.quote_preview || "")}</span>
              <div class="mt-1">${link}${permalink}</div>
            </li>`
          })
          .join("")
      }
    }

    if (this.hasEmptyObjectTarget) {
      if (data.empty_object_message) {
        this.emptyObjectTarget.textContent = data.empty_object_message
        this.emptyObjectTarget.classList.remove("d-none")
      } else {
        this.emptyObjectTarget.classList.add("d-none")
      }
    }

    if (this.hasOtherLineTarget && data.other_message) {
      const url = data.full_results_url
      this.otherLineTarget.innerHTML = url
        ? `${this.escape(data.other_message)} — <a href="${this.escape(url)}">see full results</a>`
        : this.escape(data.other_message)
      this.otherLineTarget.classList.toggle("d-none", !showResults)
    }

    if (this.hasStaleWarningTarget) {
      if (data.consultation_stale && data.stale_warning && showResults) {
        this.staleWarningTarget.textContent = data.stale_warning
        this.staleWarningTarget.classList.remove("d-none")
      } else {
        this.staleWarningTarget.textContent = ""
        this.staleWarningTarget.classList.add("d-none")
      }
    }

    if (this.hasSecondaryActionsTarget) {
      const showSecondary =
        Boolean(data.search_id) &&
        data.phase === "completed" &&
        (data.can_refresh_search || data.can_stronger_model)
      this.secondaryActionsTarget.classList.toggle("d-none", !showSecondary)
    }

    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.classList.toggle("d-none", !data.can_refresh_search)
    }

    if (this.hasStrongerButtonTarget) {
      this.strongerButtonTarget.classList.toggle("d-none", !data.can_stronger_model)
    }

    if (this.hasPrimaryActionsTarget) {
      const hidePrimary = data.polling || (data.phase === "completed" && Boolean(data.search_id))
      this.primaryActionsTarget.classList.toggle("d-none", hidePrimary)
    }
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

  escape(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
