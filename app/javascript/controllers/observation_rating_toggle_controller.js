import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onPointerDownCapture = this.handlePointerDownCapture.bind(this)
    this.onClickCapture = this.handleClickCapture.bind(this)
    this.onChange = this.handleChange.bind(this)

    this.element.addEventListener("pointerdown", this.onPointerDownCapture, true)
    this.element.addEventListener("click", this.onClickCapture, true)
    this.element.addEventListener("change", this.onChange)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onPointerDownCapture, true)
    this.element.removeEventListener("click", this.onClickCapture, true)
    this.element.removeEventListener("change", this.onChange)
  }

  handlePointerDownCapture(event) {
    const radio = this.resolveRadio(event.target)
    if (!radio) return

    radio.dataset.wasChecked = radio.checked ? "true" : "false"
  }

  handleClickCapture(event) {
    const radio = this.resolveRadio(event.target)
    if (!radio) return

    const wasChecked = radio.dataset.wasChecked === "true"
    delete radio.dataset.wasChecked

    if (!wasChecked || radio.value === "na") return

    event.preventDefault()

    const naRadio = this.findNaRadioForGroup(radio.name)
    if (!naRadio) return

    if (!naRadio.checked) {
      naRadio.checked = true
    }

    this.dispatchChangeEvents(naRadio)
    this.syncLegacyActiveClasses(naRadio)
  }

  handleChange(event) {
    const radio = this.resolveRadio(event.target)
    if (!radio) return

    this.syncHiddenFields(radio)
    this.syncLegacyActiveClasses(radio)
  }

  resolveRadio(target) {
    if (!target) return null

    if (target.matches && target.matches('input[type="radio"]')) {
      return target
    }

    const label = target.closest ? target.closest("label[for]") : null
    if (!label) return null

    const radioId = label.getAttribute("for")
    if (!radioId) return null

    const radio = this.element.querySelector(`#${CSS.escape(radioId)}`)
    if (!radio || radio.type !== "radio") return null

    return radio
  }

  findNaRadioForGroup(groupName) {
    if (!groupName) return null

    const radios = this.element.querySelectorAll('input[type="radio"]')
    for (const radio of radios) {
      if (radio.name === groupName && radio.value === "na") {
        return radio
      }
    }

    return null
  }

  dispatchChangeEvents(radio) {
    radio.dispatchEvent(new Event("input", { bubbles: true }))
    radio.dispatchEvent(new Event("change", { bubbles: true }))
  }

  syncHiddenFields(radio) {
    const { rateableType, rateableId, ratingKey } = radio.dataset
    if (!rateableType || !rateableId || !ratingKey) return

    const hiddenTypeField = document.querySelector(
      `input[name="observation[observation_ratings_attributes][${ratingKey}][rateable_type]"]`
    )
    const hiddenIdField = document.querySelector(
      `input[name="observation[observation_ratings_attributes][${ratingKey}][rateable_id]"]`
    )

    if (hiddenTypeField) hiddenTypeField.value = rateableType
    if (hiddenIdField) hiddenIdField.value = rateableId
  }

  syncLegacyActiveClasses(radio) {
    const wrapper = this.element.closest("[data-legacy-rating-buttons]")
    if (!wrapper) return

    const radios = wrapper.querySelectorAll(`input[type="radio"][name="${CSS.escape(radio.name)}"]`)
    radios.forEach((groupRadio) => {
      const label = groupRadio.closest("label.btn")
      if (!label) return

      label.classList.toggle("active", groupRadio.checked)
    })
  }
}
