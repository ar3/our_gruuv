# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssignmentClarityJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let!(:assignment) { create(:assignment, company: organization) }
  let!(:consultation) { create_assignment_clarity_consultation!(assignment: assignment) }

  it 'invokes the runner' do
    expect(Maap::AssignmentClarityRunner).to receive(:call).with(
      assignment: assignment,
      og_consultation: consultation
    ).and_return(true)

    described_class.perform_now(assignment.id, consultation.id)
  end
end
