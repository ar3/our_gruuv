# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObservableMoments::PrimaryPotentialObserverResolver do
  let(:organization) { create(:organization, :company) }
  let(:teammate_person) { create(:person) }
  let(:teammate) do
    create(:company_teammate, organization: organization, person: teammate_person,
           first_employed_at: 1.year.ago, last_terminated_at: nil)
  end

  describe '.call' do
    context 'when organization has observable_moment_notifier_teammate' do
      let!(:notifier) { create(:company_teammate, organization: organization, can_manage_employment: true) }
      before { organization.update!(observable_moment_notifier_teammate: notifier) }

      it 'returns the notifier' do
        expect(described_class.call(organization: organization, teammate: teammate)).to eq(notifier)
      end
    end

    context 'when teammate has a manager' do
      let!(:manager) { create(:company_teammate, organization: organization) }
      let!(:tenure) do
        create(:employment_tenure, company_teammate: teammate, company: organization,
               manager_teammate: manager, ended_at: nil)
      end

      it 'returns the manager' do
        expect(described_class.call(organization: organization, teammate: teammate)).to eq(manager)
      end
    end

    context 'when someone in org has can_manage_employment' do
      let!(:hr_teammate) { create(:company_teammate, organization: organization, can_manage_employment: true) }

      it 'returns the first teammate with can_manage_employment' do
        expect(described_class.call(organization: organization, teammate: teammate)).to eq(hr_teammate)
      end
    end

    context 'when no notifier, no manager, no one with can_manage_employment' do
      it 'returns the teammate themselves' do
        expect(described_class.call(organization: organization, teammate: teammate)).to eq(teammate)
      end
    end
  end
end
