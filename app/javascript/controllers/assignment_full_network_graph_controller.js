import { Controller } from "@hotwired/stimulus"
import { DataSet } from "vis-data"
import { Network } from "vis-network"

export default class extends Controller {
  static targets = [
    "highchartsSankeyPane",
    "highchartsSankeyContainer",
    "highchartsNetworkPane",
    "highchartsNetworkContainer",
    "cytoscapePane",
    "visPane",
    "visContainer",
    "mermaidPane",
    "mermaidContainer"
  ]

  static values = {
    highchartsNetworkDataJson: String,
    highchartsSankeyDataJson: String,
    visNetworkDataJson: String
  }

  connect() {
    this.highchartsSankeyChart = null
    this.highchartsNetworkChart = null
    this.visNetwork = null
    this.networkgraphScriptLoading = false

    window.setTimeout(() => this.initMermaid(), 50)
  }

  disconnect() {
    this.destroyHighchartsCharts()
    this.visNetwork?.destroy()
    this.visNetwork = null
  }

  onTabShown(event) {
    const tab = event.target.closest?.('[data-bs-toggle="tab"]') || event.target
    const paneId = tab.getAttribute?.("data-bs-target")
    if (!paneId) return

    if (paneId === "#full-network-mermaid-pane") {
      this.initMermaid()
    } else if (paneId === "#full-network-cytoscape-pane") {
      this.initCytoscape()
    } else if (paneId === "#full-network-highcharts-sankey-pane") {
      this.initSankey()
    } else if (paneId === "#full-network-highcharts-network-pane") {
      this.ensureNetworkgraphModule(() => this.initNetworkGraph())
    } else if (paneId === "#full-network-vis-pane") {
      this.initVisNetwork()
    }
  }

  destroyHighchartsCharts() {
    this.highchartsSankeyChart?.destroy()
    this.highchartsSankeyChart = null
    this.highchartsNetworkChart?.destroy()
    this.highchartsNetworkChart = null
  }

  initMermaid() {
    if (!this.hasMermaidContainerTarget) return

    window.setTimeout(() => {
      const mermaidController = this.application.getControllerForElementAndIdentifier(
        this.mermaidContainerTarget,
        "assignment-flow-mermaid"
      )
      mermaidController?.render()
    }, 50)
  }

  initSankey() {
    if (this.highchartsSankeyChart || !this.hasHighchartsSankeyContainerTarget) return

    const hc = window.Highcharts
    if (!hc?.seriesTypes?.sankey) return

    let chartData = { nodes: [], data: [] }
    try {
      chartData = JSON.parse(this.highchartsSankeyDataJsonValue || "{}")
    } catch {
      return
    }

    if (!chartData.nodes?.length) return

    const container = this.highchartsSankeyContainerTarget
    const chartHeight = Math.max(560, container.clientHeight || 0)

    this.highchartsSankeyChart = hc.chart(container, {
      chart: { height: chartHeight },
      title: { text: null },
      plotOptions: {
        sankey: {
          nodeWidth: 24,
          nodePadding: 12,
          linkOpacity: 0.5,
          dataLabels: {
            enabled: true,
            style: { fontSize: "11px", fontWeight: "normal", textOutline: "none" }
          },
          point: {
            events: {
              click: function () {
                const url = this.options?.url
                if (url) window.location.assign(url)
              }
            }
          }
        }
      },
      tooltip: {
        pointFormat: "{point.fromNode.name} → {point.toNode.name}"
      },
      series: [
        {
          type: "sankey",
          keys: ["from", "to", "weight"],
          data: chartData.data,
          nodes: chartData.nodes
        }
      ],
      credits: { enabled: false }
    })
  }

  ensureNetworkgraphModule(callback, attempts = 0) {
    const hc = window.Highcharts

    if (hc?.seriesTypes?.networkgraph) {
      callback()
      return
    }

    if (!hc) {
      if (attempts < 100) {
        setTimeout(() => this.ensureNetworkgraphModule(callback, attempts + 1), 100)
      }
      return
    }

    if (!this.networkgraphScriptLoading) {
      this.networkgraphScriptLoading = true
      const script = document.createElement("script")
      script.src = "https://code.highcharts.com/modules/networkgraph.js"
      script.async = false
      script.onload = () => callback()
      script.onerror = () => {
        this.networkgraphScriptLoading = false
      }
      document.head.appendChild(script)
      return
    }

    if (attempts < 100) {
      setTimeout(() => this.ensureNetworkgraphModule(callback, attempts + 1), 100)
    }
  }

