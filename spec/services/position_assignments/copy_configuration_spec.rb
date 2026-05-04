# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PositionAssignments::CopyConfiguration do
  let(:company) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: company, position_major_level: position_major_level) }
  let(:source_level) { create(:position_level, position_major_level: position_major_level) }
  let(:destination_level) { create(:position_level, position_major_level: position_major_level) }
  let(:source) { create(:position, title: title, position_level: source_level) }
  let(:destination) { create(:position, title: title, position_level: destination_level) }
  let(:assignment_a) { create(:assignment, company: company) }
  let(:assignment_b) { create(:assignment, company: company) }

  it 'copies all source position_assignments onto an empty destination' do
    create(:position_assignment, position: source, assignment: assignment_a, assignment_type: 'required', min_estimated_energy: 10, max_estimated_energy: 30)
    create(:position_assignment, position: source, assignment: assignment_b, assignment_type: 'suggested', min_estimated_energy: nil, max_estimated_energy: 50)

    described_class.call(source: source, destination: destination)

    destination_pas = destination.reload.position_assignments.order(:assignment_id)
    expect(destination_pas.map(&:assignment_id)).to match_array([assignment_a.id, assignment_b.id])

    pa_a = destination_pas.find_by(assignment_id: assignment_a.id)
    expect(pa_a.assignment_type).to eq('required')
    expect(pa_a.min_estimated_energy).to eq(10)
    expect(pa_a.max_estimated_energy).to eq(30)

    pa_b = destination_pas.find_by(assignment_id: assignment_b.id)
    expect(pa_b.assignment_type).to eq('suggested')
    expect(pa_b.min_estimated_energy).to be_nil
    expect(pa_b.max_estimated_energy).to eq(50)
  end

  it 'overwrites existing destination position_assignments (destroy + recreate)' do
    create(:position_assignment, position: source, assignment: assignment_a, assignment_type: 'required', max_estimated_energy: 30)
    existing = create(:position_assignment, position: destination, assignment: assignment_b, assignment_type: 'suggested', max_estimated_energy: 60)

    described_class.call(source: source, destination: destination)

    expect(PositionAssignment.find_by(id: existing.id)).to be_nil
    expect(destination.reload.position_assignments.map(&:assignment_id)).to eq([assignment_a.id])
  end

  it 'clears the destination when source has no position_assignments' do
    create(:position_assignment, position: destination, assignment: assignment_a, max_estimated_energy: 30)

    described_class.call(source: source, destination: destination)

    expect(destination.reload.position_assignments).to be_empty
  end

  it 'records a paper trail version on the destination via record_version_for_assignment_changes!' do
    create(:position_assignment, position: source, assignment: assignment_a, assignment_type: 'required', max_estimated_energy: 30)

    expect do
      described_class.call(source: source, destination: destination)
    end.to change { destination.reload.versions.count }.by_at_least(1)

    last = destination.reload.versions.last
    expect(last.changeset.keys.map(&:to_s)).to include('assignments_audit_snapshot')
  end

  it 'uses the provided change_context' do
    create(:position_assignment, position: source, assignment: assignment_a, assignment_type: 'required', max_estimated_energy: 30)

    described_class.call(source: source, destination: destination, change_context: 'Custom context for test')

    last = destination.reload.versions.last
    meta = last.respond_to?(:meta) ? last.meta : {}
    if meta && meta['position_assignment_change_context']
      expect(meta['position_assignment_change_context']).to eq('Custom context for test')
    end
  end

  it 'rolls back the destroy/create when the version step fails' do
    create(:position_assignment, position: source, assignment: assignment_a, assignment_type: 'required', max_estimated_energy: 30)
    pre_existing = create(:position_assignment, position: destination, assignment: assignment_b, max_estimated_energy: 60)

    allow_any_instance_of(Position).to receive(:record_version_for_assignment_changes!).and_raise(StandardError, 'boom')

    expect do
      described_class.call(source: source, destination: destination)
    end.to raise_error(StandardError, 'boom')

    expect(PositionAssignment.find_by(id: pre_existing.id)).to be_present
    expect(destination.reload.position_assignments.map(&:assignment_id)).to eq([assignment_b.id])
  end

  it 'raises ArgumentError when source and destination are the same' do
    expect do
      described_class.call(source: source, destination: source)
    end.to raise_error(ArgumentError)
  end
end
