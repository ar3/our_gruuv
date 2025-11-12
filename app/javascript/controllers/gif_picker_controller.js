import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "results", "selectedGifs"]
  static values = { organizationId: String }

  connect() {
    // Initialize selected GIFs display
    this.updateSelectedGifsDisplay()
  }

  async search(event) {
    // Handle Enter key or button click
    if (event.type === 'keydown' && event.key !== 'Enter') {
      return
    }
    
    if (event.type === 'keydown') {
      event.preventDefault()
    }
    
    const query = this.searchInputTarget.value.trim()
    
    if (!query) {
      this.resultsTarget.innerHTML = '<div class="alert alert-warning">Please enter a search term</div>'
      return
    }

    this.resultsTarget.innerHTML = '<div class="text-muted">Searching...</div>'

    try {
      const url = `/organizations/${this.organizationIdValue}/gifs/search?q=${encodeURIComponent(query)}&limit=25`
      
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        throw new Error('Search failed')
      }

      const data = await response.json()
      this.displayResults(data.gifs || [])
    } catch (error) {
      this.resultsTarget.innerHTML = `<div class="alert alert-danger">Error searching GIFs: ${error.message}</div>`
    }
  }

  displayResults(gifs) {
    if (gifs.length === 0) {
      this.resultsTarget.innerHTML = '<div class="alert alert-info">No GIFs found. Try a different search term.</div>'
      return
    }

    const html = gifs.map(gif => `
      <div class="gif-result mb-2" style="display: inline-block; margin-right: 10px; cursor: pointer;">
        <img src="${gif.preview_url}" 
             alt="${gif.title || 'GIF'}" 
             data-gif-url="${gif.url}"
             class="img-thumbnail"
             style="width: 150px; height: 150px; object-fit: cover;"
             data-action="click->gif-picker#selectGif" />
      </div>
    `).join('')

    this.resultsTarget.innerHTML = `<div class="gif-grid">${html}</div>`
  }

  selectGif(event) {
    const gifUrl = event.currentTarget.dataset.gifUrl
    
    // Check if already selected
    if (this.isGifSelected(gifUrl)) {
      return
    }
    
    this.addGifToForm(gifUrl)
    
    // Visual feedback
    event.currentTarget.style.border = '3px solid #0d6efd'
    setTimeout(() => {
      event.currentTarget.style.border = ''
    }, 500)
  }

  removeGif(event) {
    const gifUrl = event.currentTarget.dataset.gifUrl
    this.removeGifFromForm(gifUrl)
  }

  addGifToForm(gifUrl) {
    // Find or create the hidden input container for selected GIFs
    let container = document.getElementById('selected_gifs_container')
    if (!container) {
      container = document.createElement('div')
      container.id = 'selected_gifs_container'
      container.style.display = 'none'
      const form = document.getElementById('observation_form')
      if (form) {
        form.appendChild(container)
      }
    }

    // Check if this GIF is already in the form (from existing data)
    const existingInputs = container.querySelectorAll(`input[value="${gifUrl}"]`)
    if (existingInputs.length > 0) {
      return // Already exists
    }

    // Create a hidden input for this GIF URL
    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = 'observation[story_extras][gif_urls][]'
    input.value = gifUrl
    input.dataset.gifUrl = gifUrl
    container.appendChild(input)

    // Update the visual display
    this.updateSelectedGifsDisplay()
  }

  removeGifFromForm(gifUrl) {
    // Remove from hidden inputs in container (newly added)
    const container = document.getElementById('selected_gifs_container')
    if (container) {
      const inputs = container.querySelectorAll(`input[data-gif-url="${gifUrl}"], input[value="${gifUrl}"]`)
      inputs.forEach(input => input.remove())
    }

    // Remove from existing GIF inputs in the form (from server)
    const existingInputs = document.querySelectorAll(`.existing-gif-input[data-gif-url="${gifUrl}"], .existing-gif-input[value="${gifUrl}"]`)
    existingInputs.forEach(input => input.remove())

    // Update the visual display
    this.updateSelectedGifsDisplay()
  }

  isGifSelected(gifUrl) {
    // Check hidden inputs in container
    const container = document.getElementById('selected_gifs_container')
    if (container) {
      const existingInputs = container.querySelectorAll(`input[value="${gifUrl}"]`)
      if (existingInputs.length > 0) return true
    }
    
    // Check existing GIF inputs in the form
    const existingInputs = document.querySelectorAll(`.existing-gif-input[data-gif-url="${gifUrl}"], .existing-gif-input[value="${gifUrl}"]`)
    return existingInputs.length > 0
  }

  updateSelectedGifsDisplay() {
    const container = document.getElementById('selected_gifs_container')
    const selectedGifsContainer = document.getElementById('selected_gifs_visual')
    
    if (!selectedGifsContainer) return

    // Get all selected GIF URLs (from both hidden inputs in container and existing inputs in form)
    const selectedUrls = new Set()
    
    // From hidden inputs in the container (newly added)
    if (container) {
      container.querySelectorAll('input[type="hidden"][name*="gif_urls"]').forEach(input => {
        if (input.value) {
          selectedUrls.add(input.value)
        }
      })
    }
    
    // From existing GIF inputs in the form (from server)
    document.querySelectorAll('.existing-gif-input[data-gif-url]').forEach(input => {
      const url = input.dataset.gifUrl || input.value
      if (url) {
        selectedUrls.add(url)
      }
    })

    const gifUrls = Array.from(selectedUrls)
    
    if (gifUrls.length === 0) {
      selectedGifsContainer.innerHTML = '<div class="text-muted small">No GIFs selected</div>'
      return
    }

    // Display selected GIFs with remove buttons
    const html = `
      <div class="mb-2">
        <strong class="small">Selected GIFs (${gifUrls.length}):</strong>
      </div>
      <div class="d-flex flex-wrap gap-2">
        ${gifUrls.map(url => `
          <div class="position-relative" style="display: inline-block;">
            <img src="${url}" 
                 alt="Selected GIF" 
                 class="img-thumbnail"
                 style="width: 100px; height: 100px; object-fit: cover;" />
            <button type="button" 
                    class="btn btn-sm btn-danger position-absolute top-0 end-0" 
                    style="padding: 2px 6px; font-size: 10px;"
                    data-action="click->gif-picker#removeGif"
                    data-gif-url="${url}">
              <i class="bi bi-x"></i>
            </button>
          </div>
        `).join('')}
      </div>
    `
    
    selectedGifsContainer.innerHTML = html
  }
}

