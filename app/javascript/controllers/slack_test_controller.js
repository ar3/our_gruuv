import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messageInput"]
  static values = { organizationId: String }



  testConnection(event) {
    const button = event.currentTarget
    const resultDiv = document.getElementById('connectionResult')
    
    const orgId = this.organizationId || this.element.dataset.slackTestOrganizationIdValue
    
    this.setButtonLoading(button, 'Testing...', 'bi-wifi')
    
    fetch(`/organizations/${orgId}/slack/test_connection`)
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          resultDiv.innerHTML = '<div class="alert alert-success"><i class="bi bi-check-circle me-2"></i>Connection successful!</div>'
        } else {
          resultDiv.innerHTML = '<div class="alert alert-danger"><i class="bi bi-x-circle me-2"></i>' + (data.error || 'Connection failed') + '</div>'
        }
      })
      .catch(error => {
        resultDiv.innerHTML = '<div class="alert alert-danger"><i class="bi bi-x-circle me-2"></i>Error: ' + error.message + '</div>'
      })
      .finally(() => {
        this.resetButton(button, 'Test Connection', 'bi-wifi')
      })
  }

  listChannels(event) {
    const button = event.currentTarget
    const resultDiv = document.getElementById('channelsResult')
    
    const orgId = this.organizationId || this.element.dataset.slackTestOrganizationIdValue
    
    this.setButtonLoading(button, 'Loading...', 'bi-list')
    
    fetch(`/organizations/${orgId}/slack/list_channels`)
      .then(response => response.json())
      .then(data => {
        if (data.success && data.channels) {
          const channelList = data.channels.map(channel => 
            `<li>#${channel.name} ${channel.is_private ? '<span class="badge bg-secondary">Private</span>' : ''}</li>`
          ).join('')
          resultDiv.innerHTML = '<div class="alert alert-info"><strong>Channels:</strong><ul class="mb-0 mt-2">' + channelList + '</ul></div>'
        } else {
          resultDiv.innerHTML = '<div class="alert alert-danger"><i class="bi bi-x-circle me-2"></i>' + (data.error || 'Failed to load channels') + '</div>'
        }
      })
      .catch(error => {
        resultDiv.innerHTML = '<div class="alert alert-danger"><i class="bi bi-x-circle me-2"></i>Error: ' + error.message + '</div>'
      })
      .finally(() => {
        this.resetButton(button, 'List Channels', 'bi-list')
      })
  }

  sendTestMessage(event) {
    const button = event.currentTarget
    const messageInput = this.messageInputTarget
    const resultDiv = document.getElementById('messageResult')
    const message = messageInput.value
    
    if (!message.trim()) {
      resultDiv.innerHTML = '<div class="alert alert-warning"><i class="bi bi-exclamation-triangle me-2"></i>Please enter a message</div>'
      return
    }
    
    const orgId = this.organizationId || this.element.dataset.slackTestOrganizationIdValue
    
    this.setButtonLoading(button, 'Sending...', 'bi-send')
    
    fetch(`/organizations/${orgId}/slack/post_test_message`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({ message: message })
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          resultDiv.innerHTML = '<div class="alert alert-success"><i class="bi bi-check-circle me-2"></i>Message sent successfully!</div>'
        } else {
          resultDiv.innerHTML = '<div class="alert alert-danger"><i class="bi bi-x-circle me-2"></i>' + (data.error || 'Failed to send message') + '</div>'
        }
      })
      .catch(error => {
        resultDiv.innerHTML = '<div class="alert alert-danger"><i class="bi bi-x-circle me-2"></i>Error: ' + error.message + '</div>'
      })
      .finally(() => {
        this.resetButton(button, 'Send', 'bi-send')
      })
  }

  setButtonLoading(button, text, iconClass) {
    button.disabled = true
    button.innerHTML = `<i class="bi bi-hourglass-split me-1"></i>${text}`
  }

  resetButton(button, text, iconClass) {
    button.disabled = false
    button.innerHTML = `<i class="bi ${iconClass} me-1"></i>${text}`
  }
} 