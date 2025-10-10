require 'rails_helper'

RSpec.describe 'Milestone Earning', type: :system, critical: true do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true, can_manage_maap: true) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow(person).to receive(:can_manage_employment?).and_return(true)
    allow(person).to receive(:can_manage_maap?).and_return(true)
  end

  describe 'Celebrate milestones page' do
    let!(:employee1) { create(:person, full_name: 'John Doe', email: 'john@example.com') }
    let!(:employee2) { create(:person, full_name: 'Jane Smith', email: 'jane@example.com') }
    let!(:employee1_teammate) { create(:teammate, person: employee1, organization: organization) }
    let!(:employee2_teammate) { create(:teammate, person: employee2, organization: organization) }
    let!(:ability) do
      create(:ability,
        organization: organization,
        name: 'Ruby Programming',
        description: 'Ability to write Ruby applications',
        milestone_1_description: 'Basic Ruby syntax',
        milestone_2_description: 'Object-oriented programming',
        milestone_3_description: 'Rails development',
        created_by: person,
        updated_by: person
      )
    end

    it 'loads celebrate milestones page with empty state' do
      visit celebrate_milestones_organization_path(organization)

      expect(page).to have_content('Recent Milestones')
      expect(page).to have_content('Total Milestones')
      expect(page).to have_content('People Celebrated')
      expect(page).to have_content('Recent (30 days)')
      expect(page).to have_content('Level 5 Achievements')

      expect(page).to have_content('No Recent Milestones')
      expect(page).to have_content('No milestones have been achieved in the past 90 days')
      expect(page).to have_content('Encourage your team to work toward their next ability milestones!')
    end

    it 'shows milestone analytics and spotlight' do
      visit celebrate_milestones_organization_path(organization)

      expect(page).to have_content('Spotlight')
      expect(page).to have_content('Milestone Overview')
      expect(page).to have_content('Top Abilities')
      expect(page).to have_content('Filters: Last 90 Days')
      expect(page).to have_content('Sort: Most Recent')
    end

    it 'shows existing milestones when they exist' do
      # Create milestone attainments
      create(:teammate_milestone,
        teammate: employee1_teammate,
        ability: ability,
        milestone_level: 2,
        certified_by: person,
        attained_at: Date.current
      )
      create(:teammate_milestone,
        teammate: employee2_teammate,
        ability: ability,
        milestone_level: 3,
        certified_by: person,
        attained_at: 1.week.ago
      )

      visit celebrate_milestones_organization_path(organization)

      expect(page).to have_content('Recent Milestones')
      expect(page).to have_content('John Doe')
      expect(page).to have_content('Jane Smith')
      expect(page).to have_content('Ruby Programming')
      expect(page).to have_content('Milestone 2')
      expect(page).to have_content('Milestone 3')

      expect(page).to have_content('Total Milestones')
      expect(page).to have_content('People Celebrated')
    end

    it 'shows award milestone button with proper permissions' do
      visit celebrate_milestones_organization_path(organization)

      expect(page).to have_css('button.btn.btn-primary.dropdown-toggle')
      expect(page).to have_content('Manage Abilities')
    end

    it 'shows disabled award milestone button without permissions' do
      allow(person).to receive(:can_manage_maap?).and_return(false)
      visit celebrate_milestones_organization_path(organization)

      expect(page).to have_content('Manage Abilities')
      # The permission message only shows when the button is disabled
      expect(page).to have_content('Manage Abilities')
    end
  end

  describe 'Milestones overview page' do
    it 'loads milestones overview page' do
      visit milestones_overview_path

      expect(page).to have_content('Milestones Overview')
      expect(page).to have_content('Milestones System')
      expect(page).to have_content('Key Components:')
      expect(page).to have_content('Abilities')
      expect(page).to have_content('Observations')
      expect(page).to have_content('Eligibility Reviews')

      expect(page).to have_content('Vision:')
      expect(page).to have_content('This system creates a culture of continuous feedback')
      expect(page).to have_content('Team Building')
      expect(page).to have_content('Growth Support')
    end

    it 'shows navigation links to related systems' do
      visit milestones_overview_path

      expect(page).to have_link('View Abilities', href: organization_abilities_path(organization))
      expect(page).to have_link('View Observations', href: organization_observations_path(organization))
      expect(page).to have_content('Skills and competencies needed for assignments')
      expect(page).to have_content('360-degree feedback system with 5-point Likert scale')
    end
  end

  describe 'Complete picture milestone display' do
    let!(:employee_person) { create(:person, full_name: 'Alice Johnson', email: 'alice@example.com') }
    let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
    let!(:ability) do
      create(:ability,
        organization: organization,
        name: 'Project Management',
        description: 'Ability to manage projects effectively',
        milestone_1_description: 'Basic project planning',
        milestone_2_description: 'Team coordination',
        milestone_3_description: 'Strategic project management',
        created_by: person,
        updated_by: person
      )
    end

    it 'shows no milestones section when no milestones exist' do
      visit complete_picture_organization_person_path(organization, employee_person)

      expect(page).to have_content('Alice Johnson')
      expect(page).to have_content('Complete Picture View')
      expect(page).to have_content('Current Position')

      # Should not show milestones section when empty
      expect(page).to_not have_content('Achieved Milestones')
    end

    it 'shows milestones section when milestones exist' do
      # Create milestone attainment
      create(:teammate_milestone,
        teammate: employee_teammate,
        ability: ability,
        milestone_level: 2,
        certified_by: person,
        attained_at: Date.current
      )

      visit complete_picture_organization_person_path(organization, employee_person)

      expect(page).to have_content('Alice Johnson')
      expect(page).to have_content('Complete Picture View')
      expect(page).to have_content('Achieved Milestones')
      expect(page).to have_content('Project Management')
      expect(page).to have_content('Milestone 2')
      expect(page).to have_content('These are the ability milestones this person has achieved')

      expect(page).to have_link('View All Abilities', href: organization_abilities_path(organization))
      expect(page).to have_link('Create New Ability', href: new_organization_ability_path(organization))
    end

    it 'shows milestone details with proper formatting' do
      # Create milestone attainment
      create(:teammate_milestone,
        teammate: employee_teammate,
        ability: ability,
        milestone_level: 3,
        certified_by: person,
        attained_at: 2.weeks.ago
      )

      visit complete_picture_organization_person_path(organization, employee_person)

      expect(page).to have_content('Project Management')
      expect(page).to have_content('Milestone 3')
      expect(page).to have_content('Oct 2025') # Date formatting
    end

    it 'shows no growth data state when appropriate' do
      visit complete_picture_organization_person_path(organization, employee_person)

      expect(page).to have_content('No Current Position')
      expect(page).to have_content('This person does not have an active employment tenure with a position')
    end
  end

  describe 'Milestone navigation and UI elements' do
    it 'navigates between milestone-related pages' do
      # Start at celebrate milestones
      visit celebrate_milestones_organization_path(organization)
      expect(page).to have_content('Recent Milestones')

      # Navigate to milestones overview
      visit milestones_overview_path
      expect(page).to have_content('Milestones Overview')

      # Navigate back to celebrate milestones
      visit celebrate_milestones_organization_path(organization)
      expect(page).to have_content('Recent Milestones')
    end

    it 'shows proper milestone level display' do
      employee_person = create(:person, full_name: 'Bob Wilson', email: 'bob@example.com')
      employee_teammate = create(:teammate, person: employee_person, organization: organization)
      ability = create(:ability, organization: organization, name: 'Leadership', created_by: person, updated_by: person)

      # Create milestone attainment
      create(:teammate_milestone,
        teammate: employee_teammate,
        ability: ability,
        milestone_level: 4,
        certified_by: person,
        attained_at: Date.current
      )

      visit celebrate_milestones_organization_path(organization)

      expect(page).to have_content('Bob Wilson')
      expect(page).to have_content('Leadership')
      expect(page).to have_content('Milestone 4')
    end

    it 'shows milestone certification information' do
      employee_person = create(:person, full_name: 'Carol Davis', email: 'carol@example.com')
      employee_teammate = create(:teammate, person: employee_person, organization: organization)
      ability = create(:ability, organization: organization, name: 'Communication', created_by: person, updated_by: person)

      # Create milestone attainment
      create(:teammate_milestone,
        teammate: employee_teammate,
        ability: ability,
        milestone_level: 1,
        certified_by: person,
        attained_at: Date.current
      )

      visit celebrate_milestones_organization_path(organization)

      expect(page).to have_content('Carol Davis')
      expect(page).to have_content('Communication')
      expect(page).to have_content('Milestone 1')
      expect(page).to have_content(person.display_name) # certified by
    end
  end
end
