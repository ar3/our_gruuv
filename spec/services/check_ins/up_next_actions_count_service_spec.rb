# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::UpNextActionsCountService do
  let(:organization) { create(:organization) }
  let(:employee) { create(:person) }
  let(:manager) { create(:person) }
  let!(:employee_teammate) { create(:company_teammate, person: employee, organization: organization, first_employed_at: 1.month.ago) }
  let!(:manager_teammate) { create(:company_teammate, person: manager, organization: organization, first_employed_at: 1.month.ago) }

  before do
    create(
      :employment_tenure,
      teammate: employee_teammate,
      company: organization,
      manager_teammate: manager_teammate,
      started_at: 1.month.ago,
      ended_at: nil
    )
  end

  describe ".call" do
    it "uses employee perspective when the viewer is the teammate" do
      allow(CheckIns::SingleItemCheckInNextItemService).to receive(:call).and_return({ ordered_items: [] })

      described_class.call(
        teammate: employee_teammate,
        organization: organization,
        viewing_teammate: employee_teammate
      )

      expect(CheckIns::SingleItemCheckInNextItemService).to have_received(:call).with(
        hash_including(current_person: employee)
      )
    end

    it "uses manager perspective when the viewer is someone else" do
      allow(CheckIns::SingleItemCheckInNextItemService).to receive(:call).and_return({ ordered_items: [] })

      described_class.call(
        teammate: employee_teammate,
        organization: organization,
        viewing_teammate: manager_teammate
      )

      expect(CheckIns::SingleItemCheckInNextItemService).to have_received(:call).with(
        hash_including(current_person: manager)
      )
    end
  end
end
