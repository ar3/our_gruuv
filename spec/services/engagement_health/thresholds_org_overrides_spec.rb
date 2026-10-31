# frozen_string_literal: true

require "rails_helper"

RSpec.describe EngagementHealth::Thresholds do
  let(:organization) { create(:organization, :company) }

  describe ".required_clarity_healthy_within_days" do
    it "defaults to 60 when unset" do
      expect(described_class.required_clarity_healthy_within_days(organization)).to eq(60)
      expect(described_class.required_clarity_healthy_within_days(nil)).to eq(60)
    end

    it "reads a company preference override" do
      organization.company_label_preferences.create!(
        label_key: described_class::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY,
        label_value: "45"
      )

      expect(described_class.required_clarity_healthy_within_days(organization)).to eq(45)
    end
  end

  describe ".required_clarity_needs_attention_at_days" do
    it "defaults to 90 when unset" do
      expect(described_class.required_clarity_needs_attention_at_days(organization)).to eq(90)
    end

    it "reads a company preference override" do
      organization.company_label_preferences.create!(
        label_key: described_class::REQUIRED_CLARITY_NEEDS_ATTENTION_AT_DAYS_KEY,
        label_value: "120"
      )

      expect(described_class.required_clarity_needs_attention_at_days(organization)).to eq(120)
    end
  end

  describe ".new_assignment_grace_within_days" do
    it "tracks the org Healthy window" do
      organization.company_label_preferences.create!(
        label_key: described_class::REQUIRED_CLARITY_HEALTHY_WITHIN_DAYS_KEY,
        label_value: "45"
      )

      expect(described_class.new_assignment_grace_within_days(organization)).to eq(45)
    end
  end

  describe ".required_clarity_*_from" do
    it "prefers values baked into EH inputs" do
      expect(
        described_class.required_clarity_healthy_within_days_from(
          inputs: { "healthy_within_days" => 40 },
          organization: organization
        )
      ).to eq(40)
    end
  end
end
