import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    open: Boolean,
    locked: Boolean
  }
  
  static targets = ["nav", "toggleBtn", "lockBtn", "closeBtn"]
  
  get backdropElement() {
    return document.querySelector('.vertical-nav-backdrop')
  }
  
  get hasBackdrop() {
    return this.backdropElement !== null
  }
  
  connect() {
    // Restore state from data attributes
    this.open = this.navTarget.dataset.open === 'true'
    this.locked = this.navTarget.dataset.locked === 'true'
    
    // Apply initial state
    this.updateNavState()
    
    // Handle escape key
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.boundHandleEscape)
    
    // Handle backdrop clicks (mobile) - use event delegation since backdrop might not exist initially
    document.addEventListener('click', (e) => {
      if (e.target.classList.contains('vertical-nav-backdrop') && !this.locked) {
        this.close()
      }
    })
    
    // Handle custom toggle event from floating button
    this.boundHandleToggleEvent = this.handleToggleEvent.bind(this)
    document.addEventListener('vertical-nav:toggle', this.boundHandleToggleEvent)
    
    // Handle clicks on floating toggle button
    document.addEventListener('click', (e) => {
      if (e.target.closest('.floating-toggle')) {
        this.toggle()
      }
    })
  }
  
  disconnect() {
    document.removeEventListener('keydown', this.boundHandleEscape)
    if (this.boundHandleToggleEvent) {
      document.removeEventListener('vertical-nav:toggle', this.boundHandleToggleEvent)
    }
  }
  
  handleToggleEvent() {
    this.toggle()
  }
  
  toggle() {
    if (this.locked) {
      return
    }
    
    if (this.open) {
      this.close()
    } else {
      this.openNav()
    }
  }
  
  openNav() {
    this.open = true
    this.updateNavState()
    this.saveState()
  }
  
  close() {
    if (this.locked) {
      return
    }
    
    this.open = false
    this.updateNavState()
    this.saveState()
  }
  
  toggleLock() {
    this.locked = !this.locked
    
    // If locking, ensure nav is open
    if (this.locked && !this.open) {
      this.open = true
    }
    
    this.updateNavState()
    this.saveState()
  }
  
  updateNavState() {
    if (this.open) {
      this.navTarget.classList.add('open')
      this.navTarget.classList.remove('closed')
      if (this.hasBackdrop) {
        this.backdropElement.classList.add('show')
      }
    } else {
      this.navTarget.classList.remove('open')
      this.navTarget.classList.add('closed')
      if (this.hasBackdrop) {
        this.backdropElement.classList.remove('show')
      }
    }
    
    if (this.locked) {
      this.navTarget.classList.add('locked')
      if (this.hasLockBtnTarget) {
        const icon = this.lockBtnTarget.querySelector('i')
        if (icon) {
          icon.classList.remove('bi-pin')
          icon.classList.add('bi-pin-fill')
        }
      }
    } else {
      this.navTarget.classList.remove('locked')
      if (this.hasLockBtnTarget) {
        const icon = this.lockBtnTarget.querySelector('i')
        if (icon) {
          icon.classList.remove('bi-pin-fill')
          icon.classList.add('bi-pin')
        }
      }
    }
    
    // Update main content container
    const mainContent = document.querySelector('.main-content-container')
    if (mainContent) {
      if (this.open) {
        mainContent.classList.add('nav-open')
      } else {
        mainContent.classList.remove('nav-open')
      }
    }
    
    // Show/hide floating toggle button
    const floatingToggle = document.querySelector('.floating-toggle')
    if (floatingToggle) {
      if (this.open) {
        floatingToggle.classList.add('d-none')
      } else {
        floatingToggle.classList.remove('d-none')
      }
    }
  }
  
  saveState() {
    // Debounce state persistence
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
    
    this.saveTimeout = setTimeout(() => {
      this.persistState()
    }, 300)
  }
  
  async persistState() {
    const url = '/user_preferences/vertical_nav'
    const formData = new FormData()
    formData.append('open', this.open)
    formData.append('locked', this.locked)
    
    try {
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: formData
      })
      
      if (!response.ok) {
        console.error('Failed to save vertical nav state')
      }
    } catch (error) {
      console.error('Error saving vertical nav state:', error)
    }
  }
  
  handleEscape(event) {
    if (event.key === 'Escape' && this.open && !this.locked) {
      this.close()
    }
  }
}

