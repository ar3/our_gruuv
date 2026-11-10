# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObservationsHelper, 'external observer', type: :helper do
  let(:company) { create(:organization, :company) }

  def build_observation(observer:)
    create(:observation,
      company: company,
      observer: observer,
      privacy_level: :public_to_company,
      published_at: Time.current
    )
  end

  describe '#observation_observer_external?' do
    it 'is false when the observer is an active teammate of the company' do
      observer = create(:company_teammate, organization: company).person
      observation = build_observation(observer: observer)
      expect(helper.observation_observer_external?(observation)).to be false
    end

    it 'is true when the observer has no teammate record for the company' do
      outsider = create(:person)
      observation = build_observation(observer: outsider)
      expect(helper.observation_observer_external?(observation)).to be true
    end

    it 'is true when the observer only has a terminated teammate for the company' do
      outsider = create(:person)
      create(:company_teammate,
        person: outsider,
        organization: company,
        last_terminated_at: Date.current,
        first_employed_at: 1.year.ago
      )
      observation = build_observation(observer: outsider)
      expect(helper.observation_observer_external?(observation)).to be true
    end
  end

  describe '#observation_observer_attribution' do
    it 'includes an External badge and links outsiders to the external person page' do
      outsider = create(:person, first_name: 'Pat', last_name: 'Guest')
      observation = build_observation(observer: outsider)
      html = helper.observation_observer_attribution(observation, organization: company)
      expect(html).to include('Pat')
      expect(html).to include('External')
      expect(html).to include(organization_external_person_path(company, outsider))
    end

    it 'does not include External for org teammates' do
      observer = create(:company_teammate, organization: company).person
      observation = build_observation(observer: observer)
      html = helper.observation_observer_attribution(observation)
      expect(html).not_to include('External')
    end

    it 'links teammate observers to their teammate page' do
      observer_teammate = create(:company_teammate, organization: company)
      observation = build_observation(observer: observer_teammate.person)
      html = helper.observation_observer_attribution(observation, organization: company)
      expect(html).to include(organization_company_teammate_path(company, observer_teammate))
      expect(html).not_to include('External')
    end
  end
end
