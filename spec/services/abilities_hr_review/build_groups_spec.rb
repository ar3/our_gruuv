# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::BuildGroups do
  let(:organization) { create(:organization) }

  it 'splits same name with different descriptions into separate groups' do
    parsed = [
      parsed_row('Knife work', 'Desc A'),
      parsed_row('Knife work', 'Desc B')
    ]
    result = described_class.call(parsed_rows: parsed, organization: organization)
    expect(result['ability_groups'].size).to eq(2)
    expect(result['association_rows'].size).to eq(2)
  end

  it 'merges same name and same description into one group' do
    parsed = [
      parsed_row('Knife work', 'Same', assignment: 'Line Cook'),
      parsed_row('Knife work', 'Same', assignment: 'Prep Cook')
    ]
    result = described_class.call(parsed_rows: parsed, organization: organization)
    expect(result['ability_groups'].size).to eq(1)
    expect(result['ability_groups'].first['file_row_count']).to eq(2)
    expect(result['ability_groups'].first['file_assignment_count']).to eq(2)
    expect(result['association_rows'].size).to eq(2)
  end

  def parsed_row(name, description, assignment: 'Line Cook')
    desc_norm = AbilitiesHrReview::MarkdownNormalizer.call(description)
    milestones_norm = (1..5).to_h { |n| ["milestone_#{n}_normalized", ''] }
    {
      'ability_name' => name,
      'name_key' => name.downcase,
      'content_fingerprint' => AbilitiesHrReview::ContentFingerprint.call(
        description_normalized: desc_norm,
        milestone_normalized: milestones_norm
      ),
      'assignment_raw' => assignment,
      'resolved_assignment_id' => nil,
      'assignment_match_kind' => 'none',
      'assignment_alternatives' => [],
      'ability_match' => {
        'matched_ability_id' => nil,
        'ability_match_kind' => 'none',
        'default_department_id' => nil,
        'default_department_label' => 'None',
        'form_ability_name' => name
      },
      'description' => { 'raw' => description, 'normalized' => desc_norm, 'proposed' => nil },
      'milestones' => (1..5).each_with_object({}) { |n, h| h[n.to_s] = { 'raw' => '', 'normalized' => '', 'proposed' => nil } },
      'join_milestone' => { 'level' => 1 },
      'source_csv_row' => 1
    }.stringify_keys
  end
end
