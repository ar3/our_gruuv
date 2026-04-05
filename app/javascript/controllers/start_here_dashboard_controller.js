import { Controller } from "@hotwired/stimulus"

// Lazy-loads Start Here card bodies via JSON (partial per widget or legacy dashboard_content).
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (!this.hasUrlValue) return
    const ids = this.slotElements.map((el) => el.dataset.widgetId).filter(Boolean)
    if (ids.length === 0) return
    this.loadWidgets(ids)
  }

  get slotElements() {
    return Array.from(this.element.querySelectorAll('[data-start-here-dashboard-target="slot"]'))
  }

  async loadWidgets(widgetIds) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    let response
    try {
      response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          ...(token ? { "X-CSRF-Token": token } : {}),
        },
        body: JSON.stringify({ widget_ids: widgetIds }),
        credentials: "same-origin",
      })
    } catch (_err) {
      widgetIds.forEach((id) => {
        const slot = this.slotForWidgetId(id)
        if (slot) this.showSlotNetworkError(slot)
      })
      return
    }

    if (!response.ok) {
      widgetIds.forEach((id) => {
        const slot = this.slotForWidgetId(id)
        if (slot) this.showSlotHttpError(slot, response.status)
      })
      return
    }

    let data
    try {
      data = await response.json()
    } catch (_err) {
      widgetIds.forEach((id) => {
        const slot = this.slotForWidgetId(id)
        if (slot) this.showSlotNetworkError(slot)
      })
      return
    }

    const widgets = data.widgets || {}
    widgetIds.forEach((id) => {
      const slot = this.slotForWidgetId(id)
      if (!slot) return
      const payload = widgets[id]
      if (!payload) {
        this.showSlotHttpError(slot, response.status)
        return
      }
      if (payload.ok && typeof payload.html === "string") {
        this.fillSlotSuccess(slot, id, payload.html)
      } else {
        this.showSlotApplicationError(slot, payload.error || "Something went wrong.")
      }
    })
  }

  retry(event) {
    event.preventDefault()
    const slot = event.currentTarget.closest('[data-start-here-dashboard-target="slot"]')
    if (!slot) return
    const id = slot.dataset.widgetId
    if (!id) return
    this.resetSlot(slot)
    this.loadWidgets([id])
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
