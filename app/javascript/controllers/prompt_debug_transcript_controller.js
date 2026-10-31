import { Controller } from "@hotwired/stimulus"

// Links transcript cues <-> candidate rows on prompt-debug consults.
export default class extends Controller {
  static targets = ["cue", "item"]

  connect() {
    this.activeCueId = null
    this.activeItemId = null
  }

  highlightFromItem(event) {
    event.preventDefault()
    const el = event.currentTarget
    const itemId = el.dataset.itemId
    if (!itemId) return
    this.clearHighlights()
    this.activeItemId = itemId
    const row = this.itemTargets.find((target) => target.dataset.itemId === itemId)
    row?.classList.add("table-warning")

    const cueIds = (el.dataset.cueIds || row?.dataset.cueIds || "").split(",").filter(Boolean)
    cueIds.forEach((cueId) => {
      const cue = this.cueTargets.find((target) => target.dataset.cueId === cueId)
      if (!cue) return
      cue.classList.add("border-warning", "bg-warning-subtle")
    })
    const first = cueIds[0] && this.cueTargets.find((target) => target.dataset.cueId === cueIds[0])
    first?.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }

  highlightFromCue(event) {
    const cue = event.currentTarget
    const cueId = cue.dataset.cueId
    if (!cueId) return
    this.clearHighlights()
    this.activeCueId = cueId
    cue.classList.add("border-warning", "bg-warning-subtle")

    const itemIds = (cue.dataset.itemIds || "").split(",").filter(Boolean)
    itemIds.forEach((itemId) => {
      const row = this.itemTargets.find((el) => el.dataset.itemId === itemId)
      if (!row) return
      row.classList.add("table-warning")
    })
    const first = itemIds[0] && this.itemTargets.find((el) => el.dataset.itemId === itemIds[0])
    first?.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }

  clearHighlights() {
    this.cueTargets.forEach((el) => {
      el.classList.remove("border-warning", "bg-warning-subtle")
    })
    this.itemTargets.forEach((el) => {
      el.classList.remove("table-warning")
    })
    this.activeCueId = null
    this.activeItemId = null
  }
}
