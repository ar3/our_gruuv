# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObservableMoments::ObserveWorkAnniversariesService do
  let(:organization) { create(:organization, :company) }

  describe '.call' do
    context 'when a teammate has a work anniversary in the past 14 days' do
      let(:anniversary_date) { 5.days.ago }
      let!(:teammate) do
        create(:company_teammate, organization: organization,
               first_employed_at: anniversary_date - 2.years, last_terminated_at: nil)
      end
      let!(:employment_tenure) do
        create(:employment_tenure, company_teammate: teammate, company: organization, ended_at: nil)
      end

      it 'creates a work_anniversary observable moment' do
        expect { described_class.call(organization: organization) }
          .to change { ObservableMoment.by_type(:work_anniversary).where(company: organization).count }.by(1)
      end

      it 'does not create a duplicate if one exists in the past 14 days' do
        described_class.call(organization: organization)
        expect { described_class.call(organization: organization) }
          .not_to change { ObservableMoment.by_type(:work_anniversary).where(company: organization).count }
      end
    end

    context 'when no teammate has a work anniversary in the past 14 days' do
      let!(:teammate) do
        create(:company_teammate, organization: organization,
               first_employed_at: 100.days.ago - 1.year, last_terminated_at: nil)
      end

      it 'creates no moments' do
        expect { described_class.call(organization: organization) }
          .not_to change { ObservableMoment.by_type(:work_anniversary).count }
      end
    end
  end
end
