import { Controller } from "@hotwired/stimulus"

const MERMAID_SRC = "https://cdnjs.cloudflare.com/ajax/libs/mermaid/11.12.0/mermaid.min.js"

export default class extends Controller {
  static values = {
    lazy: { type: Boolean, default: false },
    source: String,
    clickUrls: { type: Object, default: {} }
  }

  connect() {
    this.rendered = false
    this.chartId = `assignment-mermaid-${this.element.id || Math.random().toString(36).slice(2)}`
    if (!this.lazyValue) this.render()
  }

  disconnect() {
    this.rendered = false
    this.element.innerHTML = ""
  }

  render() {
    if (this.rendered) return

    const source = (this.sourceValue || "").trim()
    if (!source) return

    this.ensureMermaid(async () => {
      const mermaid = window.mermaid
      mermaid.initialize({
        startOnLoad: false,
        flowchart: { useMaxWidth: true, htmlLabels: false, curve: "basis" },
        securityLevel: "loose"
      })

      try {
        const { svg, bindFunctions } = await mermaid.render(this.chartId, source)
        this.element.innerHTML = svg
        bindFunctions?.()
        this.bindNodeClicks()
        this.rendered = true
      } catch (error) {
        this.showError(error)
      }
    })
  }

  bindNodeClicks() {
    const urls = this.clickUrlsValue || {}
    Object.entries(urls).forEach(([nodeId, url]) => {
      if (!url) return

      this.element.querySelectorAll(`[id*="${nodeId}"]`).forEach((nodeEl) => {
        nodeEl.style.cursor = "pointer"
        nodeEl.addEventListener("click", () => window.location.assign(url))
      })
    })
  }

  showError(error) {
    const message = error?.message || error?.str || "Could not render flowchart."
    const notice = document.createElement("p")
    notice.className = "text-danger small mb-0"
    notice.textContent = message
    this.element.replaceChildren(notice)
  }

  ensureMermaid(callback, attempts = 0) {
    if (typeof window.mermaid !== "undefined") {
      callback()
      return
    }

    const existing = document.querySelector(`script[src="${MERMAID_SRC}"]`)
    if (existing) {
      if (attempts < 100) {
        setTimeout(() => this.ensureMermaid(callback, attempts + 1), 100)
      }
      return
    }

    const script = document.createElement("script")
    script.src = MERMAID_SRC
    script.async = false
    script.dataset.turboTrack = "reload"
    script.onload = () => callback()
    document.head.appendChild(script)
  }
}
