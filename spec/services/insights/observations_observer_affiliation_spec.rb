# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::ObservationsObserverAffiliation do
  let(:company) { create(:organization, :company) }

  describe '.teammate_person_ids' do
    it 'includes active and terminated teammates, excludes never-hired people' do
      active = create(:company_teammate, organization: company).person
      former = create(:person)
      create(:company_teammate,
        person: former,
        organization: company,
        last_terminated_at: Date.current,
        first_employed_at: 1.year.ago
      )
      outsider = create(:person)

      ids = described_class.teammate_person_ids(
        organization: company,
        person_ids: [active.id, former.id, outsider.id]
      )
      expect(ids).to include(active.id, former.id)
      expect(ids).not_to include(outsider.id)
    end
  end

  describe '.observer_department_label' do
    it 'returns External when there is no teammate' do
      expect(described_class.observer_department_label(person_id: 1, teammate: nil))
        .to eq('External')
    end

    it 'returns No Department for a teammate without an active tenure department' do
      teammate = create(:company_teammate, organization: company)
      expect(described_class.observer_department_label(person_id: teammate.person_id, teammate: teammate))
        .to eq('No Department')
    end
  end

  describe '.sort_department_names' do
    it 'puts No Department then External after real departments' do
      expect(described_class.sort_department_names(['External', 'Alpha', 'No Department', 'Beta']))
        .to eq(['Alpha', 'Beta', 'No Department', 'External'])
    end
  end
end
