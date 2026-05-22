import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"

export default class extends Controller {
  static values = {
    elementsJson: String,
    rootsJson: { type: String, default: "[]" },
    lazy: { type: Boolean, default: false }
  }

  connect() {
    if (this.lazyValue) return
    this.render()
  }

  initGraph() {
    if (this.cy) return
    this.render()
  }

  resize() {
    this.cy?.resize()
    this.cy?.fit(undefined, 24)
  }

  render() {
    let elements = []
    let roots = []

    try {
      elements = JSON.parse(this.elementsJsonValue || "[]")
      roots = JSON.parse(this.rootsJsonValue || "[]")
    } catch {
      return
    }

    if (!elements.length) return

    this.cy = cytoscape({
      container: this.element,
      elements: elements,
      minZoom: 0.4,
      maxZoom: 2,
      style: [
        {
          selector: "node",
          style: {
            label: "data(label)",
            "text-valign": "center",
            "text-halign": "center",
            "font-size": "11px",
            "text-wrap": "wrap",
            "text-max-width": "120px",
            shape: "roundrectangle",
            width: "label",
            height: "label",
            padding: "10px",
            "background-color": "#f8f9fa",
            "border-width": 1,
            "border-color": "#adb5bd",
            color: "#212529"
          }
        },
        {
          selector: "node[?isCurrent]",
          style: {
            "background-color": "#cfe2ff",
            "border-width": 3,
            "border-color": "#0d6efd",
            "font-weight": "bold"
          }
        },
        {
          selector: "edge",
          style: {
            width: 2,
            "line-color": "#6c757d",
            "target-arrow-color": "#6c757d",
            "target-arrow-shape": "triangle",
            "curve-style": "bezier"
          }
        }
      ],
      layout: this.layoutConfig(roots),
      wheelSensitivity: 0.2
    })

    this.cy.on("tap", "node", (event) => {
      const url = event.target.data("url")
      if (url) window.location.assign(url)
    })
  }

  disconnect() {
    this.cy?.destroy()
    this.cy = null
  }

  layoutConfig(roots) {
    const config = {
      name: "breadthfirst",
      directed: true,
      spacingFactor: 1.35,
      animate: false,
      padding: 24
    }

    if (roots.length > 0) {
      config.roots = `#${roots.join(", #")}`
    }

    return config
  }
}
