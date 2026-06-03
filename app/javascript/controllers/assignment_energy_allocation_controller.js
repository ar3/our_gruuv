import { Controller } from "@hotwired/stimulus"

const ALERT_SUCCESS = "success"
const ALERT_WARNING = "warning"
const ALERT_DANGER = "danger"

// Bulk check-in: planned bar (server-rendered) + live reflection bar from assignment rows.
export default class extends Controller {
  static targets = [
    "panel",
    "plannedTotal",
    "reflectionTotal",
    "reflectionBar",
    "reflectionEmpty",
    "plannedTrack",
    "reflectionTrack"
  ]

  static values = {
    colors: Object,
    plannedByAssignment: Object,
    assignments: Object,
    reflectionByAssignment: Object
  }

  connect() {
    this.boundRefresh = this.refreshReflectionFromDom.bind(this)
    this.element.addEventListener("change", this.boundRefresh)
    this.element.addEventListener("input", this.boundRefresh)
    this.refreshReflectionFromDom()
    this.initializeAllSegmentPopovers()
  }

  disconnect() {
    this.element.removeEventListener("change", this.boundRefresh)
    this.element.removeEventListener("input", this.boundRefresh)
    this.disposeAllSegmentPopovers()
  }

  refreshReflectionFromDom() {
    const segments = this.collectReflectionSegments()
    const total = segments.reduce((sum, s) => sum + s.value, 0)
    const layout = this.computeBarLayout(segments, total)

    this.updateReflectionTotal(total, layout.over_hundred)
    this.updatePanelAlert(total)
    this.renderReflectionBar(segments, layout)
    this.initializeSegmentPopovers(this.reflectionBarTarget)
  }

  collectReflectionSegments() {
    const assignmentIds = new Set(Object.keys(this.colorsValue || {}))
    const segments = []

    assignmentIds.forEach((assignmentId) => {
      const value = this.readReflectionForAssignment(assignmentId)
      if (value == null || value <= 0) return

      segments.push({
        assignment_id: assignmentId,
        name: this.titleForAssignment(assignmentId) || `Assignment ${assignmentId}`,
        value,
        display_weight: value,
        color: this.colorForAssignment(assignmentId)
      })
    })

    return segments.sort((a, b) => a.name.localeCompare(b.name))
  }

  readReflectionForAssignment(assignmentId) {
    const fromDom = this.readReflectionFromEnergySelect(assignmentId)
    if (fromDom != null) return fromDom

    const energyRow = this.element.querySelector(
      `[data-assignment-energy-row][data-assignment-id="${assignmentId}"]`
    )
    if (energyRow) {
      const fromRow = this.readActualEnergyFromRow(energyRow)
      if (fromRow != null) return fromRow
    }

    const tableRow = this.element.querySelector(`tr[data-assignment-id="${assignmentId}"]`)
    if (tableRow) {
      const fromTable = this.readActualEnergyFromRow(tableRow)
      if (fromTable != null) return fromTable
    }

    const key = String(assignmentId)
    const raw =
      this.reflectionByAssignmentValue[assignmentId] ??
      this.reflectionByAssignmentValue[key]
    if (raw == null || raw === "") return null

    const parsed = parseInt(raw, 10)
    return Number.isNaN(parsed) ? null : parsed
  }

  readReflectionFromEnergySelect(assignmentId) {
    const id = String(assignmentId)
    const selects = this.element.querySelectorAll(
      'select[name*="[actual_energy_percentage]"]'
    )

    for (const select of selects) {
      const row = select.closest("[data-assignment-id]")
      if (!row || String(row.dataset.assignmentId) !== id) continue
      if (row.classList.contains("assignment-energy-allocation-bar__segment")) continue

      if (select.value === "") return null

      const parsed = parseInt(select.value, 10)
      return Number.isNaN(parsed) ? null : parsed
    }

    return null
  }

