# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::ObservationsValuesCountsCsvBuilder do
  let(:company) { create(:organization) }
  let(:observer) { create(:person, first_name: 'Alice', last_name: 'Observer', email: 'alice@example.com') }
  let(:observee_person) { create(:person, first_name: 'Bob', last_name: 'Observee', email: 'bob@example.com') }
  let(:observee_teammate) do
    create(:teammate, person: observee_person, organization: company, first_employed_at: 1.year.ago)
  end
  let!(:aspiration) { create(:aspiration, company: company, name: 'Integrity', sort_order: 1) }

  def parse_csv(csv)
    CSV.parse(csv, headers: true)
  end

  def publish_observation!(observer:, observee_teammate:, privacy_level:, published_at:, aspiration_rating:)
    obs = build(
      :observation,
      observer: observer,
      company: company,
      privacy_level: privacy_level,
      published_at: published_at,
      observed_at: published_at
    )
    obs.observees.destroy_all
    obs.observees.build(teammate: observee_teammate)
    obs.save!
    obs
  end

  def add_aspiration_rating!(observation, rating)
    create(:observation_rating, observation: observation, rateable: aspiration, rating: rating)
  end

  it 'returns identifier headers and value count columns for each active aspiration' do
    published_at = 10.days.ago
    obs = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :observed_only,
      published_at: published_at,
      aspiration_rating: :strongly_agree
    )
    add_aspiration_rating!(obs, :strongly_agree)

    csv = described_class.new(company, published_at_range: 30.days.ago..Time.current).call
    rows = parse_csv(csv)

    expect(rows.headers).to include('all_names_display_name', 'email', 'OGO URL', 'department')
    expect(rows.first['OGO URL']).to include("/organizations/#{company.to_param}/observations")
    expect(rows.first['OGO URL']).to include("involving_teammate_id=#{observee_teammate.id}")
    expect(rows.headers).to include('Integrity : Private : Exceptional')
    expect(rows.headers).to include('Integrity : Public : Solid')
    expect(rows.headers).not_to include('Integrity : Public : Misaligned')
    expect(rows.headers).not_to include('Integrity : Public : Concerning')
    expect(rows.length).to eq(1)
    expect(rows.first['all_names_display_name']).to include('Bob')
    expect(rows.first['email']).to eq('bob@example.com')
    expect(rows.first['Integrity : Private : Exceptional']).to eq('1')
    expect(rows.first['Integrity : Private : Solid']).to eq('0')
  end

  it 'excludes journal observations' do
    obs = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :observer_only,
      published_at: 5.days.ago,
      aspiration_rating: :agree
    )
    add_aspiration_rating!(obs, :agree)

    csv = described_class.new(company).call
    expect(parse_csv(csv)).to be_empty
  end

  it 'excludes self-reflection observee but counts other observees on the same observation' do
    other_person = create(:person, first_name: 'Carol', last_name: 'Other', email: 'carol@example.com')
    other_teammate = create(:teammate, person: other_person, organization: company, first_employed_at: 1.year.ago)

    obs = build(
      :observation,
      observer: observer,
      company: company,
      privacy_level: :public_to_company,
      published_at: 5.days.ago,
      observed_at: 5.days.ago
    )
    obs.observees.destroy_all
    obs.observees.build(teammate: create(:teammate, person: observer, organization: company, first_employed_at: 1.year.ago))
    obs.observees.build(teammate: other_teammate)
    obs.save!
    add_aspiration_rating!(obs, :agree)

    csv = described_class.new(company).call
    rows = parse_csv(csv)

    expect(rows.length).to eq(1)
    expect(rows.first['email']).to eq('carol@example.com')
    expect(rows.first['Integrity : Public : Solid']).to eq('1')
  end

  it 'counts ratings separately for private and public privacy levels' do
    private_obs = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :managers_only,
      published_at: 8.days.ago,
      aspiration_rating: :disagree
    )
    add_aspiration_rating!(private_obs, :disagree)

    public_obs = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :public_to_world,
      published_at: 6.days.ago,
      aspiration_rating: :strongly_agree
    )
    add_aspiration_rating!(public_obs, :strongly_agree)

    row = parse_csv(described_class.new(company).call).first
    expect(row['Integrity : Private : Misaligned']).to eq('1')
    expect(row['Integrity : Public : Exceptional']).to eq('1')
  end

  it 'excludes N/A aspiration ratings' do
    obs = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :observed_only,
      published_at: 4.days.ago,
      aspiration_rating: :na
    )
    add_aspiration_rating!(obs, :na)

    expect(parse_csv(described_class.new(company).call)).to be_empty
  end

  it 'masks private count cells with X when show_private_counts is false' do
    private_obs = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :observed_only,
      published_at: 10.days.ago,
      aspiration_rating: :strongly_agree
    )
    add_aspiration_rating!(private_obs, :strongly_agree)

    public_obs = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :public_to_company,
      published_at: 8.days.ago,
      aspiration_rating: :agree
    )
    add_aspiration_rating!(public_obs, :agree)

    row = parse_csv(described_class.new(company, show_private_counts: false).call).first
    expect(row['Integrity : Private : Exceptional']).to eq('X')
    expect(row['Integrity : Private : Solid']).to eq('X')
    expect(row['Integrity : Public : Solid']).to eq('1')
  end

  it 'filters by published_at range' do
    in_range = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :observed_only,
      published_at: 10.days.ago,
      aspiration_rating: :agree
    )
    add_aspiration_rating!(in_range, :agree)

    out_of_range = publish_observation!(
      observer: observer,
      observee_teammate: observee_teammate,
      privacy_level: :observed_only,
      published_at: 100.days.ago,
      aspiration_rating: :agree
    )
    add_aspiration_rating!(out_of_range, :agree)

    row = parse_csv(described_class.new(company, published_at_range: 30.days.ago..Time.current).call).first
    expect(row['Integrity : Private : Solid']).to eq('1')
  end
end
