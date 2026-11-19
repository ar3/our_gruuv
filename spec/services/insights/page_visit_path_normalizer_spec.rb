# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::PageVisitPathNormalizer do
  describe ".call" do
    it "replaces teammate-scoped route params with placeholders" do
      url = "/organizations/1-acme/company_teammates/42/check_ins"

      expect(described_class.call(url)).to eq(
        "/organizations/:organization_id/company_teammates/:company_teammate_id/check_ins"
      )
    end

    it "groups different teammate ids into the same pattern" do
      a = described_class.call("/organizations/9-acme/company_teammates/12/check_ins")
      b = described_class.call("/organizations/9-acme/company_teammates/99/check_ins")

      expect(a).to eq(b)
    end

    it "replaces assignment id-slug params" do
      url = "/organizations/1-acme/assignments/5-foo-bar"

      expect(described_class.call(url)).to eq(
        "/organizations/:organization_id/assignments/:id"
      )
    end

    it "keeps static insights paths except organization id" do
      url = "/organizations/1-acme/insights/who_is_doing_what"

      expect(described_class.call(url)).to eq(
        "/organizations/:organization_id/insights/who_is_doing_what"
      )
    end

    it "strips query params before normalizing" do
      url = "/organizations/1-acme/company_teammates/42/check_ins?tab=open"

      expect(described_class.call(url)).to eq(
        "/organizations/:organization_id/company_teammates/:company_teammate_id/check_ins"
      )
    end

    it "falls back to id-like segment replacement when the path is unrecognized" do
      url = "/legacy/things/123/details/456-slug"

      expect(described_class.call(url)).to eq("/legacy/things/:id/details/:id")
    end
  end

  describe ".label_for" do
    it "humanizes static segments and drops placeholders" do
      pattern = "/organizations/:organization_id/company_teammates/:company_teammate_id/check_ins"

      expect(described_class.label_for(pattern)).to eq("Company teammates / Check ins")
    end

    it "returns the pattern when nothing humanizable remains" do
      expect(described_class.label_for("/organizations/:organization_id")).to eq(
        "/organizations/:organization_id"
      )
    end
  end
end
