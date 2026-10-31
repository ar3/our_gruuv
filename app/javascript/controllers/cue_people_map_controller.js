import { Controller } from "@hotwired/stimulus"

// Syncs observer teammate + certainty across cues that share a speaker label,
// and flips certainty pills when the user picks someone.
export default class extends Controller {
  static targets = [
    "observerTeammate",
    "observerCertainty",
    "observerPill",
    "observeeTeammate",
    "observeeCertainty",
    "observeePill",
    "cueStatus"
  ]

  syncObserver(event) {
    const label = event.currentTarget.dataset.speakerLabel
    if (!label) return

    const teammateEl = this.observerTeammateTargets.find((el) => el.dataset.speakerLabel === label)
    const certaintyEl = this.observerCertaintyTargets.find((el) => el.dataset.speakerLabel === label)
    if (!teammateEl || !certaintyEl) return

    if (event.currentTarget === teammateEl) {
      certaintyEl.value = teammateEl.value ? "certain" : "uncertain"
    }

    const teammateValue = teammateEl.value
    const certaintyValue = certaintyEl.value

    this.observerTeammateTargets.forEach((el) => {
      if (el.dataset.speakerLabel !== label) return
      el.value = teammateValue
    })
    this.observerCertaintyTargets.forEach((el) => {
      if (el.dataset.speakerLabel !== label) return
      el.value = certaintyValue
    })
    this.observerPillTargets.forEach((el) => {
      if (el.dataset.speakerLabel !== label) return
      this.applyPill(el, certaintyValue)
    })
  }

  observeeChanged(event) {
    const cueId = event.currentTarget.dataset.cueId
    if (!cueId) return

    const teammateEl = this.observeeTeammateTargets.find((el) => el.dataset.cueId === cueId)
    const certaintyEl = this.observeeCertaintyTargets.find((el) => el.dataset.cueId === cueId)
    const pillEl = this.observeePillTargets.find((el) => el.dataset.cueId === cueId)
    if (!teammateEl || !certaintyEl) return

    if (event.currentTarget === teammateEl) {
      certaintyEl.value = teammateEl.value ? "certain" : "uncertain"
    }
    if (pillEl) this.applyPill(pillEl, certaintyEl.value)
  }

  applyPill(el, certainty) {
    const certain = certainty === "certain"
    el.textContent = certain ? "Certain" : "Uncertain"
    el.classList.toggle("text-bg-info", certain)
    el.classList.toggle("text-bg-warning", !certain)
  }
}
