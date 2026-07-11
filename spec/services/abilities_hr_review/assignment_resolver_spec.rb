# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::AssignmentResolver do
  let(:organization) { create(:organization) }

  it 'returns exact title match' do
    assignment = create(:assignment, company: organization, title: 'Line Cook')
    res = described_class.call(organization: organization, title: 'Line Cook')
    expect(res['assignment_id']).to eq(assignment.id)
    expect(res['match_kind']).to eq('exact')
  end

  it 'does not match archived assignments' do
    archived = create(:assignment, company: organization, title: 'Archived Prep')
    archived.archive!

    res = described_class.call(organization: organization, title: 'Archived Prep')
    expect(res['assignment_id']).to be_nil
    expect(res['match_kind']).to eq('none')
  end
end
