// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

// Debug what's available in bootstrap
console.log('Bootstrap object:', bootstrap)
console.log('Available keys:', Object.keys(bootstrap))

// Initialize Bootstrap tooltips
function initializeTooltips() {
  console.log('Initializing tooltips...')
  const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]')
  console.log('Found tooltip elements:', tooltipTriggerList.length)
  
  // Try different ways to access Tooltip
  if (bootstrap.Tooltip) {
    console.log('Found bootstrap.Tooltip')
    const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl))
    console.log('Initialized tooltips:', tooltipList.length)
  } else if (window.bootstrap && window.bootstrap.Tooltip) {
    console.log('Found window.bootstrap.Tooltip')
    const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new window.bootstrap.Tooltip(tooltipTriggerEl))
    console.log('Initialized tooltips:', tooltipList.length)
  } else {
    console.log('Tooltip not found in bootstrap object')
  }
}

// Initialize Bootstrap toasts
function initializeToasts() {
  console.log('Initializing toasts...')
  const toastElList = document.querySelectorAll('.toast')
  console.log('Found toast elements:', toastElList.length)
  
  if (bootstrap.Toast) {
    console.log('Found bootstrap.Toast')
    const toastList = [...toastElList].map(toastEl => {
      const toast = new bootstrap.Toast(toastEl, {
        autohide: true,
        delay: 5000
      })
      toast.show() // Show the toast immediately
      return toast
    })
    console.log('Initialized toasts:', toastList.length)
  } else if (window.bootstrap && window.bootstrap.Toast) {
    console.log('Found window.bootstrap.Toast')
    const toastList = [...toastElList].map(toastEl => {
      const toast = new window.bootstrap.Toast(toastEl, {
        autohide: true,
        delay: 5000
      })
      toast.show() // Show the toast immediately
      return toast
    })
    console.log('Initialized toasts:', toastList.length)
  } else {
    console.log('Toast not found in bootstrap object')
  }
}

// Initialize share huddle functionality
function initializeShareHuddle() {
  console.log('Initializing share huddle functionality...')
  const shareButtons = document.querySelectorAll('.share-huddle-btn')
  console.log('Found share buttons:', shareButtons.length)
  
  shareButtons.forEach(button => {
    button.addEventListener('click', async (e) => {
      e.preventDefault()
      e.stopPropagation()
      
      const joinUrl = button.dataset.joinUrl
      console.log('Copying URL to clipboard:', joinUrl)
      
      try {
        await navigator.clipboard.writeText(joinUrl)
        console.log('URL copied to clipboard successfully')
        
        // Show success feedback
        const originalIcon = button.innerHTML
        button.innerHTML = '<i class="bi bi-check"></i>'
        button.classList.remove('text-muted')
        button.classList.add('text-success')
        
        // Reset after 2 seconds
        setTimeout(() => {
          button.innerHTML = '<i class="bi bi-link-45deg"></i>'
          button.classList.remove('text-success')
          button.classList.add('text-muted')
        }, 2000)
        
        // Show toast notification
        showToast('Huddle link copied to clipboard!', 'success')
      } catch (err) {
        console.error('Failed to copy URL to clipboard:', err)
        
        // Fallback for older browsers
        const textArea = document.createElement('textarea')
        textArea.value = joinUrl
        document.body.appendChild(textArea)
        textArea.select()
        document.execCommand('copy')
        document.body.removeChild(textArea)
        
        // Show success feedback
        const originalIcon = button.innerHTML
        button.innerHTML = '<i class="bi bi-check"></i>'
        button.classList.remove('text-muted')
        button.classList.add('text-success')
        
        setTimeout(() => {
          button.innerHTML = '<i class="bi bi-link-45deg"></i>'
          button.classList.remove('text-success')
          button.classList.add('text-muted')
        }, 2000)
        
        showToast('Huddle link copied to clipboard!', 'success')
      }
    })
  })
}

// Show toast notification
function showToast(message, type = 'info') {
  const toastContainer = document.getElementById('toast-container') || createToastContainer()
  
  const toastHtml = `
    <div class="toast" role="alert" aria-live="assertive" aria-atomic="true">
      <div class="toast-header">
        <strong class="me-auto">${type === 'success' ? 'Success' : 'Info'}</strong>
        <button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>
      </div>
      <div class="toast-body">
        ${message}
      </div>
    </div>
  `
  
  toastContainer.insertAdjacentHTML('beforeend', toastHtml)
  
  const toastElement = toastContainer.lastElementChild
  const toast = new bootstrap.Toast(toastElement, {
    autohide: true,
    delay: 3000
  })
  toast.show()
  
  // Remove toast element after it's hidden
  toastElement.addEventListener('hidden.bs.toast', () => {
    toastElement.remove()
  })
}

// Create toast container if it doesn't exist
function createToastContainer() {
  const container = document.createElement('div')
  container.id = 'toast-container'
  container.className = 'toast-container position-fixed top-0 end-0 p-3'
  container.style.zIndex = '1055'
  document.body.appendChild(container)
  return container
}

// Try multiple events to ensure tooltips and toasts are initialized
document.addEventListener('turbo:load', () => {
  initializeTooltips()
  initializeToasts()
  initializeShareHuddle()
})
document.addEventListener('DOMContentLoaded', () => {
  initializeTooltips()
  initializeToasts()
  initializeShareHuddle()
})
