import { Controller } from "@hotwired/stimulus"

// Syncs selected pills with checkboxes in a multi-select form. Pair with options-filter
// for search. Set data-selection-toolbar-label-value on each checkbox for pill text.
export default class extends Controller {
  static targets = ["pills", "emptyLabel"]

  connect() {
    this.onChange = this.onChange.bind(this)
    this.onPillsClick = this.onPillsClick.bind(this)
    this.element.addEventListener("change", this.onChange)
    this.pillsTarget.addEventListener("click", this.onPillsClick)
    this.render()
  }

  disconnect() {
    this.element.removeEventListener("change", this.onChange)
    this.pillsTarget.removeEventListener("click", this.onPillsClick)
  }

  onChange(event) {
    if (event.target.matches('input[type="checkbox"]')) this.render()
  }

  onPillsClick(event) {
    const removeBtn = event.target.closest("[data-selection-toolbar-remove]")
    if (!removeBtn) return

    event.preventDefault()
    const checkbox = this.checkboxForId(removeBtn.dataset.selectionToolbarRemove)
    if (!checkbox || checkbox.disabled) return

    checkbox.checked = false
    checkbox.dispatchEvent(new Event("change", { bubbles: true }))
    this.render()
  }

  render() {
    const checked = this.checkboxes().filter((cb) => cb.checked)
    this.pillsTarget.replaceChildren()

    checked.forEach((checkbox) => {
      this.pillsTarget.appendChild(this.buildPill(checkbox))
    })

    if (this.hasEmptyLabelTarget) {
      this.emptyLabelTarget.classList.toggle("d-none", checked.length > 0)
    }
  }

  checkboxes() {
    return Array.from(this.element.querySelectorAll('input[type="checkbox"]')).filter(
      (cb) => !cb.disabled
    )
  }

  checkboxForId(id) {
    if (!id) return null
    return this.element.querySelector(`input[type="checkbox"]#${CSS.escape(id)}`)
  }

  buildPill(checkbox) {
    const pill = document.createElement("span")
    pill.className =
      "badge bg-primary rounded-pill d-inline-flex align-items-center gap-2 py-2 px-3 selection-toolbar-pill"

    const label = document.createElement("span")
    label.textContent = this.pillLabel(checkbox)

    const removeBtn = document.createElement("button")
    removeBtn.type = "button"
    removeBtn.className =
      "btn btn-link btn-sm p-0 text-white text-decoration-none selection-toolbar-pill-remove"
    removeBtn.setAttribute("aria-label", `Remove ${label.textContent}`)
    removeBtn.dataset.selectionToolbarRemove = checkbox.id
    removeBtn.innerHTML = '<i class="bi bi-x-lg" aria-hidden="true"></i>'

    pill.append(label, removeBtn)
    return pill
  }

  pillLabel(checkbox) {
    const explicit = checkbox.dataset.selectionToolbarLabel
    if (explicit) return explicit

    if (checkbox.id) {
      const labelEl = this.element.querySelector(`label[for="${CSS.escape(checkbox.id)}"]`)
      if (labelEl) {
        const strong = labelEl.querySelector("strong")
        if (strong) return strong.textContent.trim()
        return labelEl.textContent.trim()
      }
    }

    return checkbox.value
  }
}
