# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::RealOgLeadersBuilder do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person, first_name: "Alex", last_name: "Lee") }
  let(:other) { create(:person, first_name: "Pat", last_name: "Ng") }
  let!(:observer_teammate) { create(:teammate, person: observer, organization: company) }
  let!(:other_teammate) { create(:teammate, person: other, organization: company) }

  def published_ogo!(attrs = {})
    obs_attrs = {
      observer: observer,
      company: company,
      privacy_level: :public_to_company,
      published_at: Time.current,
      observed_at: Time.current
    }.merge(attrs)
    obs = build(:observation, obs_attrs)
    obs.observees.clear
    obs.observees.build(teammate: other_teammate)
    obs.save!
    obs
  end

  def rate!(observation, rating)
    create(
      :observation_rating,
      observation: observation,
      rateable: create(:ability, company: company),
      rating: rating
    )
  end

  def ogo_for(person, at: Time.current)
    obs = build(
      :observation,
      observer: person,
      company: company,
      privacy_level: :public_to_company,
      published_at: at,
      observed_at: at
    )
    obs.observees.clear
    obs.observees.build(teammate: other_teammate)
    obs.save!
    obs
  end

  describe ".side_for" do
    it "returns :kudos when all ratings are positive" do
      obs = published_ogo!
      rate!(obs, :agree)
      obs.reload
      expect(described_class.side_for(obs)).to eq(:kudos)
    end

    it "returns :constructive when any rating is negative" do
      obs = published_ogo!
      rate!(obs, :agree)
      rate!(obs, :disagree)
      obs.reload
      expect(described_class.side_for(obs)).to eq(:constructive)
    end

    it "returns nil when there are no positive or negative ratings" do
      obs = published_ogo!
      expect(described_class.side_for(obs)).to be_nil
      rate!(obs, :na)
      obs.reload
      expect(described_class.side_for(obs)).to be_nil
    end
  end

  describe "#call" do
    it "includes people with kudos or constructive checks and stars both" do
      kudos = published_ogo!
      rate!(kudos, :strongly_agree)
      constructive = published_ogo!(observed_at: 1.hour.ago, published_at: 1.hour.ago)
      rate!(constructive, :disagree)

      rows = described_class.new(company: company, range: 90.days.ago..Time.current).call
      row = rows.find { |r| r.person == observer }

      expect(row).to be_present
      expect(row.has_kudos).to be true
      expect(row.has_constructive).to be true
      expect(row.has_both).to be true
      expect(row.kudos_count).to eq(1)
      expect(row.constructive_count).to eq(1)
      expect(row.total_count).to eq(2)
    end

    it "excludes journal OGOs, drafts, self-observees, and zero-rating OGOs" do
      draft = published_ogo!(published_at: nil)
      rate!(draft, :agree)

      journal = published_ogo!(privacy_level: :observer_only)
      rate!(journal, :agree)

      self_obs = build(
        :observation,
        observer: observer,
        company: company,
        privacy_level: :public_to_company,
        published_at: Time.current,
        observed_at: Time.current
      )
      self_obs.observees.clear
      self_obs.observees.build(teammate: observer_teammate)
      self_obs.save!
      rate!(self_obs, :agree)

      published_ogo! # no ratings

      expect(described_class.new(company: company, range: nil).call).to be_empty
    end

    it "sorts both before constructive-only before kudos-only, then by total" do
      both_person = create(:person, first_name: "Both", last_name: "Person")
      constructive_person = create(:person, first_name: "Construct", last_name: "Only")
      kudos_person = create(:person, first_name: "Kudos", last_name: "Only")
      create(:teammate, person: both_person, organization: company)
      create(:teammate, person: constructive_person, organization: company)
      create(:teammate, person: kudos_person, organization: company)

      a = ogo_for(both_person)
      rate!(a, :agree)
      b = ogo_for(both_person, at: 2.hours.ago)
      rate!(b, :disagree)

      2.times do |i|
        o = ogo_for(constructive_person, at: (i + 1).hours.ago)
        rate!(o, :disagree)
      end

      o = ogo_for(kudos_person)
      rate!(o, :agree)

      names = described_class.new(company: company, range: nil).call.map(&:display_name)

      expect(names.first).to include("Both")
      expect(names[1]).to include("Construct")
      expect(names[2]).to include("Kudos")
    end

    it "uses most recent OGO as tiebreaker after total count" do
      person_a = create(:person, first_name: "Alpha", last_name: "A")
      person_b = create(:person, first_name: "Beta", last_name: "B")
      create(:teammate, person: person_a, organization: company)
      create(:teammate, person: person_b, organization: company)

      older = ogo_for(person_a, at: 2.days.ago)
      rate!(older, :agree)

      newer = ogo_for(person_b, at: 1.hour.ago)
      rate!(newer, :agree)

      rows = described_class.new(company: company, range: nil).call
      expect(rows.map { |r| r.person.id }).to eq([person_b.id, person_a.id])
    end

    it "respects the timeframe range on observed_at" do
      in_range = published_ogo!(observed_at: 10.days.ago, published_at: 10.days.ago)
      rate!(in_range, :agree)
      out_of_range = published_ogo!(observed_at: 120.days.ago, published_at: 120.days.ago)
      rate!(out_of_range, :disagree)

      rows = described_class.new(company: company, range: 90.days.ago..Time.current).call
      expect(rows.size).to eq(1)
      expect(rows.first.kudos_count).to eq(1)
      expect(rows.first.constructive_count).to eq(0)
    end
  end
end
