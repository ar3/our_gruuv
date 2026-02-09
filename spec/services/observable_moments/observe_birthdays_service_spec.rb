# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObservableMoments::ObserveBirthdaysService do
  let(:organization) { create(:organization, :company) }

  describe '.call' do
    context 'when a teammate has a birthday in the past 14 days' do
      let!(:person) { create(:person, born_at: 5.days.ago - 25.years) }
      let!(:teammate) do
        create(:company_teammate, organization: organization, person: person,
               first_employed_at: 1.year.ago, last_terminated_at: nil)
      end
      let!(:employment_tenure) do
        create(:employment_tenure, company_teammate: teammate, company: organization, ended_at: nil)
      end

      it 'creates a birthday observable moment' do
        expect { described_class.call(organization: organization) }
          .to change { ObservableMoment.by_type(:birthday).where(company: organization).count }.by(1)
      end

      it 'does not create a duplicate if one exists in the past 14 days' do
        described_class.call(organization: organization)
        expect { described_class.call(organization: organization) }
          .not_to change { ObservableMoment.by_type(:birthday).where(company: organization).count }
      end
    end

    context 'when no teammate has a birthday in the past 14 days' do
      let!(:person) { create(:person, born_at: 100.days.ago - 25.years) }
      let!(:teammate) do
        create(:company_teammate, organization: organization, person: person,
               first_employed_at: 1.year.ago, last_terminated_at: nil)
      end

      it 'creates no moments' do
        expect { described_class.call(organization: organization) }
          .not_to change { ObservableMoment.by_type(:birthday).count }
      end
    end
  end
end
