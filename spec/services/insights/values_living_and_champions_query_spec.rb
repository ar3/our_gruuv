# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::ValuesLivingAndChampionsQuery do
  let(:company) { create(:organization, :company) }
  let(:observer_person) { create(:person) }
  let(:observer) { create(:company_teammate, :assigned_employee, person: observer_person, organization: company) }
  let(:observee) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:private_only_observee) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:aspiration) { create(:aspiration, company: company, name: 'Integrity', sort_order: 1) }
  let(:other_aspiration) { create(:aspiration, company: company, name: 'Courage', sort_order: 2) }

  def publish_ogo!(privacy:, observee_teammate:, rate_aspiration:, published_at: Time.current, points: 0)
    observation = build(
      :observation,
      :published,
      company: company,
      observer: observer_person,
      privacy_level: privacy,
      published_at: published_at
    )
    observation.observees.destroy_all
    observation.observees.build(teammate: observee_teammate)
    observation.save!
    create(:observation_rating, observation: observation, rateable: rate_aspiration, rating: :agree)
    if points.positive?
      create(
        :points_exchange_transaction,
        organization: company,
        company_teammate: observee_teammate,
        observation: observation,
        points_to_spend_delta: points,
        points_to_give_delta: 0
      )
    end
    observation
  end

  before do
    observer
  end

  it 'ranks living values by total OGOs including private, and boards use public only' do
    publish_ogo!(privacy: :public_to_company, observee_teammate: observee, rate_aspiration: aspiration, points: 10)
    publish_ogo!(privacy: :public_to_company, observee_teammate: observee, rate_aspiration: aspiration, points: 5)
    publish_ogo!(privacy: :observed_and_managers, observee_teammate: private_only_observee, rate_aspiration: aspiration)
    publish_ogo!(privacy: :public_to_company, observee_teammate: observee, rate_aspiration: other_aspiration)

    sections = described_class.new(company: company).living_ranked
    integrity = sections.find { |s| s.aspiration.id == aspiration.id }
    courage = sections.find { |s| s.aspiration.id == other_aspiration.id }

    expect(integrity.total_ogo_count).to eq(3)
    expect(integrity.public_ogo_count).to eq(2)
    expect(integrity.private_ogo_count).to eq(1)
    expect(sections.first.aspiration.id).to eq(aspiration.id)

    expect(integrity.top_observees.map { |r| r.teammate.id }).to eq([observee.id])
    expect(integrity.top_observees.first.ogo_count).to eq(2)
    expect(integrity.top_observees.first.points).to eq(15.0)
    expect(integrity.top_observees.map(&:teammate)).not_to include(private_only_observee)

    expect(integrity.top_observers.first.teammate.id).to eq(observer.id)
    expect(integrity.top_observers.first.ogo_count).to eq(2)
    expect(integrity.top_observers.first.points).to eq(15.0)

    expect(courage.total_ogo_count).to eq(1)
  end

  it 'respects published_at range' do
    publish_ogo!(
      privacy: :public_to_company,
      observee_teammate: observee,
      rate_aspiration: aspiration,
      published_at: 2.years.ago
    )
    publish_ogo!(
      privacy: :public_to_company,
      observee_teammate: observee,
      rate_aspiration: aspiration,
      published_at: 1.day.ago
    )

    sections = described_class.new(company: company, published_at_range: 90.days.ago..Time.current).living_ranked
    integrity = sections.find { |s| s.aspiration.id == aspiration.id }
    expect(integrity.total_ogo_count).to eq(1)
  end
end
