import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["result"]

  async testGiphy(event) {
    const button = event.currentTarget
    const resultTarget = this.hasResultTarget ? this.resultTarget : document.getElementById('giphyResult')
    
    this.setButtonLoading(button, 'Testing...', 'bi-search')
    
    if (resultTarget) {
      resultTarget.innerHTML = '<div class="alert alert-info">Testing GIPHY connection...</div>'
    }

    try {
      const response = await fetch('/healthcheck/test_giphy', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (resultTarget) {
        if (data.success) {
          resultTarget.innerHTML = `
            <div class="alert alert-success">
              <i class="bi bi-check-circle me-2"></i>
              <strong>Success!</strong> ${data.message}
            </div>
          `
        } else {
          resultTarget.innerHTML = `
            <div class="alert alert-danger">
              <i class="bi bi-exclamation-triangle me-2"></i>
              <strong>Error:</strong> ${data.error}
            </div>
          `
        }
      }
    } catch (error) {
      if (resultTarget) {
        resultTarget.innerHTML = `
          <div class="alert alert-danger">
            <i class="bi bi-exclamation-triangle me-2"></i>
            <strong>Error:</strong> ${error.message}
          </div>
        `
      }
    } finally {
      this.resetButton(button, 'Test Connection', 'bi-search')
    }
  }

  setButtonLoading(button, text, iconClass) {
    button.disabled = true
    button.innerHTML = `
      <span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
      ${text}
    `
  }

  resetButton(button, text, iconClass) {
    button.disabled = false
    button.innerHTML = `
      <i class="bi ${iconClass} me-2"></i>
      ${text}
    `
  }
}

