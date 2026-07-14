import { Controller } from "@hotwired/stimulus"

// Manages Required / Suggested / No Association radios for a position-assignment row.
// Top (configure) rows: disable min/max selects when No Association is selected.
// Add rows: apply default min/max when Required or Suggested is chosen.
export default class extends Controller {
  static targets = ["minEnergy", "maxEnergy", "type"]
  static values = {
    addMode: { type: Boolean, default: false },
    requiredMin: { type: Number, default: 5 },
    requiredMax: { type: Number, default: 15 },
    suggestedMin: { type: Number, default: 0 },
    suggestedMax: { type: Number, default: 10 }
  }

  connect() {
    this.sync()
  }

  changeType() {
    if (this.addModeValue) {
      this.applyAddDefaults()
    }
    this.sync()
  }

  sync() {
    const type = this.selectedType()
    const associated = type === "required" || type === "suggested"

    if (this.hasMinEnergyTarget) {
      this.minEnergyTarget.disabled = !associated
    }
    if (this.hasMaxEnergyTarget) {
      this.maxEnergyTarget.disabled = !associated
    }
  }

  applyAddDefaults() {
    const type = this.selectedType()
    if (!this.hasMinEnergyTarget || !this.hasMaxEnergyTarget) return

    if (type === "required") {
      this.minEnergyTarget.value = String(this.requiredMinValue)
      this.maxEnergyTarget.value = String(this.requiredMaxValue)
    } else if (type === "suggested") {
      this.minEnergyTarget.value = String(this.suggestedMinValue)
      this.maxEnergyTarget.value = String(this.suggestedMaxValue)
    } else {
      this.minEnergyTarget.value = ""
      this.maxEnergyTarget.value = ""
    }
  }

  selectedType() {
    const checked = this.typeTargets.find((el) => el.checked)
    return checked ? checked.value : "none"
  }
}
