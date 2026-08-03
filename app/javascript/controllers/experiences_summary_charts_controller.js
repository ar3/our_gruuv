import { Controller } from "@hotwired/stimulus"

// Renders Highcharts pies for MyGrowth::ExperiencesSummary payloads.
// Re-inits on Stimulus connect so Turbo Frame refreshes re-draw charts.
export default class extends Controller {
  static values = {
    energy: { type: Array, default: [] },
    rating: { type: Array, default: [] },
    inflightRating: { type: Array, default: [] },
    energyChartId: String,
    ratingChartId: String,
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

    const energyEl = document.getElementById(this.energyChartIdValue)
    if (energyEl && this.energyValue.length > 0) {
      this.charts.push(
        hc.chart(this.energyChartIdValue, {
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
            data: this.energyValue
          }]
        })
      )
    }

    const ratingEl = document.getElementById(this.ratingChartIdValue)
    if (ratingEl && this.ratingValue.length > 0) {
      this.charts.push(hc.chart(this.ratingChartIdValue, this.pieChartOptions(this.ratingValue)))
    } else if (ratingEl) {
      ratingEl.innerHTML = '<p class="text-muted mb-0">No rating data to chart.</p>'
    }

    if (this.showInflightValue && this.hasInflightRatingChartIdValue) {
      const inflightEl = document.getElementById(this.inflightRatingChartIdValue)
      if (inflightEl && this.inflightRatingValue.length > 0) {
        this.charts.push(
          hc.chart(this.inflightRatingChartIdValue, this.pieChartOptions(this.inflightRatingValue))
        )
      }
    }
  }

  pieChartOptions(data) {
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
