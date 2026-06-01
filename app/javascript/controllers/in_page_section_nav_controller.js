import { Controller } from "@hotwired/stimulus"

// Sticky in-page section navigation with scroll-spy and smooth scrolling.
export default class extends Controller {
  static targets = ["navLink"]
  static values = {
    initialSection: { type: String, default: "define" },
    scrollOffset: { type: Number, default: 100 }
  }

  connect() {
    this.handleClick = this.handleClick.bind(this)
    this.boundUpdate = this.debounce(() => this.updateActiveSection(), 10)

    this.navLinkTargets.forEach((link) => {
      link.addEventListener("click", this.handleClick)
    })

    window.addEventListener("scroll", this.boundUpdate, { passive: true })
    window.addEventListener("resize", this.boundUpdate)

    const initial = this.resolveInitialSection()
    if (initial) {
      this.scrollToSection(initial, false)
    }
    this.updateActiveSection()
  }

  disconnect() {
    window.removeEventListener("scroll", this.boundUpdate)
    window.removeEventListener("resize", this.boundUpdate)
    this.navLinkTargets.forEach((link) => {
      link.removeEventListener("click", this.handleClick)
    })
  }

  handleClick(event) {
    event.preventDefault()
    const href = event.currentTarget.getAttribute("href")
    if (!href || !href.startsWith("#")) return

    const sectionId = href.slice(1)
    this.scrollToSection(sectionId, true)
    if (window.history.replaceState) {
      window.history.replaceState(null, "", `${window.location.pathname}${window.location.search}#${sectionId}`)
    }
  }

  resolveInitialSection() {
    const hash = window.location.hash?.replace(/^#/, "")
    if (hash && this.sectionElement(hash)) return hash
    return this.initialSectionValue || "define"
  }

  scrollToSection(sectionId, smooth) {
    const section = this.sectionElement(sectionId)
    if (!section) return

    const top = section.getBoundingClientRect().top + window.pageYOffset - this.scrollOffsetValue
    window.scrollTo({ top, behavior: smooth ? "smooth" : "auto" })
    if (!smooth) {
      requestAnimationFrame(() => this.updateActiveSection())
    } else {
      window.setTimeout(() => this.updateActiveSection(), 400)
    }
  }

  updateActiveSection() {
    const scrollPosition = window.pageYOffset + this.scrollOffsetValue
    let current = this.sectionIds()[0] || "define"

    this.sectionIds().forEach((id) => {
      const section = this.sectionElement(id)
      if (!section) return

      const top = section.offsetTop
      const bottom = top + section.offsetHeight
      if (scrollPosition >= top && scrollPosition < bottom) {
        current = id
      }
    })

    this.navLinkTargets.forEach((link) => {
      const href = link.getAttribute("href")
      const isActive = href === `#${current}`
      link.classList.toggle("active", isActive)
      if (isActive) {
        link.setAttribute("aria-current", "true")
      } else {
        link.removeAttribute("aria-current")
      }
    })
  }

  sectionIds() {
    return Array.from(this.element.querySelectorAll("section[id]")).map((el) => el.id)
  }

  sectionElement(id) {
    const el = document.getElementById(id)
    if (el && this.element.contains(el)) return el
    return null
  }

  debounce(fn, wait) {
    let timeout
    return (...args) => {
      clearTimeout(timeout)
      timeout = window.setTimeout(() => fn(...args), wait)
    }
  }
}
