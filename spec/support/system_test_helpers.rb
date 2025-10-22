module SystemTestHelpers
  # Sign in helper that ensures clean state
  def sign_in_as(person, organization)
    # Ensure person has current organization set
    person.update!(current_organization: organization)
    
    # Set session using rack_session_access
    page.set_rack_session(current_person_id: person.id)
    
    # Verify session is set
    expect(page.get_rack_session['current_person_id']).to eq(person.id)
  end
  
  # Navigate helper that waits for page load
  def visit_and_wait(path)
    visit(path)
    expect(page).to have_current_path(path, wait: 5)
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end


