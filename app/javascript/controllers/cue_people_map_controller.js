import { Controller } from "@hotwired/stimulus"

// Per-cue observer / observee selects. Observer is stored on the cue annotation
// (not shared by speaker label) so read-aloud shout-outs can have different authors.
export default class extends Controller {
  static targets = [
    "observerTeammate",
    "observerCertainty",
    "observerPill",
    "observerName",
    "observeeTeammate",
    "observeeCertainty",
    "observeePill",
    "observeeName",
    "groupHint",
    "cueStatus"
  ]

  observerChanged(event) {
    this.syncPersonFields(event.currentTarget, {
      certaintyTargets: this.observerCertaintyTargets,
      pillTargets: this.observerPillTargets,
      nameTargets: this.observerNameTargets,
      idKey: "cueId"
    })
  }

  observeeChanged(event) {
    this.syncPersonFields(event.currentTarget, {
      certaintyTargets: this.observeeCertaintyTargets,
      pillTargets: this.observeePillTargets,
      nameTargets: this.observeeNameTargets,
      idKey: "cueId"
    })
    this.syncGroupHint(event.currentTarget)
  }

  syncGroupHint(selectEl) {
    const cueId = selectEl.dataset.cueId
    if (!cueId) return

    const hintEl = this.groupHintTargets.find((el) => el.dataset.cueId === cueId)
    if (!hintEl) return

    // Blank select = "Group of teammates (select later)"
    hintEl.classList.toggle("d-none", selectEl.value !== "")
  }

  syncPersonFields(source, { certaintyTargets, pillTargets, nameTargets, idKey }) {
    const cueId = source.dataset[idKey]
    if (!cueId) return

    const certaintyEl = certaintyTargets.find((el) => el.dataset.cueId === cueId)
    const pillEl = pillTargets.find((el) => el.dataset.cueId === cueId)
    const nameEl = nameTargets.find((el) => el.dataset.cueId === cueId)
    if (!certaintyEl) return

    const value = source.value
    const certaintyValue = value && value !== "" ? "certain" : "uncertain"
    certaintyEl.value = certaintyValue
    if (pillEl) this.applyPill(pillEl, certaintyValue)
    if (nameEl) {
      const selectedName = this.selectedOptionLabel(source)
      nameEl.textContent = selectedName
      nameEl.classList.toggle("d-none", !selectedName)
    }
  }

  applyPill(el, certainty) {
    const certain = certainty === "certain"
    el.textContent = certain ? "Certain" : "Uncertain"
    el.classList.toggle("text-bg-info", certain)
    el.classList.toggle("text-bg-warning", !certain)
  }

  selectedOptionLabel(selectEl) {
    if (!selectEl?.options || selectEl.selectedIndex < 0) return ""
    const text = selectEl.options[selectEl.selectedIndex]?.text?.trim() || ""
    if (!text || text === "—" || text.startsWith("Group of teammates")) return ""
    return text
  }
}
