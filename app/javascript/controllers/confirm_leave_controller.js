import { Controller } from "@hotwired/stimulus"

// After the form is edited, prompts "Did you save?" when the user clicks a link that would
// navigate away (GET, same tab). Form submits (POST/PATCH) are not intercepted unless
// singleActiveForm is enabled and the user submits a different form while another is dirty.
export default class extends Controller {
  static values = {
    message: {
      type: String,
      default: "Did you save? Your unsaved changes may be lost if you leave."
    },
    singleActiveForm: { type: Boolean, default: false },
    blockedDirtyMessage: {
      type: String,
      default:
        "Please click Check In to save the goal you previously modified, or you might lose your changes."
    }
  }

  connect() {
    this.dirty = false
    this.activeForm = null
    this.snapshotInitialFieldValues()
    this.boundHandleClick = this.handleClick.bind(this)
    this.boundHandleSubmit = this.handleSubmit.bind(this)
    document.addEventListener("click", this.boundHandleClick, true)
    this.element.addEventListener("submit", this.boundHandleSubmit, true)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClick, true)
    this.element.removeEventListener("submit", this.boundHandleSubmit, true)
  }

  markDirty(event) {
    if (!this.element.contains(event.target)) return

    const form = event.target.closest("form")
    if (this.singleActiveFormValue) {
      if (!form?.classList.contains("goal-check-in-form")) return

      if (this.activeForm && this.activeForm !== form) {
        this.revertControl(event.target)
        alert(this.blockedDirtyMessageValue)
        return
      }
      this.activeForm = form
    }

    this.dirty = true
  }

  guardSecondForm(event) {
    if (!this.singleActiveFormValue || !this.dirty || !this.activeForm) return

    const form = event.target.closest("form.goal-check-in-form")
    if (!form || form === this.activeForm) return

    event.target.blur()
    alert(this.blockedDirtyMessageValue)
  }

  handleSubmit(event) {
    if (!this.singleActiveFormValue || !this.dirty || !this.activeForm) return

    const form = event.target
    if (!form?.classList.contains("goal-check-in-form")) return
    if (form === this.activeForm) return

    event.preventDefault()
    event.stopPropagation()
    alert(this.blockedDirtyMessageValue)
  }

  snapshotInitialFieldValues() {
    const selector = this.singleActiveFormValue
      ? "form.goal-check-in-form input, form.goal-check-in-form select, form.goal-check-in-form textarea"
      : "input, select, textarea"

    this.element.querySelectorAll(selector).forEach((field) => {
      field.dataset.confirmLeaveInitialValue = field.value
    })
  }

  revertControl(control) {
    if (!control || control.dataset.confirmLeaveInitialValue === undefined) return
    control.value = control.dataset.confirmLeaveInitialValue
  }

  markCleanOnSuccess(event) {
    if (event.detail?.success) {
      this.dirty = false
    }
  }

  handleClick(event) {
    const link = event.target.closest("a[href]")
    if (!link || !this.isNavigatingLink(link)) return
    if (!this.dirty) return

    event.preventDefault()
    event.stopPropagation()

    if (!confirm(this.messageValue)) return

    if (window.Turbo && typeof window.Turbo.visit === "function") {
      window.Turbo.visit(link.href)
    } else {
      window.location.href = link.href
    }
  }

  isNavigatingLink(link) {
    const href = (link.getAttribute("href") || "").trim()
    if (!href || href === "#" || href.startsWith("#") || href.toLowerCase().startsWith("javascript:")) {
      return false
    }
    if (link.target && link.target !== "_self") {
      return false
    }
    const method = (link.getAttribute("data-method") || link.getAttribute("data-turbo-method") || "get").toLowerCase()
    if (method !== "get") {
      return false
    }
    return true
  }
}
