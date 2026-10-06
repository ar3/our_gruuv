# frozen_string_literal: true

require "rails_helper"

RSpec.describe OgoQualityJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:observation) { create(:observation, company: organization) }
  let(:consultation) { create_ogo_quality_consultation!(observation: observation) }

  it "invokes the runner" do
    expect(Observations::OgoQualityRunner).to receive(:call).with(
      observation: observation,
      og_consultation: consultation
    ).and_return(true)

    described_class.perform_now(observation.id, consultation.id)
    expect(consultation.reload.status).to eq("processing")
  end
end
