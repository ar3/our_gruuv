import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  choose(event) {
    event.preventDefault()
    if (!this.hasSelectTarget) return

    const teammateId = event.params.teammateId
    if (teammateId == null || teammateId === "") return

    this.selectTarget.value = String(teammateId)
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
