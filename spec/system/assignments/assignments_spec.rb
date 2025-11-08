require 'rails_helper'

RSpec.describe 'Assignments', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true, can_manage_maap: true) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
    allow(person).to receive(:can_manage_maap?).and_return(true)
  end

  describe 'Assignment creation' do
    it 'loads new assignment form' do
      visit new_organization_assignment_path(organization)
      
      # Should see the form
      expect(page).to have_content('Create New Assignment')
      expect(page).to have_field('assignment_title')
      expect(page).to have_field('assignment_outcomes_textarea')
      expect(page).to have_field('assignment_tagline')
      expect(page).to have_field('assignment_required_activities')
      expect(page).to have_field('assignment_handbook')
      
      # Should see create button
      expect(page).to have_button('Create Assignment')
    end

    it 'creates assignment with valid data' do
      visit new_organization_assignment_path(organization)
      
      # Fill out the form
      fill_in 'assignment_title', with: 'Forward Progress Facilitator'
      fill_in 'assignment_tagline', with: 'Ensuring our team moves forward with clarity and momentum'
      fill_in 'assignment_outcomes_textarea', with: "Squad-mates agree \"We are deliberately learning so much... meaning, 3+ opinion-shifting and/or assumption-(in)validating learnings per quarter\".\n\nSquadmates agree: \"I am informed... meaning I know what is most important and what we are doing about it\""
      fill_in 'assignment_required_activities', with: "• Facilitate weekly team meetings\n• Track action items and follow-ups\n• Ensure clear communication channels"
      fill_in 'assignment_handbook', with: 'Focus on outcomes over activities. Listen actively and ask clarifying questions.'
      
      click_button 'Create Assignment'
      
      # Should redirect to show page
      expect(page).to have_content('Forward Progress Facilitator')
      expect(page).to have_content('Ensuring our team moves forward with clarity and momentum')
      
      # Verify in database
      assignment = Assignment.last
      expect(assignment.title).to eq('Forward Progress Facilitator')
      expect(assignment.tagline).to eq('Ensuring our team moves forward with clarity and momentum')
      expect(assignment.company.id).to eq(organization.id)
    end

    it 'shows validation errors for missing required fields' do
      visit new_organization_assignment_path(organization)
      
      # Try to submit empty form
      click_button 'Create Assignment'
      
      # Should stay on form (validation prevents submission)
      expect(page).to have_content('Create New Assignment')
    end
  end

  describe 'Assignment editing' do
    let!(:assignment) do
      create(:assignment,
        company: organization,
        title: 'Product Manager',
        tagline: 'Driving product strategy and execution',
        required_activities: '• Define product roadmap\n• Coordinate with engineering\n• Gather user feedback'
      )
    end

    it 'loads assignment show page' do
      visit organization_assignment_path(organization, assignment)
      
      # Should see assignment show page
      expect(page).to have_content('Product Manager')
      expect(page).to have_content('Driving product strategy and execution')
      expect(page).to have_content('Assignment Details')
      expect(page).to have_content('Company')
      expect(page).to have_content(organization.display_name)
      
      # Should see outcomes section
      expect(page).to have_content('Outcomes')
      expect(page).to have_content('No Outcomes Defined')
    end

    it 'loads edit form with pre-populated data' do
      visit edit_organization_assignment_path(organization, assignment)
      
      # Should see edit form
      expect(page).to have_content('Edit Assignment')
      expect(page).to have_field('assignment_title', with: 'Product Manager')
      expect(page).to have_field('assignment_tagline', with: 'Driving product strategy and execution')
      expect(page).to have_field('assignment_required_activities', with: '• Define product roadmap\n• Coordinate with engineering\n• Gather user feedback')
      
      # Should see update button
      expect(page).to have_button('Update Assignment')
    end

    it 'updates assignment with new data' do
      visit edit_organization_assignment_path(organization, assignment)
      
      # Should see edit form
      expect(page).to have_content('Edit Assignment')
      
      # Update the form
      fill_in 'assignment_title', with: 'Senior Product Manager'
      fill_in 'assignment_tagline', with: 'Leading product strategy and cross-functional execution'
      fill_in 'assignment_required_activities', with: '• Lead product roadmap planning\n• Drive cross-functional alignment\n• Mentor junior product managers'
      
      click_button 'Update Assignment'
      
      # Should redirect to show page
      expect(page).to have_content('Senior Product Manager')
      expect(page).to have_content('Leading product strategy and cross-functional execution')
      
      # Verify updates in database
      assignment.reload
      expect(assignment.title).to eq('Senior Product Manager')
      expect(assignment.tagline).to eq('Leading product strategy and cross-functional execution')
    end
  end

  describe 'Assignment outcomes management' do
    let!(:assignment) do
      create(:assignment,
        company: organization,
        title: 'Software Engineer',
        tagline: 'Building high-quality software solutions'
      )
    end

    it 'shows assignment without outcomes' do
      visit organization_assignment_path(organization, assignment)
      
      # Should see assignment details
      expect(page).to have_content('Software Engineer')
      expect(page).to have_content('Building high-quality software solutions')
      
      # Should see no outcomes warning
      expect(page).to have_content('No Outcomes Defined')
      expect(page).to have_content('Outcomes help clarify what success looks like for this assignment')
      expect(page).to have_link('Add Outcomes')
    end

    it 'allows adding outcomes through edit' do
      visit organization_assignment_path(organization, assignment)
      
      # Click add outcomes
      click_link 'Add Outcomes'
      
      # Should see edit form with outcomes section
      expect(page).to have_content('Edit Assignment')
      expect(page).to have_field('assignment_outcomes_textarea')
      expect(page).to have_content('Add NewOutcomes')
    end

    it 'creates assignment with outcomes' do
      visit new_organization_assignment_path(organization)
      
      # Fill out the form with outcomes
      fill_in 'assignment_title', with: 'Quality Assurance Engineer'
      fill_in 'assignment_tagline', with: 'Ensuring software quality and reliability'
      fill_in 'assignment_outcomes_textarea', with: "Team agrees: \"Our software is reliable... meaning, 99.9% uptime and zero critical bugs in production\"\n\nTeam agrees: \"We catch issues early... meaning, 90% of bugs are found before production deployment\""
      
      click_button 'Create Assignment'
      
      # Should redirect to show page
      expect(page).to have_content('Quality Assurance Engineer')
      
      # Should see outcomes
      expect(page).to have_content('Outcomes')
      expect(page).to have_content('Our software is reliable')
      expect(page).to have_content('We catch issues early')
    end
  end

  describe 'Assignment external references' do
    let!(:assignment) do
      create(:assignment,
        company: organization,
        title: 'Design Lead',
        tagline: 'Leading design strategy and execution'
      )
    end

    it 'shows assignment without external references' do
      visit organization_assignment_path(organization, assignment)
      
      # Should see assignment details
      expect(page).to have_content('Design Lead')
      expect(page).to have_content('Leading design strategy and execution')
      
      # Should not see external references section
      expect(page).not_to have_content('Source Documents')
    end

    it 'allows adding external references through edit' do
      visit edit_organization_assignment_path(organization, assignment)
      
      # Should see external reference fields
      expect(page).to have_field('assignment_published_source_url')
      expect(page).to have_field('assignment_draft_source_url')
      
      # Fill in external references
      fill_in 'assignment_published_source_url', with: 'https://docs.google.com/document/d/published123'
      fill_in 'assignment_draft_source_url', with: 'https://docs.google.com/document/d/draft123'
      
      click_button 'Update Assignment'
      
      # Should redirect to show page
      expect(page).to have_content('Design Lead')
      
      # Should see external references
      expect(page).to have_content('Source Documents')
      expect(page).to have_link('Published Version')
      expect(page).to have_link('Draft Version')
    end
  end

  describe 'Navigation and UI elements' do
    it 'navigates between assignment pages' do
      # Start at assignments index
      visit organization_assignments_path(organization)
      
      # Should see assignments index
      expect(page).to have_content('Assignments')
      
      # Navigate to new assignment (plus button)
      find('a.btn.btn-primary i.bi-plus').click
      expect(page).to have_content('Create New Assignment')
      
      # Navigate back to index
      click_link 'Back to Assignments'
      expect(page).to have_content('Assignments')
    end

    it 'shows assignment in index after creation' do
      assignment = create(:assignment, 
        company: organization, 
        title: 'Marketing Specialist',
        tagline: 'Driving marketing campaigns and brand awareness'
      )
      
      visit organization_assignments_path(organization)
      
      # Should see the assignment
      expect(page).to have_content('Marketing Specialist')
      expect(page).to have_content('Driving marketing campaigns and brand awareness')
      expect(page).to have_content(organization.display_name)
    end

    it 'shows empty state when no assignments exist' do
      visit organization_assignments_path(organization)
      
      # Should see empty state
      expect(page).to have_content('No Assignments Created')
      expect(page).to have_content('Create your first assignment to define clear roles and responsibilities for your team')
      expect(page).to have_link('Create First Assignment')
    end
  end
end
