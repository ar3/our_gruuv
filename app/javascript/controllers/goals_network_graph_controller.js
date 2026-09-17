import { Controller } from "@hotwired/stimulus"

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

export default class extends Controller {
  static targets = [
    "organizationPane",
    "organizationContainer",
    "cytoscapePane"
  ]

  static values = {
    organizationDataJson: String,
    deferInit: { type: Boolean, default: false }
  }

  connect() {
    this.organizationChart = null
    this.boundOnCollapseShown = this.onSectionShown.bind(this)
    this.collapseEl = this.element.closest(".collapse")

    if (this.deferInitValue) {
      this.collapseEl?.addEventListener("shown.bs.collapse", this.boundOnCollapseShown)
      return
    }

    window.setTimeout(() => this.initCytoscape(), 50)
  }

  disconnect() {
    this.collapseEl?.removeEventListener("shown.bs.collapse", this.boundOnCollapseShown)
    this.organizationChart?.destroy()
    this.organizationChart = null
  }

  onSectionShown() {
    window.setTimeout(() => this.initCytoscape(), 50)
  }

  onTabShown(event) {
    const tab = event.target.closest?.('[data-bs-toggle="tab"]') || event.target
    const paneId = tab.getAttribute?.("data-bs-target")
    if (!paneId) return

    if (paneId.endsWith("-organization-pane") || paneId.includes("-organization-pane")) {
      this.initOrganizationChart()
      this.reflowOrganizationChart()
    } else if (paneId.endsWith("-cytoscape-pane") || paneId.includes("-cytoscape-pane")) {
      this.initCytoscape()
    }
  }

  initOrganizationChart() {
    if (this.organizationChart || !this.hasOrganizationContainerTarget) return

    const hc = window.Highcharts
    if (!hc?.seriesTypes?.organization) {
      this.waitForOrganizationModule(() => this.initOrganizationChart())
      return
    }

    let chartData = { nodes: [], links: [] }
    try {
      chartData = JSON.parse(this.organizationDataJsonValue || "{}")
    } catch {
      return
    }

    if (!chartData.nodes?.length) return

    const container = this.organizationContainerTarget
    const chartHeight = Math.max(360, Math.min(720, chartData.nodes.length * 36))
    const syncLabels = (chart) => this.syncOrganizationLabelSizes(chart)

    this.organizationChart = hc.chart(container, {
      chart: {
        type: "organization",
        inverted: true,
        height: chartHeight,
        events: {
          load() { syncLabels(this) },
          render() { syncLabels(this) }
        }
      },
      title: { text: null },
      accessibility: { enabled: false },
      series: [{
        type: "organization",
        name: "Goals",
        keys: ["from", "to"],
        data: (chartData.links || []).map((link) => [link.from, link.to]),
        nodes: chartData.nodes,
        colorByPoint: false,
        color: "#0d6efd",
        dataLabels: {
          color: "white",
          useHTML: true,
          allowOverlap: true,
          style: {
            fontSize: "11px",
            fontWeight: "600",
            textOverflow: "clip",
            textOutline: "none",
            cursor: "pointer",
            whiteSpace: "normal"
          },
          nodeFormatter() {
            const name = escapeHtml(this.point?.name || this.key || "")
            return `<div class="goals-network-org-node-label"><span class="goals-network-org-node-text">${name}</span></div>`
          }
        },
        borderColor: "white",
        // inverted:true → nodeWidth is the short vertical size of each card
        nodeWidth: 64,
        nodePadding: 10,
        cursor: "pointer",
        point: {
          events: {
            click: function() {
              const url = this.url || this.options?.url
              if (url) window.location.assign(url)
            }
          }
        }
      }],
      tooltip: {
        outside: true,
        formatter: function() {
          if (this.point?.node) {
            return `<b>${this.point.node.name}</b>`
          }
          if (this.point?.from && this.point?.to) {
            return `${this.point.fromNode?.name || this.point.from} → ${this.point.toNode?.name || this.point.to}`
          }
          return false
        }
      },
      exporting: { enabled: false }
    })

    window.setTimeout(() => syncLabels(this.organizationChart), 0)
  }

  // Size each HTML label to its SVG node so text can wrap across the full card.
  syncOrganizationLabelSizes(chart) {
    const series = chart?.series?.[0]
    if (!series?.nodes?.length) return

    series.nodes.forEach((node) => {
      const dataLabel = node.dataLabel
      const graphic = node.graphic
      if (!dataLabel) return

      let width = 0
      let height = 0

      if (graphic?.getBBox) {
        try {
          const bbox = graphic.getBBox()
          // Inverted org cards are short-and-wide; bbox axes can be swapped.
          width = Math.max(bbox.width || 0, bbox.height || 0)
          height = Math.min(bbox.width || 0, bbox.height || 0)
        } catch {
          // ignore detached SVG nodes
        }
      }

      if ((!width || !height) && node.shapeArgs) {
        const shapeW = node.shapeArgs.width || 0
        const shapeH = node.shapeArgs.height || 0
        width = Math.max(shapeW, shapeH)
        height = Math.min(shapeW, shapeH)
      }

      if (!width) return

      const pad = 4
      const innerWidth = Math.max(24, width - pad * 2)
      const innerHeight = Math.max(24, (height || 64) - pad * 2)

      if (typeof dataLabel.css === "function") {
        dataLabel.css({
          width: `${innerWidth}px`,
          height: `${innerHeight}px`,
          whiteSpace: "normal",
          textAlign: "center"
        })
      }

      const root = dataLabel.div || dataLabel.element
      if (!root) return

      if (root.style) {
        root.style.width = `${innerWidth}px`
        root.style.maxWidth = `${innerWidth}px`
        root.style.height = `${innerHeight}px`
        root.style.whiteSpace = "normal"
        root.style.textAlign = "center"
        root.style.overflow = "hidden"
      }

      root.querySelectorAll?.("span, div").forEach((el) => {
        el.style.whiteSpace = "normal"
        el.style.width = "100%"
        el.style.maxWidth = "100%"
        el.style.boxSizing = "border-box"
      })

      const label = root.querySelector?.(".goals-network-org-node-label")
      if (label) {
        label.style.width = "100%"
        label.style.height = "100%"
      }
    })
  }

  reflowOrganizationChart() {
    if (!this.organizationChart) {
      this.initOrganizationChart()
      return
    }
    window.setTimeout(() => {
      this.organizationChart?.reflow()
      this.syncOrganizationLabelSizes(this.organizationChart)
    }, 50)
  }

  initCytoscape() {
    if (!this.hasCytoscapePaneTarget) return

    window.setTimeout(() => {
      const graphRoot = this.cytoscapePaneTarget.querySelector(
        "[data-controller~='assignment-accountability-flow']"
      )
      if (!graphRoot) return

      const cytoscapeController = this.application.getControllerForElementAndIdentifier(
        graphRoot,
        "assignment-accountability-flow"
      )
      cytoscapeController?.initGraph()
      cytoscapeController?.resize()
    }, 50)
  }

  waitForOrganizationModule(callback, attempts = 0) {
    const hc = window.Highcharts
    if (hc?.seriesTypes?.organization) {
      callback()
      return
    }
    if (attempts >= 100) return
    window.setTimeout(() => this.waitForOrganizationModule(callback, attempts + 1), 100)
  }
}
