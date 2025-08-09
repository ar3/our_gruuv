import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.toggleOptions()
    this.addEventListeners()
  }

  toggleOptions() {
    const existingRadio = document.getElementById('user_type_existing')
    const newRadio = document.getElementById('user_type_new')
    const existingOptions = document.getElementById('existing-user-options')
    const newOptions = document.getElementById('new-user-options')
    
    if (existingRadio.checked) {
      existingOptions.classList.remove('d-none')
      newOptions.classList.add('d-none')
    } else {
      existingOptions.classList.add('d-none')
      newOptions.classList.remove('d-none')
    }
  }

  addEventListeners() {
    const existingRadio = document.getElementById('user_type_existing')
    const newRadio = document.getElementById('user_type_new')
    
    existingRadio.addEventListener('change', () => this.toggleOptions())
    newRadio.addEventListener('change', () => this.toggleOptions())
  }
}
