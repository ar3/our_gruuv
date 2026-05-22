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
    "g6Pane",
    "g6Container",
    "visPane",
    "visContainer",
    "mermaidPane",
    "mermaidContainer"
  ]

  static values = {
    highchartsNetworkDataJson: String,
    highchartsSankeyDataJson: String,
    g6GraphDataJson: String,
    visNetworkDataJson: String
  }

  connect() {
    this.highchartsSankeyChart = null
    this.highchartsNetworkChart = null
    this.g6Graph = null
    this.visNetwork = null
    this.networkgraphScriptLoading = false

    window.setTimeout(() => this.initMermaid(), 50)
  }

  disconnect() {
    this.destroyHighchartsCharts()
    this.g6Graph?.destroy()
    this.g6Graph = null
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
    } else if (paneId === "#full-network-g6-pane") {
      this.initG6()
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

        container.innerHTML = ""

        this.g6Graph = new Graph({
          container,
          width,
          height: 560,
          data: graphData,
          layout: {
            type: "dagre",
            rankdir: "LR",
            nodesep: 48,
            ranksep: 72
          },
          node: {
            type: "rect",
            style: {
              size: [140, 44],
              labelText: (datum) => datum.data?.label ?? datum.id,
              labelFontSize: 11,
              labelFill: "#212529",
              fill: "#f8f9fa",
              stroke: "#adb5bd",
              lineWidth: 1,
              radius: 4,
              cursor: "pointer"
            }
          },
          edge: {
            type: "line",
            style: {
              stroke: "#6c757d",
              lineWidth: 2,
              endArrow: true
            }
          },
          behaviors: ["drag-canvas", "zoom-canvas"],
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
        console.error("[G6] Failed to render assignment network graph", error)
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
