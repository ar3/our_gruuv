require 'rails_helper'

RSpec.describe 'Abilities Table on Check-Ins Page', type: :system do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:organization, type: 'Department', parent: organization, name: 'Engineering') }
  let(:employee_person) { create(:person, full_name: 'John Doe', first_name: 'John') }
  let!(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }
  let(:manager_person) { create(:person, full_name: 'Manager Person') }
  let!(:manager_teammate) { create(:teammate, person: manager_person, organization: organization, can_manage_employment: true) }
  let(:certifier) { create(:person) }
  
  let!(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let!(:position_type) { create(:position_type, organization: organization, external_title: 'Software Engineer', position_major_level: position_major_level) }
  let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let!(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let!(:employment_tenure) do
    create(:employment_tenure,
      teammate: employee_teammate,
      position: position,
      company: organization,
      manager: manager_person,
      started_at: 1.year.ago
    )
  end

  describe 'Abilities section rendering' do
    context 'when abilities exist' do
      let!(:ability_with_milestone) { create(:ability, name: 'Ruby Programming', organization: organization) }
      let!(:ability_with_assignment) { create(:ability, name: 'React Development', organization: organization) }
      let!(:ability_with_both) { create(:ability, name: 'Database Design', organization: organization) }
      let!(:assignment1) { create(:assignment, company: organization, title: 'Frontend Project') }
      let!(:assignment2) { create(:assignment, company: organization, title: 'Backend Project') }

      before do
        # Create milestone attainments
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_milestone, certified_by: certifier, milestone_level: 2, attained_at: 3.months.ago)
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_both, certified_by: certifier, milestone_level: 1, attained_at: 6.months.ago)
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_with_both, certified_by: certifier, milestone_level: 3, attained_at: 1.month.ago)

        # Create assignment requirements
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment1, ended_at: nil)
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment2, ended_at: nil)
        create(:assignment_ability, assignment: assignment1, ability: ability_with_assignment, milestone_level: 3)
        create(:assignment_ability, assignment: assignment2, ability: ability_with_both, milestone_level: 4)
        create(:assignment_ability, assignment: assignment2, ability: ability_with_assignment, milestone_level: 2)
      end

      it 'displays abilities section on check-ins page' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        expect(page).to have_content('ABILITIES/SKILLS/KNOWLEDGE')
        expect(page).to have_content('View abilities relevant to your role and assignments')
      end

      it 'displays abilities table with correct columns' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table) do
          expect(page).to have_content('Ability')
          expect(page).to have_content('Why It\'s Relevant')
          expect(page).to have_content('When Milestones Achieved')
          expect(page).to have_content('John is actively pursuing:')
        end
      end

      it 'displays abilities sorted alphabetically' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        # Find all ability name cells in the abilities table
        ability_names = abilities_table.all('tbody tr').map { |row| row.find('td:first-child').text.strip }
        
        # Should be sorted alphabetically: Database Design, React Development, Ruby Programming
        expect(ability_names).to eq(['Database Design', 'React Development', 'Ruby Programming'])
      end

      it 'shows milestone attainments in relevance column' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          ruby_row = find('tr', text: 'Ruby Programming')
          expect(ruby_row).to have_content('You have Milestone 2')
        end
      end

      it 'shows assignment requirements in relevance column' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          react_row = find('tr', text: 'React Development')
          expect(react_row).to have_content('You need Milestone 3 for Frontend Project')
          expect(react_row).to have_content('You need Milestone 2 for Backend Project')
        end
      end

      it 'shows both milestones and assignment requirements when both exist' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          db_row = find('tr', text: 'Database Design')
          expect(db_row).to have_content('You have Milestone 1')
          expect(db_row).to have_content('You have Milestone 3')
          expect(db_row).to have_content('You need Milestone 4 for Backend Project')
        end
      end

      it 'displays milestone achievement dates correctly' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          ruby_row = find('tr', text: 'Ruby Programming')
          expect(ruby_row).to have_content('Milestone 2:')
          expect(ruby_row).to have_content(3.months.ago.strftime('%B %d, %Y'))
        end
      end

      it 'displays all milestone achievement dates for abilities with multiple milestones' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          db_row = find('tr', text: 'Database Design')
          expect(db_row).to have_content('Milestone 1:')
          expect(db_row).to have_content(6.months.ago.strftime('%B %d, %Y'))
          expect(db_row).to have_content('Milestone 3:')
          expect(db_row).to have_content(1.month.ago.strftime('%B %d, %Y'))
        end
      end

      it 'shows "None" for abilities without milestone achievements' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          react_row = find('tr', text: 'React Development')
          expect(react_row).to have_content('None')
        end
      end

      it 'displays goal column with radio buttons' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        first_row = abilities_table.find('tbody tr', text: 'Database Design')
        ability_id = ability_with_both.id
        
        within(first_row) do
          # Check for radio buttons (Capybara needs disabled: :all to find disabled fields)
          expect(first_row).to have_field("ability_goal[#{ability_id}]", type: 'radio', with: 'na', checked: true, disabled: :all)
          expect(first_row).to have_field("ability_goal[#{ability_id}]", type: 'radio', with: 'm1', disabled: :all)
          expect(first_row).to have_field("ability_goal[#{ability_id}]", type: 'radio', with: 'm2', disabled: :all)
          expect(first_row).to have_field("ability_goal[#{ability_id}]", type: 'radio', with: 'm3', disabled: :all)
          expect(first_row).to have_field("ability_goal[#{ability_id}]", type: 'radio', with: 'm4', disabled: :all)
          expect(first_row).to have_field("ability_goal[#{ability_id}]", type: 'radio', with: 'm5', disabled: :all)
        end
      end

      it 'displays goal radio button labels correctly' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        first_row = abilities_table.find('tbody tr:first-child')
        
        within(first_row) do
          expect(page).to have_content('N/A')
          expect(page).to have_content('M1: Demonstrated')
          expect(page).to have_content('M2: Advanced')
          expect(page).to have_content('M3: Expert')
          expect(page).to have_content('M4: Distinguished')
          expect(page).to have_content('M5: Industry-Recognized')
        end
      end

      it 'defaults goal radio buttons to N/A' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        # Check all rows have N/A selected
        abilities_table.all('tbody tr').each do |row|
          # Find the disabled N/A radio button using CSS selector
          na_radio = row.find('input[type="radio"][value="na"][disabled]', visible: false)
          expect(na_radio).to be_checked
        end
      end

      it 'shows employee first name in goal column header' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        expect(page).to have_content('John is actively pursuing:')
      end

      it 'lists all assignment requirements for abilities with multiple assignments' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          react_row = find('tr', text: 'React Development')
          expect(react_row).to have_content('You need Milestone 3 for Frontend Project')
          expect(react_row).to have_content('You need Milestone 2 for Backend Project')
        end
      end
    end

    context 'when no abilities exist' do
      it 'displays empty state message' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        within('.alert.alert-info[data-abilities-empty-state]') do
          expect(page).to have_content('No relevant abilities found')
        end
      end
    end

    context 'abilities from organization hierarchy' do
      let!(:ability_in_department) { create(:ability, name: 'Department Ability', organization: department) }

      before do
        create(:teammate_milestone, teammate: employee_teammate, ability: ability_in_department, certified_by: certifier, milestone_level: 2)
      end

      it 'includes abilities from departments within the organization hierarchy' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table) do
          expect(page).to have_content('Department Ability')
        end
      end
    end

    context 'ability links' do
      let!(:ability) { create(:ability, name: 'Test Ability', organization: organization) }

      before do
        create(:teammate_milestone, teammate: employee_teammate, ability: ability, certified_by: certifier, milestone_level: 1)
      end

      it 'links to ability show page when user has permission' do
        # Set up ability policy to allow viewing
        allow_any_instance_of(AbilityPolicy).to receive(:show?).and_return(true)
        
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          expect(page).to have_link('Test Ability', href: organization_ability_path(organization, ability))
        end
      end

      it 'shows ability name without link when user lacks permission' do
        # Set up ability policy to deny viewing
        allow_any_instance_of(AbilityPolicy).to receive(:show?).and_return(false)
        
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        abilities_table = find('table[data-abilities-table]')
        within(abilities_table.find('tbody')) do
          expect(page).to have_content('Test Ability')
          expect(page).not_to have_link('Test Ability')
        end
      end
    end

    context 'inactive assignment tenures' do
      let!(:ability) { create(:ability, name: 'Inactive Ability', organization: organization) }
      let!(:assignment) { create(:assignment, company: organization, title: 'Inactive Assignment') }

      before do
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment, started_at: 3.months.ago, ended_at: 1.month.ago)
        create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
      end

      it 'excludes abilities from inactive assignment tenures' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        expect(page).not_to have_content('Inactive Ability')
      end
    end

    context 'different view modes' do
      let!(:ability) { create(:ability, name: 'Test Ability', organization: organization) }

      before do
        create(:teammate_milestone, teammate: employee_teammate, ability: ability, certified_by: certifier, milestone_level: 1)
      end

      it 'displays abilities table in employee view' do
        sign_in_as(employee_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        expect(page).to have_content('ABILITIES/SKILLS/KNOWLEDGE')
        abilities_table = find('table[data-abilities-table]')
        expect(abilities_table).to have_content('Test Ability')
      end

      it 'displays abilities table in manager view' do
        sign_in_as(manager_person, organization)
        visit organization_person_check_ins_path(organization, employee_person)

        expect(page).to have_content('ABILITIES/SKILLS/KNOWLEDGE')
        abilities_table = find('table[data-abilities-table]')
        expect(abilities_table).to have_content('Test Ability')
      end
    end
  end
end

