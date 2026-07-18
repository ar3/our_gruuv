# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeammateGrowthJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let!(:teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let!(:consultation) { create_teammate_growth_consultation!(teammate: teammate, organization: organization) }

  it 'invokes the runner' do
    expect(Maap::TeammateGrowthRunner).to receive(:call).with(
      teammate: teammate,
      organization: organization,
      og_consultation: consultation
    ).and_return(true)

    described_class.perform_now(teammate.id, organization.id, consultation.id)
  end
end
