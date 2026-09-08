import { Controller } from "@hotwired/stimulus"

// Keeps the miniature certify block copy aligned with the selected Official Milestone.
export default class extends Controller {
  static targets = ["sentence", "milestonePhrase", "meanings", "zeroNote", "meaning"]
  static values = {
    abilityName: String
  }

  connect() {
    this.syncFromChecked()
  }

  officialChanged() {
    this.syncFromChecked()
  }

  syncFromChecked() {
    const checked = this.element.querySelector("input.js-calibration-official-milestone:checked")
    if (!checked) return

    const n = Number(checked.dataset.milestoneN)
    const label = checked.dataset.milestoneLabel || `Milestone ${n}`
    const isZero = n === 0

    if (this.hasZeroNoteTarget) {
      this.zeroNoteTarget.classList.toggle("d-none", !isZero)
    }
    if (this.hasSentenceTarget) {
      this.sentenceTarget.classList.toggle("d-none", isZero)
    }
    if (this.hasMeaningsTarget) {
      this.meaningsTarget.classList.toggle("d-none", isZero)
    }
    if (isZero) return

    if (this.hasMilestonePhraseTarget) {
      this.milestonePhraseTarget.textContent = `${label} ${this.abilityNameValue.toLowerCase()}`
    }

    this.meaningTargets.forEach((el) => {
      const template = el.dataset.template
      if (!template) return
      el.textContent = template.replaceAll("__N__", String(n)).replaceAll("__LABEL__", label)
    })
  }
}
