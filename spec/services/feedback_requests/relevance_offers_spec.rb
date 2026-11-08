# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedbackRequests::RelevanceOffers do
  let(:organization) { create(:organization, :company) }
  let(:viewer) { create(:company_teammate, organization: organization) }
  let(:subject_tm) { create(:company_teammate, organization: organization) }

  it 'always includes a values offer' do
    create(:aspiration, company: organization, name: 'Integrity', department: nil)

    offers = described_class.call(viewer: viewer, subject: subject_tm)

    expect(offers.map(&:kind)).to include('values')
    expect(offers.find { |o| o.kind == 'values' }.offer_key).to eq('values')
  end

  it 'includes assignment offers when viewer consumes subject supplier assignment' do
    supplier = create(:assignment, company: organization, title: 'Upstream')
    consumer = create(:assignment, company: organization, title: 'Downstream')
    create(:assignment_supply_relationship, supplier_assignment: supplier, consumer_assignment: consumer)
    create(:assignment_tenure, teammate: subject_tm, assignment: supplier, anticipated_energy_percentage: 40, ended_at: nil)
    create(:assignment_tenure, teammate: viewer, assignment: consumer, anticipated_energy_percentage: 30, ended_at: nil)

    offers = described_class.call(viewer: viewer, subject: subject_tm)
    assignment_offers = offers.select { |o| o.kind == 'assignment' }

    expect(assignment_offers.size).to eq(1)
    expect(assignment_offers.first.offer_key).to eq("assignment:#{supplier.id}")
  end

  it 'includes ability offers when viewer has a higher milestone on a required ability' do
    ability = create(:ability, company: organization, name: 'Coaching')
    assignment = create(:assignment, company: organization)
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
    create(:assignment_tenure, teammate: subject_tm, assignment: assignment, anticipated_energy_percentage: 50, ended_at: nil)
    create(:teammate_milestone, company_teammate: subject_tm, ability: ability, milestone_level: 1)
    create(:teammate_milestone, company_teammate: viewer, ability: ability, milestone_level: 3)

    offers = described_class.call(viewer: viewer, subject: subject_tm)
    ability_offers = offers.select { |o| o.kind == 'ability' }

    expect(ability_offers.size).to eq(1)
    expect(ability_offers.first.offer_key).to eq("ability:#{ability.id}")
  end
end
