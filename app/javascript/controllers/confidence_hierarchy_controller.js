import { Controller } from "@hotwired/stimulus"

// Toggles child-tree collapse and chevron direction without opening the row detail.
export default class extends Controller {
  toggleChildren(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const targetSelector = button.getAttribute("data-bs-target")
    const target = targetSelector && this.element.querySelector(targetSelector)
    if (!target) return

    const icon = button.querySelector(".toggle-icon")
    const willShow = !target.classList.contains("show")

    if (window.bootstrap?.Collapse) {
      window.bootstrap.Collapse.getOrCreateInstance(target, { toggle: false }).toggle()
    } else {
      target.classList.toggle("show", willShow)
    }

    if (icon) {
      icon.classList.toggle("bi-chevron-down", !willShow)
      icon.classList.toggle("bi-chevron-up", willShow)
    }

    button.setAttribute("aria-expanded", willShow ? "true" : "false")
  }
}
