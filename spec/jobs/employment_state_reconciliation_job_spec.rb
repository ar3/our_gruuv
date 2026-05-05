require 'rails_helper'

RSpec.describe EmploymentStateReconciliationJob, type: :job do
  it 'returns true when reconciliation succeeds without corrections' do
    allow(EmploymentStateReconciliationService).to receive(:call).and_return(
      Result.ok(scanned_teammates: 2, corrected_teammates: 0, corrected_fields: 0, corrections: [])
    )

    expect(described_class.perform_and_get_result).to be(true)
  end

  it 'sends a sentry warning when corrections were made' do
    allow(EmploymentStateReconciliationService).to receive(:call).and_return(
      Result.ok(
        scanned_teammates: 2,
        corrected_teammates: 1,
        corrected_fields: 2,
        corrections: [{ teammate_id: 1, changed_fields: %i[first_employed_at last_terminated_at] }]
      )
    )
    allow(Sentry).to receive(:capture_message)

    described_class.perform_and_get_result

    expect(Sentry).to have_received(:capture_message).with(
      'Employment state reconciliation corrected teammate records',
      hash_including(level: :warning)
    )
  end
end
