import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["companySelect", "positionSelect", "managerSelect"]

  connect() {
    this.updateDependentFields()
  }

  companyChanged() {
    this.updateDependentFields()
  }

  updateDependentFields() {
    const companyId = this.companySelectTarget.value
    
    if (companyId) {
      this.fetchPositions(companyId)
      this.fetchManagers(companyId)
      this.enableDependentFields()
    } else {
      this.disableDependentFields()
      this.clearDependentFields()
    }
  }

  async fetchPositions(companyId) {
    try {
      const response = await fetch(`/organizations/${companyId}/positions.json`)
      const positions = await response.json()
      
      this.positionSelectTarget.innerHTML = '<option value="">Select a position</option>'
      positions.forEach(position => {
        const option = document.createElement('option')
        option.value = position.id
        option.textContent = `${position.title.external_title} - ${position.position_level.level}`
        this.positionSelectTarget.appendChild(option)
      })
    } catch (error) {
      console.error('Error fetching positions:', error)
    }
  }

  async fetchManagers(companyId) {
    try {
      const response = await fetch(`/organizations/${companyId}/employees.json`)
      const employees = await response.json()
      
      this.managerSelectTarget.innerHTML = '<option value="">Select a manager (optional)</option>'
      employees.forEach(employee => {
        const option = document.createElement('option')
        option.value = employee.id
        option.textContent = employee.display_name
        this.managerSelectTarget.appendChild(option)
      })
    } catch (error) {
      console.error('Error fetching managers:', error)
    }
  }

  enableDependentFields() {
    this.positionSelectTarget.disabled = false
    this.managerSelectTarget.disabled = false
  }

  disableDependentFields() {
    this.positionSelectTarget.disabled = true
    this.managerSelectTarget.disabled = true
  }

  clearDependentFields() {
    this.positionSelectTarget.innerHTML = '<option value="">Select a company first</option>'
    this.managerSelectTarget.innerHTML = '<option value="">Select a company first</option>'
  }
}
