import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["phoneNumber"]

  connect() {
    // Controller is ready
  }

  testNotification(event) {
    const button = event.currentTarget
    const resultDiv = document.getElementById('notificationApiResult')
    const phoneNumber = this.phoneNumberTarget.value.trim()
    
    if (!phoneNumber) {
      resultDiv.innerHTML = `
        <div class="alert alert-warning">
          <i class="bi bi-exclamation-triangle me-2"></i>
          <strong>Please enter a phone number</strong>
        </div>
      `
      return
    }
    
    this.setButtonLoading(button, 'Sending...', 'bi-send')
    resultDiv.innerHTML = ''
    
    fetch('/healthcheck/test_notification_api', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ phone_number: phoneNumber })
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          resultDiv.innerHTML = `
            <div class="alert alert-success">
              <i class="bi bi-check-circle me-2"></i>
              <strong>Success!</strong> ${data.message || 'Test notification sent successfully!'}
            </div>
          `
          // Show toast notification
          if (typeof showToast === 'function') {
            showToast(data.message || 'Test notification sent successfully!', 'success')
          }
        } else {
          let errorHtml = `
            <div class="alert alert-danger">
              <i class="bi bi-x-circle me-2"></i>
              <strong>Error from NotificationAPI:</strong>
              <pre class="mt-2 mb-0 small" style="white-space: pre-wrap;">${data.error || 'Unknown error occurred'}</pre>
              ${data.note ? `<div class="mt-2 p-2 bg-warning bg-opacity-10 border-start border-warning border-3"><small><strong>Note:</strong> ${data.note}</small></div>` : ''}
            </div>
          `
          
          // Show full error details if available
          if (data.status || data.headers || data.full_response) {
            errorHtml += `
              <div class="mt-3">
                <details>
                  <summary class="btn btn-sm btn-outline-danger">Show Full Error Details</summary>
                  <div class="mt-2 p-3 bg-light border rounded">
                    <pre class="small mb-2" style="white-space: pre-wrap; word-wrap: break-word;">${JSON.stringify(data.full_response || data, null, 2)}</pre>
                    ${data.status ? `<p class="mb-1"><strong>HTTP Status:</strong> ${data.status}</p>` : ''}
                    ${data.headers ? `<p class="mb-1"><strong>Response Headers:</strong></p><pre class="small">${JSON.stringify(data.headers, null, 2)}</pre>` : ''}
                    ${data.backtrace ? `<p class="mb-1"><strong>Backtrace:</strong></p><pre class="small">${data.backtrace.join('\n')}</pre>` : ''}
                  </div>
                </details>
              </div>
            `
          }
          
          resultDiv.innerHTML = errorHtml
        }
      })
      .catch(error => {
        resultDiv.innerHTML = `
          <div class="alert alert-danger">
            <i class="bi bi-x-circle me-2"></i>
            <strong>Error:</strong> ${error.message}
          </div>
        `
      })
      .finally(() => {
        this.resetButton(button, 'Send Test Message', 'bi-send')
      })
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

