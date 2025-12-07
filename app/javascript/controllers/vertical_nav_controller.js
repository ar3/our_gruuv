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
    // Read locked state (can be string 'true'/'false' or boolean)
    const lockedValue = this.navTarget.dataset.locked
    this.locked = lockedValue === 'true' || lockedValue === true
    
    // If locked, nav must be open. Otherwise read from data attribute
    const openValue = this.navTarget.dataset.open
    this.open = this.locked ? true : (openValue === 'true' || openValue === true)
    
    // Ensure locked nav is always open
    if (this.locked) {
      this.open = true
    }
    
    // Apply initial state
    this.updateNavState()
    
    // Ensure floating toggle button is visible on mobile when nav is closed
    const floatingToggle = document.querySelector('.floating-toggle')
    if (floatingToggle && !this.open) {
      // On mobile, ensure button is visible
      if (window.innerWidth <= 991.98) {
        floatingToggle.style.display = 'flex'
        floatingToggle.style.visibility = 'visible'
        floatingToggle.style.opacity = '1'
        floatingToggle.classList.remove('d-none', 'nav-open-hidden')
      }
    }
    
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
  
  // Lock/unlock is now handled via form POST for reliability
  // This method is kept for backwards compatibility but shouldn't be called
  toggleLock() {
    // Lock/unlock is now handled via form POST - redirect to form action
    const lockBtn = document.querySelector('.vertical-nav-lock-btn')
    if (lockBtn && lockBtn.closest('form')) {
      lockBtn.closest('form').submit()
    }
  }
  
  updateNavState() {
    // If locked, nav must always be open
    if (this.locked) {
      this.open = true
    }
    
    if (this.open) {
      this.navTarget.classList.add('open')
      this.navTarget.classList.remove('closed')
      if (this.hasBackdrop) {
        this.backdropElement.classList.add('show')
      }
    } else {
      // Only allow closing if not locked
      if (!this.locked) {
        this.navTarget.classList.remove('open')
        this.navTarget.classList.add('closed')
        if (this.hasBackdrop) {
          this.backdropElement.classList.remove('show')
        }
      }
    }
    
    if (this.locked) {
      this.navTarget.classList.add('locked')
      // Ensure open class is present when locked
      this.navTarget.classList.add('open')
      this.navTarget.classList.remove('closed')
      if (this.hasBackdrop) {
        this.backdropElement.classList.add('show')
      }
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
        floatingToggle.classList.add('d-none', 'nav-open-hidden')
        floatingToggle.style.display = 'none'
        floatingToggle.style.visibility = 'hidden'
      } else {
        floatingToggle.classList.remove('d-none', 'nav-open-hidden')
        // Always ensure it's visible when nav is closed
        floatingToggle.style.display = 'flex'
        floatingToggle.style.visibility = 'visible'
        floatingToggle.style.opacity = '1'
      }
    }
    
    // Update top bar spacer visibility
    const spacer = document.querySelector('.vertical-nav-toggle-spacer')
    if (spacer) {
      if (this.open) {
        spacer.style.width = '0'
      } else {
        spacer.style.width = '68px'
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