  initNetworkGraph() {
    if (this.highchartsNetworkChart || !this.hasHighchartsNetworkContainerTarget) return

    const hc = window.Highcharts
    if (!hc?.seriesTypes?.networkgraph) {
      this.ensureNetworkgraphModule(() => this.initNetworkGraph())
      return
    }

    let chartData = { nodes: [], links: [] }
    try {
      chartData = JSON.parse(this.highchartsNetworkDataJsonValue || "{}")
    } catch {
      return
    }

    if (!chartData.nodes?.length) return

    const container = this.highchartsNetworkContainerTarget
    const chartHeight = Math.max(560, container.clientHeight || 0)

    this.highchartsNetworkChart = hc.chart(container, {
      chart: { type: "networkgraph", height: chartHeight },
      title: { text: null },
      plotOptions: {
        networkgraph: {
          keys: ["from", "to"],
          layoutAlgorithm: {
            enableSimulation: true,
            maxIterations: 800,
            friction: -0.75,
            linkLength: 140,
            integration: "verlet"
          },
          dataLabels: {
            enabled: true,
            linkFormat: "",
            style: { fontSize: "11px", fontWeight: "normal" }
          },
          link: {
            color: "#6c757d",
            width: 2
          },
          node: {
            color: "#f8f9fa",
            borderColor: "#adb5bd",
            borderWidth: 1
          },
          point: {
            events: {
              click: function () {
                const url = this.options?.url || this.options?.custom?.url
                if (url) window.location.assign(url)
              }
            }
          }
        }
      },
      tooltip: {
        formatter: function () {
          return this.point.name || this.point.id
        }
      },
      series: [
        {
          type: "networkgraph",
          data: chartData.links,
          nodes: chartData.nodes
        }
      ],
      credits: { enabled: false }
    })
  }

  initCytoscape() {
    if (!this.hasCytoscapePaneTarget) return

    const graphEl = this.cytoscapePaneTarget.querySelector(
      "[data-controller~='assignment-accountability-flow']"
    )
    if (!graphEl) return

    const cytoscapeController = this.application.getControllerForElementAndIdentifier(
      graphEl,
      "assignment-accountability-flow"
    )
    cytoscapeController?.initGraph()
    cytoscapeController?.resize()
  }

  initVisNetwork() {
    if (this.visNetwork || !this.hasVisContainerTarget) return

    let graphData = { nodes: [], edges: [] }
    try {
      graphData = JSON.parse(this.visNetworkDataJsonValue || "{}")
    } catch {
      return
    }

    if (!graphData.nodes?.length) return

    const nodes = new DataSet(
      graphData.nodes.map((node) => ({
        id: node.id,
        label: node.label,
        shape: "box",
        color: {
          background: "#f8f9fa",
          border: "#adb5bd",
          highlight: { background: "#cfe2ff", border: "#0d6efd" }
        },
        font: { color: "#212529", size: 12 },
        margin: 10
      }))
    )

    const edges = new DataSet(
      graphData.edges.map((edge) => ({
        id: edge.id,
        from: edge.from,
        to: edge.to,
        arrows: edge.arrows || "to",
        color: { color: "#6c757d", highlight: "#495057" },
        width: 2
      }))
    )

    this.visNetwork = new Network(
      this.visContainerTarget,
      { nodes, edges },
      {
        layout: {
          hierarchical: {
            enabled: true,
            direction: "LR",
            sortMethod: "directed",
            levelSeparation: 180,
            nodeSpacing: 140
          }
        },
        physics: { enabled: false },
        interaction: { hover: true, navigationButtons: true, keyboard: true }
      }
    )

    this.visNetwork.on("click", (params) => {
      if (params.nodes.length !== 1) return
      const node = graphData.nodes.find((n) => n.id === params.nodes[0])
      if (node?.url) window.location.assign(node.url)
    })
  }
}
