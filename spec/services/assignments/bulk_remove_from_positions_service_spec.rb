require 'rails_helper'

RSpec.describe Assignments::BulkRemoveFromPositionsService do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let!(:position_assignment) do
    position_major_level = create(:position_major_level)
    title = create(:title, company: organization, position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level)
    position = create(:position, title: title, position_level: position_level)
    create(:position_assignment, position: position, assignment: assignment)
  end

  it 'removes all position assignments for the assignment' do
    result = described_class.call(assignment: assignment)

    expect(result.ok?).to be true
    expect(result.value[:count]).to eq(1)
    expect(assignment.position_assignments.reload).to be_empty
  end

  it 'returns an error when there are no position assignments' do
    position_assignment.destroy!

    result = described_class.call(assignment: assignment)

    expect(result.ok?).to be false
    expect(result.error).to include('No position assignments')
  end
end
