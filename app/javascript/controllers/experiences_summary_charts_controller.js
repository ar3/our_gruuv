import { Controller } from "@hotwired/stimulus"

// Renders Highcharts pies for MyGrowth::ExperiencesSummary payloads.
// Re-inits on Stimulus connect so Turbo Frame refreshes re-draw charts.
export default class extends Controller {
  static values = {
    energy: { type: Array, default: [] },
    rating: { type: Array, default: [] },
    inflightEnergy: { type: Array, default: [] },
    inflightRating: { type: Array, default: [] },
    energyChartId: String,
    ratingChartId: String,
    inflightEnergyChartId: String,
    inflightRatingChartId: String,
    showInflight: { type: Boolean, default: false }
  }

  connect() {
    this.charts = []
    this.renderCharts()
  }

  disconnect() {
    this.destroyCharts()
  }

  renderCharts() {
    const hc = window.Highcharts
    if (typeof hc === "undefined") return

    this.destroyCharts()

    this.renderAssignmentPie(this.energyChartIdValue, this.energyValue)
    this.renderRatingPie(this.ratingChartIdValue, this.ratingValue)

    if (this.showInflightValue) {
      this.renderAssignmentPie(this.inflightEnergyChartIdValue, this.inflightEnergyValue)
      this.renderRatingPie(this.inflightRatingChartIdValue, this.inflightRatingValue)
    }
  }

  renderAssignmentPie(chartId, data) {
    if (!chartId) return

    const el = document.getElementById(chartId)
    if (!el) return
    if (!data || data.length === 0) return

    const hc = window.Highcharts
    this.charts.push(
      hc.chart(chartId, {
        chart: { type: "pie" },
        title: { text: null },
        accessibility: { enabled: false },
        plotOptions: {
          pie: {
            allowPointSelect: true,
            cursor: "pointer",
            dataLabels: {
              enabled: true,
              format: "<b>{point.name}</b>: {point.y}% ({point.percentage:.1f}%)"
            }
          }
        },
        series: [{
          name: "Energy",
          colorByPoint: true,
          data: data
        }]
      })
    )
  }

  renderRatingPie(chartId, data) {
    if (!chartId) return

    const el = document.getElementById(chartId)
    if (!el) return

    if (!data || data.length === 0) {
      el.innerHTML = '<p class="text-muted mb-0">No rating data to chart.</p>'
      return
    }

    this.charts.push(window.Highcharts.chart(chartId, this.ratingPieOptions(data)))
  }

  ratingPieOptions(data) {
    return {
      chart: { type: "pie" },
      title: { text: null },
      accessibility: { enabled: false },
      plotOptions: {
        pie: {
          allowPointSelect: true,
          cursor: "pointer",
          dataLabels: {
            enabled: true,
            format: "<b>{point.name}</b>: {point.y}% ({point.percentage:.1f}%)"
          }
        }
      },
      series: [{
        name: "Energy",
        colorByPoint: false,
        data: data
      }]
    }
  }

  destroyCharts() {
    ;(this.charts || []).forEach((chart) => {
      try {
        chart.destroy()
      } catch (_e) {
        // Chart may already be gone after Turbo replaces the frame.
      }
    })
    this.charts = []
  }
}
