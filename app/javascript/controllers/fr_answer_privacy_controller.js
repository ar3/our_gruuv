import { Controller } from "@hotwired/stimulus"

// Gates "Public to company" on feedback-request answer cards until the
// question's rating is Exceptional (strongly_agree) or Strong (agree).
// When company is locked and was selected, falls back to Subject+Manager.
export default class extends Controller {
  static targets = ["companyInput", "companyLabel", "fallbackInput", "hint"]

  static values = {
    positiveRatings: { type: Array, default: ["strongly_agree", "agree"] }
  }

  connect() {
    this.card = this.element.closest(".card")
    this.onCardChange = this.handleCardChange.bind(this)

    if (this.card) {
      this.card.addEventListener("change", this.onCardChange)
    }

    this.sync()
  }

  disconnect() {
    if (this.card) {
      this.card.removeEventListener("change", this.onCardChange)
    }
  }

  handleCardChange(event) {
    const target = event.target
    if (!target || target.type !== "radio") return
    if (!target.name || !target.name.endsWith("[rating]")) return

    this.sync()
  }

  sync() {
    const allowCompany = this.isPositiveRatingSelected()

    if (this.hasCompanyInputTarget) {
      this.companyInputTarget.disabled = !allowCompany

      if (!allowCompany && this.companyInputTarget.checked) {
        this.selectFallback()
      }
    }

    if (this.hasCompanyLabelTarget) {
      this.companyLabelTarget.classList.toggle("disabled", !allowCompany)
    }

    if (this.hasHintTarget) {
      this.hintTarget.classList.toggle("d-none", allowCompany)
    }
  }

  isPositiveRatingSelected() {
    const rating = this.currentRating()
    if (!rating) return false

    return this.positiveRatingsValue.includes(rating)
  }

  currentRating() {
    if (!this.card) return null

    const checkedRadio = this.card.querySelector(
      'input[type="radio"][name$="[rating]"]:checked'
    )
    if (checkedRadio) return checkedRadio.value

    const hiddenRating = this.card.querySelector(
      'input[type="hidden"][name$="[rating]"]'
    )
    return hiddenRating ? hiddenRating.value : null
  }

  selectFallback() {
    if (!this.hasFallbackInputTarget) return

    this.companyInputTarget.checked = false
    this.fallbackInputTarget.checked = true
    this.fallbackInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.fallbackInputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
