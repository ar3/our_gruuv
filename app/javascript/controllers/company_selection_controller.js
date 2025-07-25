import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "newCompanyField", "newCompanyInput"]

  connect() {
    console.log('Company selection controller connected')
  }

  toggleNewCompany() {
    const selectedValue = this.selectTarget.value
    
    if (selectedValue === 'new') {
      this.newCompanyFieldTarget.classList.remove('d-none')
      this.newCompanyInputTarget.focus()
      // Don't set required here - let server-side validation handle it
    } else {
      this.newCompanyFieldTarget.classList.add('d-none')
      this.newCompanyInputTarget.value = ''
    }
  }
} 