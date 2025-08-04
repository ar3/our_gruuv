import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "dropdown", "card", "minEnergy", "maxEnergy", "error"]
  static values = { 
    type: String,
    positionId: Number,
    availableAssignments: Array
  }

  connect() {
    console.log("Position assignments controller connected")
    
    // Listen for assignments being added to other sections
    this.element.addEventListener('assignmentAdded', this.handleAssignmentAdded.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('assignmentAdded', this.handleAssignmentAdded.bind(this))
  }

  addAssignment(event) {
    const assignmentId = event.target.value
    if (!assignmentId) return

    const assignmentTitle = event.target.options[event.target.selectedIndex].text
    const assignment = this.availableAssignmentsValue.find(a => a.id == assignmentId)
    
    if (!assignment) return

    // Find the container for this specific dropdown
    const dropdown = event.target
    const container = this.findContainerForDropdown(dropdown)
    
    // Create the assignment card
    const cardHtml = this.createAssignmentCard(assignment, assignmentTitle)
    container.insertAdjacentHTML('beforeend', cardHtml)
    
    // Reset dropdown
    event.target.value = ''
    
    // Remove from available assignments
    this.removeFromAvailableAssignments(assignmentId)
    
    // Update all dropdown options
    this.updateAllDropdownOptions()
    
    // Notify other assignment sections that this assignment was added
    this.dispatch('assignmentAdded', { detail: { assignmentId: assignmentId, assignmentTitle: assignmentTitle } })
  }

  removeAssignment(event) {
    const card = event.target.closest('.assignment-card')
    const assignmentId = card.dataset.assignmentId
    const assignmentTitle = card.querySelector('.assignment-title').textContent
    
    // Add back to available assignments
    this.addToAvailableAssignments(assignmentId, assignmentTitle)
    
    // Remove card
    card.remove()
    
    // Update dropdown options
    this.updateDropdownOptions()
    
    // Notify other assignment sections that this assignment was removed
    this.dispatch('assignmentRemoved', { detail: { assignmentId: assignmentId, assignmentTitle: assignmentTitle } })
  }

  updateEnergy(event) {
    const card = event.target.closest('.assignment-card')
    const minInput = card.querySelector('.min-energy')
    const maxInput = card.querySelector('.max-energy')
    const errorElement = card.querySelector('.energy-error')
    const minHiddenInput = card.querySelector('input[name*="min_energy"]')
    const maxHiddenInput = card.querySelector('input[name*="max_energy"]')
    
    const min = parseInt(minInput.value) || 0
    const max = parseInt(maxInput.value) || 0
    
    // Update hidden inputs for form submission
    if (minHiddenInput) minHiddenInput.value = min || ''
    if (maxHiddenInput) maxHiddenInput.value = max || ''
    
    // Clear previous error
    errorElement.textContent = ''
    errorElement.classList.add('d-none')
    
    // Validate 5-unit increments
    if (min > 0 && min % 5 !== 0) {
      errorElement.textContent = 'Min percentage must be in increments of 5'
      errorElement.classList.remove('d-none')
      return
    }
    
    if (max > 0 && max % 5 !== 0) {
      errorElement.textContent = 'Max percentage must be in increments of 5'
      errorElement.classList.remove('d-none')
      return
    }
    
    // Validate
    if (min > 0 && max > 0 && max <= min) {
      errorElement.textContent = 'Max must be greater than min'
      errorElement.classList.remove('d-none')
      return
    }
    
    if (min > 100 || max > 100) {
      errorElement.textContent = 'Percentage cannot exceed 100%'
      errorElement.classList.remove('d-none')
      return
    }
  }

  createAssignmentCard(assignment, title) {
    return `
      <div class="assignment-card card mb-2" data-assignment-id="${assignment.id}" data-controller="assignment-card">
        <div class="card-body p-3">
          <div class="d-flex justify-content-between align-items-start mb-2">
            <h6 class="card-title mb-0 assignment-title">${title}</h6>
            <button type="button" class="btn-close btn-sm" data-action="click->position-assignments#removeAssignment"></button>
          </div>
          
          <div class="row g-2">
            <div class="col-6">
              <label class="form-label small mb-1">Min % of effort</label>
              <input type="number" class="form-control form-control-sm min-energy" 
                     placeholder="0" min="0" max="100" step="5"
                     data-action="input->position-assignments#updateEnergy">
            </div>
            <div class="col-6">
              <label class="form-label small mb-1">Max % of effort</label>
              <input type="number" class="form-control form-control-sm max-energy" 
                     placeholder="100" min="0" max="100" step="5"
                     data-action="input->position-assignments#updateEnergy">
            </div>
          </div>
          
          <div class="energy-error text-danger small mt-1 d-none"></div>
          
          <input type="hidden" name="position[${this.typeValue}_assignment_ids][]" value="${assignment.id}">
          <input type="hidden" name="position[${this.typeValue}_assignment_min_energy][]" value="">
          <input type="hidden" name="position[${this.typeValue}_assignment_max_energy][]" value="">
        </div>
      </div>
    `
  }

  removeFromAvailableAssignments(assignmentId) {
    this.availableAssignmentsValue = this.availableAssignmentsValue.filter(a => a.id != assignmentId)
  }

  addToAvailableAssignments(assignmentId, title) {
    this.availableAssignmentsValue.push({ id: assignmentId, title: title })
  }



  handleAssignmentAdded(event) {
    const { assignmentId, assignmentTitle } = event.detail
    
    // Remove this assignment from our available assignments
    this.removeFromAvailableAssignments(assignmentId)
    
    // Update dropdown options
    this.updateDropdownOptions()
  }

  handleAssignmentRemoved(event) {
    const { assignmentId, assignmentTitle } = event.detail
    
    // Add this assignment back to our available assignments
    this.addToAvailableAssignments(assignmentId, assignmentTitle)
    
    // Update all dropdown options
    this.updateAllDropdownOptions()
  }

  findContainerForDropdown(dropdown) {
    // Find the container that's associated with this dropdown
    const section = dropdown.closest('.border.rounded.p-3.bg-light')
    return section.querySelector('[data-position-assignments-target="container"]')
  }

  updateAllDropdownOptions() {
    // Update all dropdowns in the form
    this.dropdownTargets.forEach(dropdown => {
      this.updateDropdownOptions(dropdown)
    })
  }

  updateDropdownOptions(dropdown = null) {
    const targetDropdown = dropdown || this.dropdownTarget
    const currentValue = targetDropdown.value
    
    // Clear existing options except the first (prompt)
    while (targetDropdown.options.length > 1) {
      targetDropdown.remove(1)
    }
    
    // Add available assignments
    this.availableAssignmentsValue.forEach(assignment => {
      const option = document.createElement('option')
      option.value = assignment.id
      option.textContent = assignment.title
      targetDropdown.appendChild(option)
    })
    
    // Restore selected value if it's still available
    if (currentValue && this.availableAssignmentsValue.find(a => a.id == currentValue)) {
      targetDropdown.value = currentValue
    }
  }
} 