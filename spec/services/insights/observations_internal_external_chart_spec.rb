# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::ObservationsInternalExternalChart do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }
  let(:outsider) { create(:person) }
  let(:chart_range) { 2.weeks.ago.beginning_of_week..Time.current }

  it 'stacks Internal vs External by week' do
    create(:observation,
      company: company,
      observer: teammate.person,
      published_at: 3.days.ago,
      observed_at: 3.days.ago,
      deleted_at: nil
    )
    create(:observation,
      company: company,
      observer: outsider,
      published_at: 3.days.ago,
      observed_at: 3.days.ago,
      deleted_at: nil
    )

    base_scope = Observation.for_company(company).not_soft_deleted.published
    result = described_class.call(
      base_scope: base_scope,
      chart_range: chart_range,
      organization: company
    )

    expect(result[:series].map { |s| s[:name] }).to eq(%w[Internal External])
    internal = result[:series].find { |s| s[:name] == 'Internal' }
    external = result[:series].find { |s| s[:name] == 'External' }
    expect(internal[:data].sum).to eq(1)
    expect(external[:data].sum).to eq(1)
  end

  it 'counts terminated observers as Internal' do
    former = create(:person)
    create(:company_teammate,
      person: former,
      organization: company,
      last_terminated_at: Date.current,
      first_employed_at: 1.year.ago
    )
    create(:observation,
      company: company,
      observer: former,
      published_at: 3.days.ago,
      observed_at: 3.days.ago,
      deleted_at: nil
    )

    base_scope = Observation.for_company(company).not_soft_deleted.published
    result = described_class.call(
      base_scope: base_scope,
      chart_range: chart_range,
      organization: company
    )
    internal = result[:series].find { |s| s[:name] == 'Internal' }
    external = result[:series].find { |s| s[:name] == 'External' }
    expect(internal[:data].sum).to eq(1)
    expect(external[:data].sum).to eq(0)
  end
end
