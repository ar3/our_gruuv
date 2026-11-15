# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingInvoice, type: :model do
  let(:organization) { create(:organization) }
  let(:invoice) { create(:billing_invoice, organization: organization, status: 'open') }

  it 'allows manual open and waived statuses' do
    expect(described_class::MANUAL_STATUSES).to eq(%w[open waived])
  end

  it 'includes automation statuses for processor flows' do
    expect(described_class::AUTOMATION_STATUSES).to include('processing', 'paid', 'failed', 'refunded')
  end

  describe '#apply_manual_status!' do
    it 'waives an open invoice' do
      invoice.apply_manual_status!('waived')
      expect(invoice.reload).to be_waived
      expect(invoice.paid_at).to be_nil
    end

    it 'rejects automation-only statuses' do
      expect { invoice.apply_manual_status!('paid') }.to raise_error(ArgumentError)
    end
  end
end
