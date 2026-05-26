# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReviewHelper, type: :helper do
  describe '#abilities_hr_milestone_option_label' do
    it 'includes milestone adjective and ability name' do
      label = helper.abilities_hr_milestone_option_label(2, ability_name: 'Knife work')
      expect(label).to eq('Milestone 2 – Advanced @ Knife work')
    end
  end

  describe '#abilities_hr_existing_assignment_ability_caption' do
    let(:organization) { create(:organization) }
    let!(:assignment) { create(:assignment, company: organization, title: 'Line Cook') }
    let!(:ability) { create(:ability, company: organization, name: 'Knife work') }

    it 'describes an existing assignment ability' do
      AssignmentAbility.create!(assignment: assignment, ability: ability, milestone_level: 2)
      caption = helper.abilities_hr_existing_assignment_ability_caption(
        assignment_id: assignment.id,
        ability_id: ability.id,
        ability_name: 'Knife work'
      )
      expect(caption).to eq('Existing today: Milestone 2 – Advanced @ Knife work')
    end

    it 'states when no association exists' do
      caption = helper.abilities_hr_existing_assignment_ability_caption(
        assignment_id: assignment.id,
        ability_id: ability.id,
        ability_name: 'Knife work'
      )
      expect(caption).to include('No association exists today')
    end
  end

  describe '#abilities_hr_association_rows_sorted_by_assignment' do
    it 'orders rows by resolved assignment title' do
      rows = [
        { 'id' => 'b', 'resolved_assignment_id' => 2, 'assignment_raw' => 'Zebra' },
        { 'id' => 'a', 'resolved_assignment_id' => 1, 'assignment_raw' => 'Apple' }
      ]
      sorted = helper.abilities_hr_association_rows_sorted_by_assignment(
        rows,
        assignment_titles_by_id: { 1 => 'Line Cook', 2 => 'Prep Cook' }
      )
      expect(sorted.map { |r| r['id'] }).to eq(%w[a b])
    end
  end

  describe '#abilities_hr_join_milestone_select_options' do
    it 'returns five milestone options' do
      html = helper.abilities_hr_join_milestone_select_options(ability_name: 'Knife work', selected: 2)
      expect(html).to include('Milestone 2 – Advanced @ Knife work')
      expect(html).to include('Milestone 1 – Demonstrated @ Knife work')
    end
  end
end
