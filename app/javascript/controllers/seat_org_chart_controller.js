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
    "treegraphPane",
    "treegraphContainer",
    "cytoscapePane"
  ]

  static values = {
    organizationDataJson: String,
    treegraphDataJson: String
  }

  connect() {
    this.organizationChart = null
    this.treegraphChart = null
  }

  disconnect() {
    this.organizationChart?.destroy()
    this.organizationChart = null
    this.treegraphChart?.destroy()
    this.treegraphChart = null
  }

  onTabShown(event) {
    const tab = event.target.closest?.('[data-bs-toggle="tab"]') || event.target
    const paneId = tab.getAttribute?.("data-bs-target")
    if (!paneId) return

    if (paneId.includes("-organization-pane")) {
      this.initOrganizationChart()
      this.reflowOrganizationChart()
    } else if (paneId.includes("-treegraph-pane")) {
      this.initTreegraphChart()
      this.reflowTreegraphChart()
    } else if (paneId.includes("-cytoscape-pane")) {
      this.initCytoscape()
    }
  }

  initOrganizationChart() {
    if (this.organizationChart || !this.hasOrganizationContainerTarget) return

    const hc = window.Highcharts
    if (!hc?.seriesTypes?.organization) {
      this.waitForHighchartsModule("organization", () => this.initOrganizationChart())
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
    const chartHeight = Math.max(360, Math.min(720, chartData.nodes.length * 48))

    this.organizationChart = hc.chart(container, {
      chart: {
        type: "organization",
        inverted: true,
        height: chartHeight
      },
      title: { text: null },
      accessibility: { enabled: false },
      series: [{
        type: "organization",
        name: "Seats",
        keys: ["from", "to"],
        data: (chartData.links || []).map((link) => [link.from, link.to]),
        nodes: chartData.nodes,
        colorByPoint: false,
        color: "#6c757d",
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
            const title = escapeHtml(this.point?.title || "")
            return `<div style="text-align:center;line-height:1.15;padding:2px;"><strong>${name}</strong>${title ? `<br/><span style="opacity:0.9;font-size:10px;font-weight:400;">${title}</span>` : ""}</div>`
          }
        },
        borderColor: "white",
        nodeWidth: 72,
        nodePadding: 12,
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
            const title = this.point.node.title ? `<br/>${this.point.node.title}` : ""
            return `<b>${this.point.node.name}</b>${title}`
          }
          return false
        }
      },
      exporting: { enabled: false }
    })
  }

  initTreegraphChart() {
    if (this.treegraphChart || !this.hasTreegraphContainerTarget) return

    const hc = window.Highcharts
    if (!hc?.seriesTypes?.treegraph) {
      this.waitForHighchartsModule("treegraph", () => this.initTreegraphChart())
      return
    }

    let chartData = { nodes: [] }
    try {
      chartData = JSON.parse(this.treegraphDataJsonValue || "{}")
    } catch {
      return
    }

    const nodes = chartData.nodes || []
    if (!nodes.length) return

    const data = nodes.map((node) => {
      const point = {
        id: node.id,
        // Highcharts treegraph roots use empty-string parent (see treegraph-boxes demo)
        parent: node.parent || "",
        name: node.name,
        url: node.url
      }
      if (node.color) point.color = node.color
      if (node.subtitle) point.subtitle = node.subtitle
      return point
    })

    const container = this.treegraphContainerTarget
    const chartHeight = Math.max(420, Math.min(900, nodes.length * 56))

    // Match Highcharts "treegraph-boxes" demo: rect markers + levels.
    // Do not pass layoutAlgorithm.type "box" — that option does not exist and breaks render.
    this.treegraphChart = hc.chart(container, {
      chart: {
        spacingBottom: 24,
        marginRight: 20,
        height: chartHeight
      },
      title: { text: null },
      accessibility: { enabled: false },
      series: [{
        type: "treegraph",
        data,
        marker: {
          symbol: "rect",
          width: "25%",
          height: 52,
          lineWidth: 2,
          lineColor: "#ffffff"
        },
        borderRadius: 8,
        link: {
          type: "curved",
          lineWidth: 2,
          color: "#adb5bd"
        },
        dataLabels: {
          enabled: true,
          useHTML: true,
          allowOverlap: true,
          style: {
            fontSize: "11px",
            fontWeight: "600",
            textOutline: "none",
            cursor: "pointer",
            whiteSpace: "normal",
            color: "#ffffff"
          },
          formatter() {
            const name = escapeHtml(this.point?.name || "")
            const subtitle = escapeHtml(this.point?.subtitle || "")
            return `<div style="text-align:center;line-height:1.15;padding:2px 4px;max-width:100%;"><strong>${name}</strong>${subtitle ? `<br/><span style="opacity:0.92;font-size:10px;font-weight:400;">${subtitle}</span>` : ""}</div>`
          }
        },
        levels: [
          {
            level: 1,
            levelIsConstant: false,
            colorByPoint: false,
            color: "#6c757d"
          },
          {
            level: 2,
            colorByPoint: true
          },
          {
            level: 3,
            colorVariation: { key: "brightness", to: -0.35 }
          }
        ],
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
        useHTML: true,
        formatter: function() {
          const subtitle = this.point?.subtitle ? `<br/>${escapeHtml(this.point.subtitle)}` : ""
          return `<b>${escapeHtml(this.point?.name || "")}</b>${subtitle}`
        }
      },
      exporting: { enabled: false }
    })
  }

  reflowOrganizationChart() {
    if (!this.organizationChart) {
      this.initOrganizationChart()
      return
    }
    window.setTimeout(() => this.organizationChart?.reflow(), 50)
  }

  reflowTreegraphChart() {
    if (!this.treegraphChart) {
      this.initTreegraphChart()
      return
    }
    window.setTimeout(() => this.treegraphChart?.reflow(), 50)
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

  waitForHighchartsModule(seriesType, callback, attempts = 0) {
    const hc = window.Highcharts
    if (hc?.seriesTypes?.[seriesType]) {
      callback()
      return
    }
    if (attempts >= 100) return
    window.setTimeout(() => this.waitForHighchartsModule(seriesType, callback, attempts + 1), 100)
  }
}
