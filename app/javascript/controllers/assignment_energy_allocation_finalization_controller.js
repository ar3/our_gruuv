import { Controller } from "@hotwired/stimulus"

const ALERT_SUCCESS = "success"
const ALERT_WARNING = "warning"
const ALERT_DANGER = "danger"

// Finalization: left bar static; right bar mirrors anticipated_energy_percentage selects.
export default class extends Controller {
  static targets = ["panel", "updatedTotal", "updatedBar"]

  static values = {
    colors: Object,
    currentForecast: Object,
    employeeActual: Object,
    updatedForecast: Object,
    assignments: Object,
    employeeName: String
  }

  connect() {
    this.boundRefresh = this.refreshUpdatedFromDom.bind(this)
    this.element.addEventListener("change", this.boundRefresh)
    this.element.addEventListener("input", this.boundRefresh)
    this.refreshUpdatedFromDom()
    this.initializeSegmentPopovers(this.element)
  }

  disconnect() {
    this.element.removeEventListener("change", this.boundRefresh)
    this.element.removeEventListener("input", this.boundRefresh)
    this.disposeSegmentPopovers(this.element)
  }

  refreshUpdatedFromDom() {
    const segments = this.collectUpdatedSegments()
    const total = segments.reduce((sum, s) => sum + s.value, 0)
    const layout = this.computeBarLayout(segments, total)

    this.updateUpdatedTotal(total, layout.over_hundred)
    this.updatePanelAlert(total)
    this.renderUpdatedBar(segments, layout)
    this.initializeSegmentPopovers(this.updatedBarTarget)
  }

  collectUpdatedSegments() {
    const tableAssignmentIds = Array.from(
      this.element.querySelectorAll("tr[data-assignment-id]")
    ).map((row) => row.dataset.assignmentId)

    const assignmentIds = new Set([
      ...Object.keys(this.colorsValue || {}),
      ...Object.keys(this.updatedForecastValue || {}),
      ...tableAssignmentIds
    ])

    const segments = []

    assignmentIds.forEach((assignmentId) => {
      const value = this.readUpdatedForecastForAssignment(assignmentId)
      if (value == null || value <= 0) return

      segments.push({
        assignment_id: assignmentId,
        name: this.assignmentName(assignmentId) || `Assignment ${assignmentId}`,
        value,
        display_weight: value,
        color: this.colorForAssignment(assignmentId)
      })
    })

    return segments.sort((a, b) => a.name.localeCompare(b.name))
  }

  readUpdatedForecastForAssignment(assignmentId) {
    const row = this.element.querySelector(`tr[data-assignment-id="${assignmentId}"]`)
    if (row) return this.readUpdatedForecastFromRow(row)

    const key = String(assignmentId)
    const raw = this.updatedForecastValue[assignmentId] ?? this.updatedForecastValue[key]
    if (raw == null || raw === "") return null

    const parsed = parseInt(raw, 10)
    return Number.isNaN(parsed) ? null : parsed
  }

  readUpdatedForecastFromRow(row) {
    const select =
      row.querySelector(
        'select[name*="assignment_check_ins"][name*="anticipated_energy_percentage"]'
      ) || row.querySelector('select[name^="assignment_tenures["]')
    if (select && select.value !== "") {
      const parsed = parseInt(select.value, 10)
      return Number.isNaN(parsed) ? null : parsed
    }

    const fallback = row.dataset.initialUpdatedForecast
    if (fallback !== undefined && fallback !== "") {
      const parsed = parseInt(fallback, 10)
      return Number.isNaN(parsed) ? null : parsed
    }

    return null
  }

  computeBarLayout(segments, total) {
    if (!segments.length) {
      return { segments: [], unallocated_percent: 100, over_hundred: false }
    }

    const numericTotal = Number(total) || 0
    if (numericTotal > 100) {
      let weightSum = segments.reduce((sum, s) => sum + s.value, 0) || 1

      return {
        over_hundred: true,
        unallocated_percent: 0,
        segments: segments.map((segment) => ({
          ...segment,
          flex_percent: (segment.value / weightSum) * 100
        }))
      }
    }

    const weightSum = segments.reduce((sum, s) => sum + s.display_weight, 0) || 1
    const coloredWidth = Math.min(Math.max(numericTotal, 0), 100)
    const unallocated_percent = 100 - coloredWidth

    return {
      over_hundred: false,
      unallocated_percent,
      segments: segments.map((segment) => ({
        ...segment,
        flex_percent: (segment.display_weight / weightSum) * coloredWidth
      }))
    }
  }

  updateUpdatedTotal(total, overHundred) {
    if (!this.hasUpdatedTotalTarget) return
    this.updatedTotalTarget.textContent = overHundred ? `${total}% (over 100%)` : `${total}%`
  }

  updatePanelAlert(total) {
    if (!this.hasPanelTarget) return

    this.panelTarget.classList.remove(
      "assignment-energy-allocation-panel--success",
      "assignment-energy-allocation-panel--warning",
      "assignment-energy-allocation-panel--danger"
    )

    if (total <= 0) return

    const band = this.alertBandFor(total)
    if (band === ALERT_SUCCESS) {
      this.panelTarget.classList.add("assignment-energy-allocation-panel--success")
    } else if (band === ALERT_WARNING) {
      this.panelTarget.classList.add("assignment-energy-allocation-panel--warning")
    } else {
      this.panelTarget.classList.add("assignment-energy-allocation-panel--danger")
    }
  }