  readActualEnergyFromRow(row) {
    const select = row.querySelector('select[name*="[actual_energy_percentage]"]')
    if (select && select.value !== "") {
      const parsed = parseInt(select.value, 10)
      return Number.isNaN(parsed) ? null : parsed
    }

    const hidden = row.querySelector('input[type="hidden"][name*="[actual_energy_percentage]"]')
    if (hidden && hidden.value !== "") {
      const parsed = parseInt(hidden.value, 10)
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
      let weightSum = segments.reduce((sum, s) => sum + (s.value > 0 ? s.value : s.display_weight), 0)
      if (weightSum <= 0) weightSum = segments.reduce((sum, s) => sum + s.display_weight, 0)
      if (weightSum <= 0) weightSum = 1

      return {
        over_hundred: true,
        unallocated_percent: 0,
        segments: segments.map((segment) => {
          const weight = segment.value > 0 ? segment.value : segment.display_weight
          return {
            ...segment,
            flex_percent: (weight / weightSum) * 100
          }
        })
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

  updateReflectionTotal(total, overHundred) {
    if (!this.hasReflectionTotalTarget) return

    const label = overHundred ? `${total}% (over 100%)` : `${total}%`
    this.reflectionTotalTarget.textContent = label
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

  renderReflectionBar(segments, layout) {
    if (!this.hasReflectionBarTarget) return

    if (!segments.length) {
      this.reflectionBarTarget.innerHTML = `
        <div class="assignment-energy-allocation-bar__empty small text-muted py-1" data-assignment-energy-allocation-target="reflectionEmpty">
          Set a percentage on assignments below to see how your time adds up.
        </div>
      `
      return
    }

    const trackClass = layout.over_hundred
      ? "assignment-energy-allocation-bar__track assignment-energy-allocation-bar__track--over"
      : "assignment-energy-allocation-bar__track"

    let segmentsHtml = layout.segments
      .map((segment) => this.segmentMarkup(segment))
      .join("")

    if (layout.unallocated_percent > 0) {
      segmentsHtml += `
        <div class="assignment-energy-allocation-bar__segment assignment-energy-allocation-bar__segment--unallocated"
             style="flex: 0 0 ${layout.unallocated_percent}%;"
             title="Unallocated"></div>
      `
    }

    this.reflectionBarTarget.innerHTML = `
      <div class="assignment-energy-allocation-bar__track-wrap">
        <div class="${trackClass}" data-assignment-energy-allocation-target="reflectionTrack">
          ${segmentsHtml}
        </div>
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

  initializeAllSegmentPopovers() {
    if (this.hasPlannedTrackTarget) {
      this.initializeSegmentPopovers(this.plannedTrackTarget)
    }
    if (this.hasReflectionBarTarget) {
      this.initializeSegmentPopovers(this.reflectionBarTarget)
    }
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

  disposeAllSegmentPopovers() {
    const Popover = this.bootstrapPopoverClass()
    if (!Popover) return

    this.element
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
      this.assignmentMeta(assignmentId)?.name ||
      `Assignment ${assignmentId}`

    const planned = this.plannedPercentFor(assignmentId)
    const actual = this.actualPercentFor(assignmentId)

    return `
      <div class="small text-start">
        <strong>${this.escapeHtml(name)}</strong><br>
        Planned: ${this.formatPercent(planned)}<br>
        Actual: ${this.formatPercent(actual)}
      </div>
    `
  }

  plannedPercentFor(assignmentId) {
    const planned = this.plannedByAssignmentValue[assignmentId]
    if (planned != null && planned !== "") return parseInt(planned, 10)

    const key = String(assignmentId)
    const fromValue = this.plannedByAssignmentValue[key]
    if (fromValue != null && fromValue !== "") return parseInt(fromValue, 10)

    const meta = this.assignmentMeta(assignmentId)
    if (meta && meta.planned != null) return parseInt(meta.planned, 10)

    return null
  }

  actualPercentFor(assignmentId) {
    const fromSelect = this.readReflectionFromEnergySelect(assignmentId)
    if (fromSelect != null) return fromSelect

    const row = this.element.querySelector(`tr[data-assignment-id="${assignmentId}"]`)
    if (!row) return null
    return this.readActualEnergyFromRow(row)
  }

  assignmentMeta(assignmentId) {
    return (
      this.assignmentsValue[assignmentId] ||
      this.assignmentsValue[String(assignmentId)] ||
      null
    )
  }

  titleForAssignment(assignmentId) {
    const meta = this.assignmentMeta(assignmentId)
    if (meta?.name) return meta.name

    const id = String(assignmentId)
    const row = this.element.querySelector(
      `[data-assignment-energy-row][data-assignment-id="${id}"], tr[data-assignment-id="${id}"]`
    )
    const fromDom = row?.dataset?.assignmentTitle
    return fromDom || null
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
    if (typeof window !== "undefined" && window.bootstrap?.Popover) {
      return window.bootstrap.Popover
    }
    return null
  }

  escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/"/g, "&quot;")
  }
}
