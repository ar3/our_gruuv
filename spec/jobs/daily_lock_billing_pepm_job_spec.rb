# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyLockBillingPepmJob, type: :job do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization) }
  let(:as_of) { Date.new(2026, 11, 24) }
  let(:due_on) { Date.new(2026, 12, 1) }

  before do
    OrganizationBillingSetting.for_organization!(organization).update!(
      cadence: 'monthly',
      next_payment_due_on: due_on
    )
  end

  it 'enqueues a lock job when today is calculation day' do
    expect {
      described_class.perform_now(as_of: as_of)
    }.to have_enqueued_job(Billing::LockDuePepmJob).with(organization.id, as_of: as_of)
  end

  it 'does not enqueue when today is not calculation day' do
    expect {
      described_class.perform_now(as_of: as_of - 1.day)
    }.not_to have_enqueued_job(Billing::LockDuePepmJob)
  end
end
