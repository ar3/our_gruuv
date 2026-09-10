import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["g6Pane", "g6Container", "cytoscapePane"]

  static values = {
    g6GraphDataJson: String
  }

  connect() {
    this.g6Graph = null
  }

  disconnect() {
    this.g6Graph?.destroy()
    this.g6Graph = null
  }

  onTabShown(event) {
    const tab = event.target.closest?.('[data-bs-toggle="tab"]') || event.target
    const paneId = tab.getAttribute?.("data-bs-target")
    if (!paneId) return

    if (paneId === "#insights-title-paths-g6-pane") {
      this.initG6()
    } else if (paneId === "#insights-title-paths-cytoscape-pane") {
      this.resizeCytoscape()
    }
  }

  resizeCytoscape() {
    if (!this.hasCytoscapePaneTarget) return

    const graphRoot = this.cytoscapePaneTarget.querySelector("[data-controller~='assignment-accountability-flow']")
    if (!graphRoot) return

    const cytoscapeController = this.application.getControllerForElementAndIdentifier(
      graphRoot,
      "assignment-accountability-flow"
    )
    cytoscapeController?.resize()
  }

  initG6() {
    if (this.g6Graph || !this.hasG6ContainerTarget) return

    let graphData = { nodes: [], edges: [] }
    try {
      graphData = JSON.parse(this.g6GraphDataJsonValue || "{}")
    } catch {
      return
    }

    if (!graphData.nodes?.length) return

    const container = this.g6ContainerTarget

    window.setTimeout(async () => {
      try {
        const G6 = await this.ensureG6()
        const { Graph } = G6
        const width = container.clientWidth || container.offsetWidth || 800
        const height = Math.max(480, container.clientHeight || 0)

        container.innerHTML = ""

        this.g6Graph = new Graph({
          container,
          width,
          height,
          data: graphData,
          layout: false,
          node: {
            type: "rect",
            style: {
              size: [150, 44],
              label: true,
              labelText: (datum) => datum.style?.labelText || datum.data?.label || datum.id,
              labelPlacement: "center",
              labelWordWrap: true,
              labelMaxWidth: "90%",
              labelFontSize: 11,
              labelFill: "#212529",
              fill: (datum) => datum.style?.fill || (datum.data?.highlightTier === "external" ? "#f1f3f5" : "#e7f1ff"),
              stroke: (datum) => datum.style?.stroke || (datum.data?.highlightTier === "external" ? "#ced4da" : "#6ea8fe"),
              lineWidth: 2,
              radius: 4,
              cursor: "pointer"
            }
          },
          edge: {
            type: "quadratic",
            style: {
              stroke: (datum) => datum.data?.lineColor || datum.style?.stroke || "#6c757d",
              lineWidth: 2,
              endArrow: true,
              label: true,
              labelText: (datum) => datum.data?.label || "",
              labelFontSize: 10,
              labelFill: "#6c757d",
              labelBackground: true,
              labelBackgroundFill: "#ffffff",
              labelBackgroundOpacity: 0.85
            }
          },
          behaviors: ["drag-canvas", "zoom-canvas", "drag-element"],
          autoFit: "view"
        })

        this.g6Graph.on("node:click", (event) => {
          const nodeId = event.target?.id
          if (!nodeId) return

          const nodeData = this.g6Graph.getNodeData(nodeId)
          const url = nodeData?.data?.url
          if (url) window.location.assign(url)
        })

        await this.g6Graph.render()
      } catch (error) {
        console.error("[G6] Failed to render title paths graph", error)
        container.replaceChildren(this.g6ErrorElement("Could not load G6 graph."))
      }
    }, 50)
  }

  ensureG6(attempts = 0) {
    const G6_SRC = "https://unpkg.com/@antv/g6@5.0.49/dist/g6.min.js"

    return new Promise((resolve, reject) => {
      if (window.G6?.Graph) {
        resolve(window.G6)
        return
      }

      const existing = document.querySelector(`script[src="${G6_SRC}"]`)
      if (existing) {
        if (attempts < 100) {
          setTimeout(() => {
            this.ensureG6(attempts + 1).then(resolve).catch(reject)
          }, 100)
        } else {
          reject(new Error("G6 library timed out"))
        }
        return
      }

      const script = document.createElement("script")
      script.src = G6_SRC
      script.async = false
      script.dataset.turboTrack = "reload"
      script.onload = () => {
        if (window.G6?.Graph) resolve(window.G6)
        else reject(new Error("G6 script loaded without Graph export"))
      }
      script.onerror = () => reject(new Error("G6 script failed to load"))
      document.head.appendChild(script)
    })
  }

  g6ErrorElement(message) {
    const notice = document.createElement("p")
    notice.className = "text-danger small mb-0"
    notice.textContent = message
    return notice
  }
}
