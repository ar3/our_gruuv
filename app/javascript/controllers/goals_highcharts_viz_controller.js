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
  static targets = ["container"]

  static values = {
    chartKind: String,
    dataJson: String
  }

  connect() {
    this.chart = null
    this.renderChart()
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }

  renderChart() {
    const hc = window.Highcharts
    if (!hc) {
      this.waitForHighcharts(() => this.renderChart())
      return
    }

    let payload = {}
    try {
      payload = JSON.parse(this.dataJsonValue || "{}")
    } catch {
      return
    }

    const seriesType = payload.series_type
    if (!seriesType) return

    if (!hc.seriesTypes?.[seriesType]) {
      this.waitForSeriesType(seriesType, () => this.renderChart())
      return
    }

    this.chart?.destroy()
    this.chart = null

    const container = this.containerTarget
    const kind = this.chartKindValue || payload.chart_kind

    if (seriesType === "networkgraph") {
      this.chart = this.buildNetworkgraph(hc, container, payload)
    } else if (seriesType === "treegraph") {
      this.chart = this.buildTreegraph(hc, container, payload, kind === "hc-treegraph-boxes")
    } else if (seriesType === "sankey") {
      this.chart = this.buildSankey(hc, container, payload)
    } else if (seriesType === "organization") {
      this.chart = this.buildOrganization(hc, container, payload)
    }
  }

  buildNetworkgraph(hc, container, payload) {
    const nodes = payload.nodes || []
    const height = Math.max(420, Math.min(900, nodes.length * 28))
    return hc.chart(container, {
      chart: { type: "networkgraph", height },
      title: { text: null },
      accessibility: { enabled: false },
      plotOptions: {
        networkgraph: {
          keys: ["from", "to"],
          layoutAlgorithm: { enableSimulation: true, friction: -0.9 },
          link: { color: "#adb5bd" }
        }
      },
      series: [{
        type: "networkgraph",
        data: (payload.links || []).map((l) => [l.from, l.to]),
        nodes,
        dataLabels: {
          enabled: true,
          linkFormat: "",
          style: { fontSize: "10px", textOutline: "none" },
          formatter() {
            const soft = this.point?.softLabel ? ` (${escapeHtml(this.point.softLabel)})` : ""
            return `${escapeHtml(this.point?.name || "")}${soft}`
          }
        },
        cursor: "pointer",
        point: {
          events: {
            click() {
              const url = this.url || this.options?.url
              if (url) window.location.assign(url)
            }
          }
        }
      }],
      tooltip: {
        formatter() {
          const soft = this.point?.softLabel ? `<br/>${escapeHtml(this.point.softLabel)}` : ""
          return `<b>${escapeHtml(this.point?.name || "")}</b>${soft}`
        }
      },
      exporting: { enabled: false },
      credits: { enabled: false }
    })
  }

  buildTreegraph(hc, container, payload, boxes) {
    const nodes = payload.nodes || []
    const height = Math.max(420, Math.min(1000, nodes.length * 52))
    const data = nodes.map((node) => {
      const point = {
        id: node.id,
        parent: node.parent || "",
        name: node.name,
        url: node.url,
        subtitle: node.subtitle,
        duplicated: node.duplicated
      }
      if (node.color) point.color = node.color
      return point
    })

    const series = {
      type: "treegraph",
      data,
      link: { type: "curved", lineWidth: 2, color: "#adb5bd" },
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
          color: boxes ? "#ffffff" : "#212529"
        },
        formatter() {
          const name = escapeHtml(this.point?.name || "")
          const subtitle = escapeHtml(this.point?.subtitle || "")
          return `<div style="text-align:center;line-height:1.15;padding:2px 4px;"><strong>${name}</strong>${subtitle ? `<br/><span style="opacity:0.9;font-size:10px;font-weight:400;">${subtitle}</span>` : ""}</div>`
        }
      },
      cursor: "pointer",
      point: {
        events: {
          click() {
            const url = this.url || this.options?.url
            if (url) window.location.assign(url)
          }
        }
      }
    }

    if (boxes) {
      series.marker = {
        symbol: "rect",
        width: "25%",
        height: 52,
        lineWidth: 2,
        lineColor: "#ffffff"
      }
      series.borderRadius = 8
    }

    return hc.chart(container, {
      chart: { height, marginRight: 20, spacingBottom: 24 },
      title: { text: null },
      accessibility: { enabled: false },
      series: [series],
      tooltip: {
        useHTML: true,
        formatter() {
          const subtitle = this.point?.subtitle ? `<br/>${escapeHtml(this.point.subtitle)}` : ""
          return `<b>${escapeHtml(this.point?.name || "")}</b>${subtitle}`
        }
      },
      exporting: { enabled: false },
      credits: { enabled: false }
    })
  }

  buildSankey(hc, container, payload) {
    const nodes = payload.nodes || []
    const height = Math.max(420, Math.min(900, Math.max(nodes.length, 6) * 36))
    return hc.chart(container, {
      chart: {
        type: "sankey",
        inverted: !!payload.inverted,
        height
      },
      title: { text: null },
      accessibility: { enabled: false },
      series: [{
        type: "sankey",
        keys: ["from", "to", "weight"],
        data: payload.data || [],
        nodes,
        dataLabels: { style: { fontSize: "11px", textOutline: "none" } },
        cursor: "pointer",
        point: {
          events: {
            click() {
              const url = this.url || this.options?.url || this.node?.url
              if (url) window.location.assign(url)
            }
          }
        }
      }],
      tooltip: {
        formatter() {
          if (this.point?.isNode) {
            const soft = this.point.softLabel ? `<br/>${escapeHtml(this.point.softLabel)}` : ""
            return `<b>${escapeHtml(this.point.name || "")}</b>${soft}`
          }
          return `${escapeHtml(this.point?.from || "")} → ${escapeHtml(this.point?.to || "")}`
        }
      },
      exporting: { enabled: false },
      credits: { enabled: false }
    })
  }

  buildOrganization(hc, container, payload) {
    const nodes = payload.nodes || []
    const height = Math.max(360, Math.min(900, nodes.length * 48))
    return hc.chart(container, {
      chart: {
        type: "organization",
        inverted: !!payload.inverted,
        height
      },
      title: { text: null },
      accessibility: { enabled: false },
      series: [{
        type: "organization",
        keys: ["from", "to"],
        data: (payload.links || []).map((l) => [l.from, l.to]),
        nodes,
        colorByPoint: false,
        color: "#6c757d",
        dataLabels: {
          color: "white",
          useHTML: true,
          allowOverlap: true,
          style: {
            fontSize: "11px",
            fontWeight: "600",
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
        nodeWidth: 80,
        nodePadding: 12,
        cursor: "pointer",
        point: {
          events: {
            click() {
              const url = this.url || this.options?.url
              if (url) window.location.assign(url)
            }
          }
        }
      }],
      tooltip: {
        outside: true,
        formatter() {
          if (this.point?.node) {
            const title = this.point.node.title ? `<br/>${escapeHtml(this.point.node.title)}` : ""
            return `<b>${escapeHtml(this.point.node.name)}</b>${title}`
          }
          return false
        }
      },
      exporting: { enabled: false },
      credits: { enabled: false }
    })
  }

  waitForHighcharts(callback, attempts = 0) {
    if (window.Highcharts) {
      callback()
      return
    }
    if (attempts >= 100) return
    window.setTimeout(() => this.waitForHighcharts(callback, attempts + 1), 100)
  }

  waitForSeriesType(seriesType, callback, attempts = 0) {
    const hc = window.Highcharts
    if (hc?.seriesTypes?.[seriesType]) {
      callback()
      return
    }
    if (attempts >= 100) return
    window.setTimeout(() => this.waitForSeriesType(seriesType, callback, attempts + 1), 100)
  }
}
