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
  static values = {
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
      window.setTimeout(() => this.renderChart(), 100)
      return
    }

    let payload = {}
    try {
      payload = JSON.parse(this.dataJsonValue || "{}")
    } catch {
      return
    }

    const points = payload.points || []
    const tails = payload.tails || []
    const floor = payload.floor
    const average = payload.average

    this.chart?.destroy()
    this.chart = null

    const plotLines = []
    if (floor != null) {
      plotLines.push({
        value: floor,
        color: "#dc3545",
        width: 1,
        zIndex: 4,
        label: { text: "Floor", style: { color: "#dc3545", fontSize: "10px" } }
      })
    }
    if (average != null) {
      plotLines.push({
        value: average,
        color: "#6c757d",
        width: 1,
        dashStyle: "Dash",
        zIndex: 4,
        label: { text: "Avg", style: { color: "#6c757d", fontSize: "10px" } }
      })
    }

    const series = tails.map((tail) => ({
      type: "line",
      data: [
        [tail.from, tail.lane],
        [tail.to, tail.lane]
      ],
      color: tail.color,
      lineWidth: 2,
      enableMouseTracking: false,
      marker: { enabled: false },
      showInLegend: false
    }))

    series.push({
      type: "scatter",
      name: "Checks",
      data: points.map((point) => ({
        x: point.confidence,
        y: point.lane,
        name: point.title,
        goalId: point.goal_id,
        color: point.color,
        marker: {
          radius: 5,
          symbol: "circle",
          fillColor: point.color,
          lineWidth: 0
        }
      })),
      showInLegend: false,
      cursor: "pointer",
      tooltip: {
        pointFormatter() {
          return `<b>${escapeHtml(this.name)}</b><br/>${this.x}%`
        }
      },
      point: {
        events: {
          click() {
            const target = document.getElementById(`confidence-goal-${this.goalId}`)
            if (!target) return
            target.scrollIntoView({ behavior: "smooth", block: "center" })
            const details = target.closest("details")
            if (details) details.open = true
          }
        }
      }
    })

    this.chart = hc.chart(this.element, {
      chart: {
        type: "scatter",
        height: 120,
        spacing: [8, 8, 8, 8],
        backgroundColor: "transparent"
      },
      title: { text: null },
      credits: { enabled: false },
      accessibility: { enabled: false },
      legend: { enabled: false },
      xAxis: {
        min: 0,
        max: 100,
        title: { text: null },
        tickInterval: 25,
        gridLineWidth: 0,
        plotLines
      },
      yAxis: {
        min: -0.5,
        max: 3.5,
        visible: false,
        title: { text: null }
      },
      series
    })
  }
}
