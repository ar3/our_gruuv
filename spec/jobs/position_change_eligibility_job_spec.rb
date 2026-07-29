# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PositionChangeEligibilityJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let!(:teammate) { create(:company_teammate, :unassigned_employee, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:consultation) do
    create_position_change_eligibility_consultation!(
      teammate: teammate,
      position: position,
      organization: organization
    )
  end

  it 'invokes the runner' do
    expect(Maap::PositionChangeEligibilityRunner).to receive(:call).with(
      teammate: teammate,
      position: position,
      organization: organization,
      og_consultation: consultation
    ).and_return(true)

    described_class.perform_now(teammate.id, position.id, organization.id, consultation.id)
  end
end
