import { Controller } from "@hotwired/stimulus"

// Carousel over locked Confidential Talent Reflections + optional 24-month stance chart.
// History slides are newest-first: index 0 = most recent prior. Older = higher index.
export default class extends Controller {
  static targets = ["slide", "chart", "olderButton", "newerButton", "positionLabel"]
  static values = {
    index: { type: Number, default: 0 },
    chartPoints: { type: Array, default: [] }
  }

  connect() {
    this.chart = null
    this.showSlide(this.indexValue)
    this.renderChart()
  }

  disconnect() {
    this.destroyChart()
  }

  older(event) {
    event?.preventDefault()
    if (this.indexValue >= this.slideTargets.length - 1) return
    this.indexValue = this.indexValue + 1
    this.showSlide(this.indexValue)
  }

  newer(event) {
    event?.preventDefault()
    if (this.indexValue <= 0) return
    this.indexValue = this.indexValue - 1
    this.showSlide(this.indexValue)
  }

  selectPeriod(event) {
    const period = event.params?.period || event.currentTarget?.dataset?.period
    if (!period) return
    const idx = this.slideTargets.findIndex((el) => el.dataset.period === period)
    if (idx < 0) return
    this.indexValue = idx
    this.showSlide(this.indexValue)
  }

  showSlide(index) {
    this.slideTargets.forEach((el, i) => {
      el.classList.toggle("d-none", i !== index)
    })
    if (this.hasOlderButtonTarget) {
      this.olderButtonTarget.disabled = index >= this.slideTargets.length - 1
    }
    if (this.hasNewerButtonTarget) {
      this.newerButtonTarget.disabled = index <= 0
    }
    if (this.hasPositionLabelTarget) {
      const total = this.slideTargets.length
      this.positionLabelTarget.textContent = total > 0 ? `${index + 1} of ${total}` : ""
    }
    this.highlightChartPoint()
  }

  renderChart() {
    if (!this.hasChartTarget) return
    const points = this.chartPointsValue || []
    if (points.length < 3) {
      this.chartTarget.classList.add("d-none")
      return
    }

    const hc = window.Highcharts
    if (typeof hc === "undefined") return

    this.destroyChart()
    this.chartTarget.classList.remove("d-none")

    const categories = points.map((p) => p.label)
    const data = points.map((p, i) => ({
      y: p.y,
      period: p.period,
      locked: p.locked,
      current: p.current,
      stanceLabel: p.stanceLabel,
      color: this.toneColor(p.tone),
      x: i
    }))

    this.chart = hc.chart(this.chartTarget, {
      chart: { type: "line", height: 180, backgroundColor: "transparent" },
      title: { text: null },
      credits: { enabled: false },
      legend: { enabled: false },
      accessibility: { enabled: false },
      xAxis: {
        categories,
        title: { text: null },
        labels: { rotation: -45, style: { fontSize: "10px" } }
      },
      yAxis: {
        min: 0,
        max: 2,
        tickInterval: 1,
        title: { text: null },
        labels: {
          formatter() {
            return ["Take swap", "Do nothing", "Avoid swap"][this.value] || ""
          }
        }
      },
      tooltip: {
        formatter() {
          const p = this.point
          return `<b>${p.category}</b><br/>${p.stanceLabel || ""}`
        }
      },
      plotOptions: {
        series: {
          step: "left",
          cursor: "pointer",
          marker: { enabled: true, radius: 5 },
          point: {
            events: {
              click: (e) => {
                const period = e.point?.options?.period
                if (!period) return
                if (e.point.options.current) return
                this.selectPeriod({ params: { period } })
              }
            }
          }
        }
      },
      series: [{
        name: "Stance",
        data,
        color: "#6c757d"
      }]
    })
  }

  highlightChartPoint() {
    if (!this.chart) return
    const active = this.slideTargets[this.indexValue]
    const period = active?.dataset?.period
    const series = this.chart.series?.[0]
    if (!series) return
    series.points.forEach((point) => {
      const match = point.options?.period === period
      point.setState(match ? "hover" : "")
      if (match) point.select(true, false)
      else point.select(false, false)
    })
  }

  toneColor(tone) {
    switch (tone) {
      case "warning": return "#ffc107"
      case "info": return "#0dcaf0"
      case "success": return "#198754"
      default: return "#6c757d"
    }
  }

  destroyChart() {
    if (!this.chart) return
    try {
      this.chart.destroy()
    } catch (_e) {
      // already gone
    }
    this.chart = null
  }
}
