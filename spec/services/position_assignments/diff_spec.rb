# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PositionAssignments::Diff do
  let(:company) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:source_level) { create(:position_level, position_major_level: position_major_level) }
  let(:destination_level) { create(:position_level, position_major_level: position_major_level) }
  let(:source) { create(:position, title: title, position_level: source_level) }
  let(:destination) { create(:position, title: title, position_level: destination_level) }
  let(:assignment_a) { create(:assignment, company: company) }
  let(:assignment_b) { create(:assignment, company: company) }
  let(:assignment_c) { create(:assignment, company: company) }

  it 'returns empty result when both positions have no assignments' do
    result = described_class.call(source: source, destination: destination)
    expect(result.added).to be_empty
    expect(result.removed).to be_empty
    expect(result.changed).to be_empty
    expect(result).to be_empty
    expect(result.total_count).to eq(0)
  end

  it 'detects added rows (on source only)' do
    pa = create(:position_assignment, position: source, assignment: assignment_a, max_estimated_energy: 30)

    result = described_class.call(source: source, destination: destination)
    expect(result.added.map(&:id)).to eq([pa.id])
    expect(result.removed).to be_empty
    expect(result.changed).to be_empty
    expect(result.total_count).to eq(1)
  end

  it 'detects removed rows (on destination only)' do
    pa = create(:position_assignment, position: destination, assignment: assignment_a, max_estimated_energy: 40)

    result = described_class.call(source: source, destination: destination)
    expect(result.added).to be_empty
    expect(result.removed.map(&:id)).to eq([pa.id])
    expect(result.changed).to be_empty
  end

  it 'detects assignment_type change' do
    create(:position_assignment, position: source, assignment: assignment_a, assignment_type: 'required', max_estimated_energy: 30)
    create(:position_assignment, position: destination, assignment: assignment_a, assignment_type: 'suggested', max_estimated_energy: 30)

    result = described_class.call(source: source, destination: destination)
    expect(result.added).to be_empty
    expect(result.removed).to be_empty
    expect(result.changed.size).to eq(1)
    expect(result.changed.first[:source].assignment_type).to eq('required')
    expect(result.changed.first[:destination].assignment_type).to eq('suggested')
  end

  it 'detects energy change (min/max)' do
    create(:position_assignment, position: source, assignment: assignment_a, min_estimated_energy: 10, max_estimated_energy: 30)
    create(:position_assignment, position: destination, assignment: assignment_a, min_estimated_energy: 20, max_estimated_energy: 40)

    result = described_class.call(source: source, destination: destination)
    expect(result.changed.size).to eq(1)
    expect(result.added).to be_empty
    expect(result.removed).to be_empty
  end

  it 'treats identical rows as no diff' do
    create(:position_assignment, position: source, assignment: assignment_a, assignment_type: 'required', min_estimated_energy: 10, max_estimated_energy: 30)
    create(:position_assignment, position: destination, assignment: assignment_a, assignment_type: 'required', min_estimated_energy: 10, max_estimated_energy: 30)

    result = described_class.call(source: source, destination: destination)
    expect(result).to be_empty
  end

  it 'returns mixed added/removed/changed in one call' do
    create(:position_assignment, position: source, assignment: assignment_a, max_estimated_energy: 30)
    create(:position_assignment, position: destination, assignment: assignment_b, max_estimated_energy: 50)
    create(:position_assignment, position: source, assignment: assignment_c, assignment_type: 'required', max_estimated_energy: 20)
    create(:position_assignment, position: destination, assignment: assignment_c, assignment_type: 'suggested', max_estimated_energy: 20)

    result = described_class.call(source: source, destination: destination)
    expect(result.added.map(&:assignment_id)).to eq([assignment_a.id])
    expect(result.removed.map(&:assignment_id)).to eq([assignment_b.id])
    expect(result.changed.size).to eq(1)
    expect(result.changed.first[:source].assignment_id).to eq(assignment_c.id)
    expect(result.total_count).to eq(3)
  end
end
