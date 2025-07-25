import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["companySelect", "newCompanyField", "newCompanyInput", "teamSelect", "newTeamField", "newTeamInput", "teamNameField"]
  static values = { initialCompany: String, initialTeam: String }

  connect() {
    console.log('Organization selection controller connected')
    // Initialize team field as disabled
    this.disableTeamField()
    
    // Handle initial values if provided
    this.initializeWithValues()
  }

  initializeWithValues() {
    if (this.hasInitialCompanyValue && this.initialCompanyValue) {
      // Set the company selection
      this.companySelectTarget.value = this.initialCompanyValue
      
      // Trigger the company change logic
      this.toggleNewCompany()
      
      // If we have an initial team value, set it after teams are loaded
      if (this.hasInitialTeamValue && this.initialTeamValue) {
        // Store the initial team value to set after teams load
        this.pendingInitialTeamValue = this.initialTeamValue
      }
    }
  }

  setInitialTeamValue() {
    if (this.hasTeamSelectTarget && this.pendingInitialTeamValue) {
      // Check if the team exists in the dropdown
      const teamOption = Array.from(this.teamSelectTarget.options).find(option => 
        option.value === this.pendingInitialTeamValue
      )
      
      if (teamOption) {
        this.teamSelectTarget.value = this.pendingInitialTeamValue
        this.syncTeamName()
      }
      
      // Clear the pending value
      this.pendingInitialTeamValue = null
    }
  }

  toggleNewCompany() {
    const selectedValue = this.companySelectTarget.value
    
    if (selectedValue === 'new') {
      this.newCompanyFieldTarget.classList.remove('d-none')
      this.newCompanyInputTarget.focus()
      // Don't set required here - let server-side validation handle it
      
      // Enable team field for new company
      this.enableTeamField()
      this.setupTeamFieldForNewCompany()
    } else if (selectedValue === '') {
      // No company selected
      this.newCompanyFieldTarget.classList.add('d-none')
      this.newCompanyInputTarget.value = ''
      this.disableTeamField()
    } else {
      // Existing company selected
      this.newCompanyFieldTarget.classList.add('d-none')
      this.newCompanyInputTarget.value = ''
      this.enableTeamField()
      this.loadTeamsForCompany(selectedValue)
    }
  }

  toggleNewTeam() {
    const selectedValue = this.teamSelectTarget.value
    
    if (selectedValue === 'new') {
      this.newTeamFieldTarget.classList.remove('d-none')
      this.newTeamInputTarget.focus()
      // Don't set required here - let server-side validation handle it
    } else {
      this.newTeamFieldTarget.classList.add('d-none')
      this.newTeamInputTarget.value = ''
    }
    
    // Sync the selected value to the hidden team_name field
    this.syncTeamName()
  }

  updateNewTeamName() {
    const companySelection = this.companySelectTarget.value
    const teamSelection = this.teamSelectTarget.value
    
    // Update team name when creating new company OR when new team is selected
    if (companySelection === 'new' || teamSelection === 'new') {
      this.syncTeamName()
    }
  }

  enableTeamField() {
    if (this.hasTeamSelectTarget) {
      this.teamSelectTarget.disabled = false
      this.teamSelectTarget.classList.remove('text-muted')
    }
    if (this.hasTeamNameFieldTarget) {
      this.teamNameFieldTarget.disabled = false
      this.teamNameFieldTarget.classList.remove('text-muted')
    }
  }

  disableTeamField() {
    if (this.hasTeamSelectTarget) {
      this.teamSelectTarget.disabled = true
      this.teamSelectTarget.classList.add('text-muted')
      this.teamSelectTarget.innerHTML = '<option value="">Select company first</option>'
    }
    if (this.hasTeamNameFieldTarget) {
      this.teamNameFieldTarget.disabled = true
      this.teamNameFieldTarget.classList.add('text-muted')
      this.teamNameFieldTarget.value = ''
    }
    // Hide the new team field when no company is selected
    if (this.hasNewTeamFieldTarget) {
      this.newTeamFieldTarget.classList.add('d-none')
    }
  }

  setupTeamFieldForNewCompany() {
    if (this.hasTeamSelectTarget) {
      this.teamSelectTarget.innerHTML = '<option value="">Select a team...</option>'
      this.teamSelectTarget.disabled = true
      this.teamSelectTarget.classList.add('text-muted')
    }
    if (this.hasTeamNameFieldTarget) {
      this.teamNameFieldTarget.disabled = false
      this.teamNameFieldTarget.classList.remove('text-muted')
      this.teamNameFieldTarget.placeholder = 'e.g., Engineering Team'
    }
    // Show the new team field when creating a new company
    if (this.hasNewTeamFieldTarget) {
      this.newTeamFieldTarget.classList.remove('d-none')
    }
    if (this.hasNewTeamInputTarget) {
      this.newTeamInputTarget.focus()
      this.newTeamInputTarget.placeholder = 'e.g., Engineering Team'
    }
  }

  loadTeamsForCompany(companyName) {
    if (!this.hasTeamSelectTarget) return

    // Hide the new team field when loading existing teams
    if (this.hasNewTeamFieldTarget) {
      this.newTeamFieldTarget.classList.add('d-none')
    }

    // Use POST request to avoid URL encoding issues with special characters
    fetch('/api/companies/teams', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      },
      body: JSON.stringify({ company_name: companyName })
    })
      .then(response => response.json())
      .then(data => {
        this.teamSelectTarget.innerHTML = '<option value="">Select a team...</option>'
        
        data.teams.forEach(team => {
          const option = document.createElement('option')
          option.value = team.name
          option.textContent = team.name
          this.teamSelectTarget.appendChild(option)
        })
        
        // Add "New team" option
        const newTeamOption = document.createElement('option')
        newTeamOption.value = 'new'
        newTeamOption.textContent = '+ Create new team'
        this.teamSelectTarget.appendChild(newTeamOption)
        
        // Set initial team value if we have one pending
        this.setInitialTeamValue()
      })
      .catch(error => {
        console.error('Error loading teams:', error)
        this.teamSelectTarget.innerHTML = '<option value="">Error loading teams</option>'
      })
  }

  syncTeamName() {
    const selectedValue = this.teamSelectTarget.value
    const newTeamName = this.newTeamInputTarget.value
    const companySelection = this.companySelectTarget.value
    
    if (this.hasTeamNameFieldTarget) {
      // If creating a new company, always use the new team name
      if (companySelection === 'new') {
        this.teamNameFieldTarget.value = newTeamName
      } else if (selectedValue === 'new') {
        // If existing company but new team selected
        this.teamNameFieldTarget.value = newTeamName
      } else {
        // If existing company and existing team selected
        this.teamNameFieldTarget.value = selectedValue
      }
    }
  }
} 