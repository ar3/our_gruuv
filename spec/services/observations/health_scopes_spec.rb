# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observations::HealthScopes do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }
  let(:other_teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }
  let(:observer) { teammate.person }
  let(:other_person) { other_teammate.person }

  def publish_observation!(attrs = {})
    defaults = {
      observer: observer,
      company: organization,
      published_at: 5.days.ago,
      deleted_at: nil,
      privacy_level: :observed_only,
      story: "Published story"
    }
    build(:observation, defaults.merge(attrs.except(:observee_teammates))).tap do |obs|
      Array(attrs[:observee_teammates]).each { |t| obs.observees.build(teammate: t) }
      obs.save!
    end
  end

  describe ".company_ids_for" do
    it "includes the organization (and any descendants when hierarchy exists)" do
      expect(described_class.company_ids_for(organization)).to include(organization.id)
    end
  end

  describe ".published_non_journal_scope" do
    it "excludes journal entries" do
      publish_observation!(privacy_level: :observer_only)
      expect(described_class.published_non_journal_scope(organization)).not_to exist
    end
  end

  describe ".given_scope" do
    it "includes non-journal published observations by the teammate" do
      publish_observation!(privacy_level: :observed_only)
      expect(described_class.given_scope(teammate, organization)).to exist
    end

    it "excludes journal entries" do
      publish_observation!(privacy_level: :observer_only)
      expect(described_class.given_scope(teammate, organization)).not_to exist
    end

    it "excludes drafts and soft-deleted observations" do
      build(:observation, observer: observer, company: organization, published_at: nil, story: "Draft").save!
      build(:observation, observer: observer, company: organization, published_at: 5.days.ago, deleted_at: Time.current, story: "Deleted").save!
      expect(described_class.given_scope(teammate, organization)).not_to exist
    end
  end

  describe ".received_scope" do
    it "includes published observations where teammate is an observee" do
      publish_observation!(observer: other_person, observee_teammates: [teammate])
      expect(described_class.received_scope(teammate, organization)).to exist
    end

    it "excludes journal observations unless observer is the observee" do
      publish_observation!(
        observer: other_person,
        privacy_level: :observer_only,
        observee_teammates: [teammate]
      )
      expect(described_class.received_scope(teammate, organization)).not_to exist
    end

    it "includes self journal when observer is also the observee" do
      publish_observation!(
        privacy_level: :observer_only,
        observee_teammates: [teammate]
      )
      expect(described_class.received_scope(teammate, organization)).to exist
    end
  end
end
