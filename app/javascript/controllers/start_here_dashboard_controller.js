import { Controller } from "@hotwired/stimulus"

// Lazy-loads Start Here card bodies via JSON (partial per widget or legacy dashboard_content).
// Optional loadOnScroll: wait until the dashboard region enters the viewport before fetching
// (used when embedded on OG Academy so most visitors never trigger widget AJAX).
export default class extends Controller {
  static values = {
    url: String,
    loadOnScroll: { type: Boolean, default: false },
  }

  connect() {
    this.activeLoadAbortControllers = new Set()
    if (!this.hasUrlValue) return
    const ids = this.slotElements.map((el) => el.dataset.widgetId).filter(Boolean)
    if (ids.length === 0) return

    if (this.loadOnScrollValue) {
      this.observeAndLoad(ids)
    } else {
      this.loadWidgets(ids)
    }
  }

  disconnect() {
    if (this._scrollObserver) {
      this._scrollObserver.disconnect()
      this._scrollObserver = null
    }
    if (this._scrollGateHandler) {
      window.removeEventListener("scroll", this._scrollGateHandler, { passive: true })
      this._scrollGateHandler = null
    }
    this.abortAllLoads()
  }

  observeAndLoad(ids) {
    // Snapshot fold position at connect. Tall viewports + short lazy placeholders above can
    // put this region on-screen without the user scrolling — still wait for a real scroll then.
    this._startedBelowFold =
      this.element.getBoundingClientRect().top > window.innerHeight - 40
    this._scrollLoadStarted = false

    const readyToLoad = (isIntersecting) => {
      if (!isIntersecting) return false
      if (this._startedBelowFold) return true
      return window.scrollY > 80
    }

    const beginLoad = () => {
      if (this._scrollLoadStarted) return
      this._scrollLoadStarted = true
      if (this._scrollObserver) {
        this._scrollObserver.disconnect()
        this._scrollObserver = null
      }
      if (this._scrollGateHandler) {
        window.removeEventListener("scroll", this._scrollGateHandler, { passive: true })
        this._scrollGateHandler = null
      }
      this.loadWidgets(ids)
    }

    if (typeof IntersectionObserver === "undefined") {
      this._scrollGateHandler = () => {
        const rect = this.element.getBoundingClientRect()
        const visible = rect.top < window.innerHeight && rect.bottom > 0
        if (readyToLoad(visible)) beginLoad()
      }
      window.addEventListener("scroll", this._scrollGateHandler, { passive: true })
      this._scrollGateHandler()
      return
    }

    this._scrollObserver = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => readyToLoad(entry.isIntersecting))) beginLoad()
      },
      { root: null, rootMargin: "0px", threshold: 0 }
    )
    this._scrollObserver.observe(this.element)

    // If already intersecting but still waiting on scrollY, re-check on scroll.
    if (!this._startedBelowFold) {
      this._scrollGateHandler = () => {
        const rect = this.element.getBoundingClientRect()
        const visible = rect.top < window.innerHeight && rect.bottom > 0
        if (readyToLoad(visible)) beginLoad()
      }
      window.addEventListener("scroll", this._scrollGateHandler, { passive: true })
    }
  }

  get slotElements() {
    return Array.from(this.element.querySelectorAll('[data-start-here-dashboard-target="slot"]'))
  }

  abortAllLoads() {
    if (!this.activeLoadAbortControllers) return
    this.activeLoadAbortControllers.forEach((controller) => controller.abort())
    this.activeLoadAbortControllers.clear()
  }

  loadWasAborted(abortController, err) {
    return abortController.signal.aborted || err?.name === "AbortError"
  }

  async loadWidgets(widgetIds) {
    await Promise.all(widgetIds.map((id) => this.loadSingleWidget(id)))
  }

  async loadSingleWidget(widgetId) {
    const abortController = new AbortController()
    this.activeLoadAbortControllers.add(abortController)

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const slot = this.slotForWidgetId(widgetId)
    if (!slot) {
      this.activeLoadAbortControllers.delete(abortController)
      return
    }

    let response
    try {
      response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          ...(token ? { "X-CSRF-Token": token } : {}),
        },
        body: JSON.stringify({ widget_ids: [widgetId] }),
        credentials: "same-origin",
        signal: abortController.signal,
      })
    } catch (err) {
      if (!this.loadWasAborted(abortController, err)) this.showSlotNetworkError(slot)
      return
    } finally {
      this.activeLoadAbortControllers.delete(abortController)
    }

    if (this.loadWasAborted(abortController)) return

    if (!response.ok) {
      this.showSlotHttpError(slot, response.status)
      return
    }

    let data
    try {
      data = await response.json()
    } catch (err) {
      if (!this.loadWasAborted(abortController, err)) this.showSlotNetworkError(slot)
      return
    }

    if (this.loadWasAborted(abortController)) return

    const payload = (data.widgets || {})[widgetId]
    if (!payload) {
      this.showSlotHttpError(slot, response.status)
      return
    }
    if (payload.ok && typeof payload.html === "string") {
      this.fillSlotSuccess(slot, widgetId, payload.html)
    } else {
      this.showSlotApplicationError(slot, payload.error || "Something went wrong.")
    }
  }

  retry(event) {
    event.preventDefault()
    const slot = event.currentTarget.closest('[data-start-here-dashboard-target="slot"]')
    if (!slot) return
    const id = slot.dataset.widgetId
    if (!id) return
    this.resetSlot(slot)
    this.loadSingleWidget(id)
  }

  slotForWidgetId(widgetId) {
    return this.slotElements.find((el) => el.dataset.widgetId === widgetId)
  }

  resetSlot(slot) {
    const sk = slot.querySelector(".start-here-dashboard-skeleton")
    const body = slot.querySelector(".start-here-dashboard-body")
    const err = slot.querySelector(".start-here-dashboard-error")
    if (sk) sk.classList.remove("d-none")
    if (body) {
      body.classList.add("d-none")
      body.innerHTML = ""
    }
    if (err) err.classList.add("d-none")
  }

  fillSlotSuccess(slot, widgetId, html) {
    const sk = slot.querySelector(".start-here-dashboard-skeleton")
    const body = slot.querySelector(".start-here-dashboard-body")
    const err = slot.querySelector(".start-here-dashboard-error")
    if (sk) sk.classList.add("d-none")
    if (err) err.classList.add("d-none")
    if (body) {
      body.innerHTML = html
      body.classList.remove("d-none")
      this.element.dispatchEvent(
        new CustomEvent("start-here:widget-dashboard-loaded", {
          bubbles: true,
          detail: { widgetId, element: body },
        })
      )
    }
  }

  showSlotApplicationError(slot, message) {
    const sk = slot.querySelector(".start-here-dashboard-skeleton")
    const body = slot.querySelector(".start-here-dashboard-body")
    const err = slot.querySelector(".start-here-dashboard-error")
    if (sk) sk.classList.add("d-none")
    if (body) {
      body.classList.add("d-none")
      body.innerHTML = ""
    }
    if (err) {
      const msgEl = err.querySelector(".start-here-dashboard-error-message")
      if (msgEl) msgEl.textContent = message
      err.classList.remove("d-none")
    }
  }

  showSlotNetworkError(slot) {
    this.showSlotApplicationError(slot, "Could not load. Check your connection.")
  }

  showSlotHttpError(slot, status) {
    this.showSlotApplicationError(slot, `Could not load (HTTP ${status}).`)
  }
}
