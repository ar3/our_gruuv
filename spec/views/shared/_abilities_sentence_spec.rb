require 'rails_helper'

RSpec.describe 'shared/_abilities_sentence', type: :view do
  let(:organization) { create(:organization, :company) }
  let(:ability1) { create(:ability, company: organization, name: 'Communication') }
  let(:ability2) { create(:ability, company: organization, name: 'Mentorship') }
  let(:ability3) { create(:ability, company: organization, name: 'Manager Development') }
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_ability1) { create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 2) }
  let(:assignment_ability2) { create(:assignment_ability, assignment: assignment, ability: ability2, milestone_level: 2) }
  let(:assignment_ability3) { create(:assignment_ability, assignment: assignment, ability: ability3, milestone_level: 3) }

  before do
    assignment_ability1
    assignment_ability2
    assignment_ability3
  end

  context 'without parentheticals' do
    it 'displays abilities in sentence format without milestone numbers' do
      render partial: 'shared/abilities_sentence',
             locals: {
               assignment_abilities: assignment.assignment_abilities.by_milestone_level,
               public_view: false,
               show_milestone_parentheticals: false,
               include_prefix: true
             }

      expect(rendered).to include('… needing Abilities such as –')
      expect(rendered).to include('advanced Communication')
      expect(rendered).to include('advanced Mentorship')
      expect(rendered).to include('expert Manager Development')
      expect(rendered).not_to include('(M2)')
      expect(rendered).not_to include('(M3)')
    end

    it 'handles single ability' do
      single_assignment = create(:assignment, company: organization)
      single_aa = create(:assignment_ability, assignment: single_assignment, ability: ability1, milestone_level: 2)

      render partial: 'shared/abilities_sentence',
             locals: {
               assignment_abilities: [single_aa],
               public_view: false,
               show_milestone_parentheticals: false,
               include_prefix: true
             }

      expect(rendered).to include('advanced Communication')
      expect(rendered).not_to include('and')
    end

    it 'handles two abilities with "and"' do
      two_assignment = create(:assignment, company: organization)
      aa1 = create(:assignment_ability, assignment: two_assignment, ability: ability1, milestone_level: 2)
      aa2 = create(:assignment_ability, assignment: two_assignment, ability: ability2, milestone_level: 3)

      render partial: 'shared/abilities_sentence',
             locals: {
               assignment_abilities: [aa1, aa2],
               public_view: false,
               show_milestone_parentheticals: false,
               include_prefix: true
             }

      expect(rendered).to include('advanced Communication and expert Mentorship')
    end
  end

  context 'with parentheticals' do
    it 'displays abilities with milestone numbers in parentheses' do
      render partial: 'shared/abilities_sentence',
             locals: {
               assignment_abilities: assignment.assignment_abilities.by_milestone_level,
               public_view: false,
               show_milestone_parentheticals: true,
               include_prefix: true
             }

      expect(rendered).to include('… needing Abilities such as –')
      expect(rendered).to include('advanced Communication (M2)')
      expect(rendered).to include('advanced Mentorship (M2)')
      expect(rendered).to include('expert Manager Development (M3)')
    end
  end

  context 'without prefix' do
    it 'does not include the prefix when include_prefix is false' do
      render partial: 'shared/abilities_sentence',
             locals: {
               assignment_abilities: assignment.assignment_abilities.by_milestone_level,
               public_view: false,
               show_milestone_parentheticals: false,
               include_prefix: false
             }

      expect(rendered).not_to include('… needing Abilities such as –')
      expect(rendered).to include('advanced Communication')
    end
  end

  context 'with public_view' do
    it 'links to public MAAP pages when public_view is true' do
      render partial: 'shared/abilities_sentence',
             locals: {
               assignment_abilities: [assignment_ability1],
               public_view: true,
               show_milestone_parentheticals: false,
               include_prefix: true
             }

      expect(rendered).to have_link('advanced Communication', href: organization_public_maap_ability_path(organization, ability1))
    end

    it 'links to authenticated pages when public_view is false' do
      render partial: 'shared/abilities_sentence',
             locals: {
               assignment_abilities: [assignment_ability1],
               public_view: false,
               show_milestone_parentheticals: false,
               include_prefix: true
             }

      expect(rendered).to have_link('advanced Communication', href: organization_ability_path(organization, ability1))
    end
  end

  context 'with no abilities' do
    it 'displays fallback message' do
      empty_assignment = create(:assignment, company: organization)

      render partial: 'shared/abilities_sentence',
             locals: {
               assignment_abilities: empty_assignment.assignment_abilities,
               public_view: false,
               show_milestone_parentheticals: false,
               include_prefix: true
             }

      expect(rendered).to include('ability milestones to be determined')
    end
  end
end

