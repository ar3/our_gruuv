import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String }
  
  insertTemplate(event) {
    event.preventDefault()
    
    const template = `1. Your intent with this feedback / story
--Are you expecting a response, a change, or do you just want those in the story to know your perspective--

2. Situation / Context
--What was happening--

3. Observation 
--Just the facts about what happened / observable behaviors / no editorializing or judgements here, just the facts--

4. Feelings / Impact
--Use the feeling dropdowns below--

5. Unmet needs
--Your unmet needs, or if this is a celebratory story, needs that were exceeded--

6. Request
--This goes back to the intent... if you have a specific request for the future, put them here... this is where a conversation will have to happen to see if those in your story agree to the requests--
`
    
    const textarea = document.getElementById(this.targetValue)
    if (textarea) {
      // Append to existing text or insert if empty
      const currentText = textarea.value.trim()
      textarea.value = currentText ? currentText + "\n\n" + template : template
      
      // Show toast notification
      this.showToast("MAAP framework template inserted")
    }
  }
  
  showToast(message) {
    // Use your existing toast system if available
    // For now, just log to console
    console.log(message)
  }
}

