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

    it 'falls back to assignment_raw when resolved_assignment_id is nil' do
      rows = [
        { 'id' => 'b', 'resolved_assignment_id' => nil, 'assignment_raw' => 'Zebra' },
        { 'id' => 'a', 'resolved_assignment_id' => nil, 'assignment_raw' => 'Apple' }
      ]

      expect do
        sorted = helper.abilities_hr_association_rows_sorted_by_assignment(
          rows,
          assignment_titles_by_id: {}
        )
        expect(sorted.map { |r| r['id'] }).to eq(%w[a b])
      end.not_to raise_error
    end
  end

  describe '#abilities_hr_join_milestone_select_options' do
    it 'returns five milestone options' do
      html = helper.abilities_hr_join_milestone_select_options(ability_name: 'Knife work', selected: 2)
      expect(html).to include('Milestone 2 – Advanced @ Knife work')
      expect(html).to include('Milestone 1 – Demonstrated @ Knife work')
    end
  end

  describe '#abilities_hr_values_differ?' do
    it 'treats surrounding whitespace as equal' do
      expect(helper.abilities_hr_values_differ?('  Same value  ', 'Same value')).to be(false)
    end

    it 'returns true when trimmed values differ' do
      expect(helper.abilities_hr_values_differ?('One', 'Two')).to be(true)
    end
  end

  describe '#abilities_hr_field_comparison' do
    let(:organization) { create(:organization) }
    let(:ability) do
      create(
        :ability,
        company: organization,
        description: 'Use knives safely.',
        milestone_1_description: 'M1 existing'
      )
    end

    it 'returns existing ability values for description and milestones' do
      description = helper.abilities_hr_field_comparison(
        matched_ability: ability,
        field: 'description',
        proposed_value: 'Use knives safely.'
      )
      milestone = helper.abilities_hr_field_comparison(
        matched_ability: ability,
        field: 'milestone_1_description',
        proposed_value: 'M1 new'
      )

      expect(description['existing_value']).to eq('Use knives safely.')
      expect(description['different']).to be(false)
      expect(milestone['existing_value']).to eq('M1 existing')
      expect(milestone['different']).to be(true)
    end
  end
end
