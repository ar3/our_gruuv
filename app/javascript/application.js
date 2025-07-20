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

// Try multiple events to ensure tooltips and toasts are initialized
document.addEventListener('turbo:load', () => {
  initializeTooltips()
  initializeToasts()
})
document.addEventListener('DOMContentLoaded', () => {
  initializeTooltips()
  initializeToasts()
})