  alertBandFor(total) {
    if (total === 100) return ALERT_SUCCESS
    if (total >= 90 && total <= 110 && total !== 100) return ALERT_WARNING
    return ALERT_DANGER
  }

  renderUpdatedBar(segments, layout) {
    if (!this.hasUpdatedBarTarget) return

    if (!segments.length) {
      this.updatedBarTarget.innerHTML =
        '<div class="assignment-energy-allocation-bar__empty small text-muted py-1">No forecasted energy to display yet.</div>'
      return
    }

    const trackClass = layout.over_hundred
      ? "assignment-energy-allocation-bar__track assignment-energy-allocation-bar__track--over"
      : "assignment-energy-allocation-bar__track"

    let segmentsHtml = layout.segments.map((segment) => this.segmentMarkup(segment)).join("")

    if (layout.unallocated_percent > 0) {
      segmentsHtml += `
        <div class="assignment-energy-allocation-bar__segment assignment-energy-allocation-bar__segment--unallocated"
             style="flex: 0 0 ${layout.unallocated_percent}%;"
             title="Unallocated"></div>
      `
    }

    this.updatedBarTarget.innerHTML = `
      <div class="assignment-energy-allocation-bar__track-wrap">
        <div class="${trackClass}">${segmentsHtml}</div>
      </div>
    `
  }

  segmentMarkup(segment) {
    const name = this.escapeHtml(segment.name)
    const id = this.escapeHtml(segment.assignment_id)
    return `
      <div class="assignment-energy-allocation-bar__segment"
           style="flex: 0 0 ${segment.flex_percent}%; background-color: ${segment.color};"
           tabindex="0"
           data-assignment-id="${id}"
           data-assignment-name="${name}"></div>
    `
  }

  initializeSegmentPopovers(container) {
    if (!container) return

    const Popover = this.bootstrapPopoverClass()
    if (!Popover) return

    container
      .querySelectorAll(
        ".assignment-energy-allocation-bar__segment[data-assignment-id]:not(.assignment-energy-allocation-bar__segment--unallocated)"
      )
      .forEach((element) => {
        const existing = Popover.getInstance(element)
        if (existing) existing.dispose()

        const controller = this
        new Popover(element, {
          trigger: "hover focus",
          placement: "top",
          html: true,
          sanitize: false,
          content: () => controller.segmentPopoverContent(element)
        })
      })
  }

  disposeSegmentPopovers(container) {
    if (!container) return

    const Popover = this.bootstrapPopoverClass()
    if (!Popover) return

    container
      .querySelectorAll(
        ".assignment-energy-allocation-bar__segment[data-assignment-id]:not(.assignment-energy-allocation-bar__segment--unallocated)"
      )
      .forEach((element) => {
        const instance = Popover.getInstance(element)
        if (instance) instance.dispose()
      })
  }

  segmentPopoverContent(element) {
    const assignmentId = element.dataset.assignmentId
    const name =
      element.dataset.assignmentName ||
      this.assignmentName(assignmentId) ||
      `Assignment ${assignmentId}`

    const employeeName = this.employeeNameValue || "Employee"
    const currentForecast = this.forecastFor(assignmentId)
    const actual = this.actualFor(assignmentId)
    const updated = this.updatedValueFor(assignmentId, element)

    return `
      <div class="small text-start">
        <strong>${this.escapeHtml(name)}</strong><br>
        Current forecasted energy: ${this.formatPercent(currentForecast)}<br>
        ${this.escapeHtml(employeeName)} actual (vs forecast): ${this.formatPercent(actual)}<br>
        New forecasted energy: ${this.formatPercent(updated)}
      </div>
    `
  }

  updatedValueFor(assignmentId, element) {
    const row = this.element.querySelector(`tr[data-assignment-id="${assignmentId}"]`)
    if (row) {
      const fromRow = this.readUpdatedForecastFromRow(row)
      if (fromRow != null) return fromRow
    }
    const key = String(assignmentId)
    const fromValue = this.updatedForecastValue[assignmentId] ?? this.updatedForecastValue[key]
    return fromValue != null ? parseInt(fromValue, 10) : null
  }

  forecastFor(assignmentId) {
    const key = String(assignmentId)
    const v = this.currentForecastValue[assignmentId] ?? this.currentForecastValue[key]
    return v != null && v !== "" ? parseInt(v, 10) : null
  }

  actualFor(assignmentId) {
    const key = String(assignmentId)
    const v = this.employeeActualValue[assignmentId] ?? this.employeeActualValue[key]
    return v != null && v !== "" ? parseInt(v, 10) : null
  }

  assignmentName(assignmentId) {
    const meta = this.assignmentsValue[assignmentId] || this.assignmentsValue[String(assignmentId)]
    return meta?.name
  }

  colorForAssignment(assignmentId) {
    return (
      this.colorsValue[assignmentId] ||
      this.colorsValue[String(assignmentId)] ||
      "#6c757d"
    )
  }

  formatPercent(value) {
    if (value == null || Number.isNaN(value)) return "—"
    return `${value}%`
  }

  bootstrapPopoverClass() {
    return window.bootstrap?.Popover || null
  }

  escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/"/g, "&quot;")
  }
}
