import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggleBetweenFields(event) {
    const betweenFields = this.element.querySelector('.between-fields-container')
    if (event.target && event.target.value === 'between') {
      if (betweenFields) {
        betweenFields.style.display = 'block'
      }
    } else {
      if (betweenFields) {
        betweenFields.style.display = 'none'
      }
    }
  }
}

