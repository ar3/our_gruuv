import { Controller } from "@hotwired/stimulus"

// Manages Inbound / Outbound / No Association radios for a title-path row.
// Configure rows: disable path type when No Association is selected.
// Add rows: default path type when Inbound or Outbound is chosen.
export default class extends Controller {
  static targets = ["pathType", "direction"]
  static values = {
    addMode: { type: Boolean, default: false },
    endCap: { type: Boolean, default: false },
    defaultPathType: { type: String, default: "natural_progression" }
  }

  connect() {
    this.sync()
  }

  changeDirection() {
    if (this.addModeValue) {
      this.applyAddDefaults()
    }
    this.sync()
  }

  sync() {
    const direction = this.selectedDirection()
    const associated = direction === "inbound" || direction === "outbound"

    if (this.hasPathTypeTarget && this.pathTypeTarget.tagName === "SELECT") {
      this.pathTypeTarget.disabled = !associated
    }
  }

  applyAddDefaults() {
    if (!this.hasPathTypeTarget) return

    const direction = this.selectedDirection()
    if (direction === "inbound" || direction === "outbound") {
      this.pathTypeTarget.value = this.defaultPathTypeValue
    } else {
      this.pathTypeTarget.value = this.defaultPathTypeValue
    }
  }

  selectedDirection() {
    const checked = this.directionTargets.find((el) => el.checked)
    return checked ? checked.value : "none"
  }
}
