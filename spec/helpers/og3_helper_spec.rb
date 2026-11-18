# frozen_string_literal: true

require "rails_helper"

RSpec.describe Og3Helper, type: :helper do
  it "exposes short, medium, and clear labels" do
    expect(helper.og3_label_short).to eq("OG3")
    expect(helper.og3_label_medium).to eq("OG3 Goals")
    expect(helper.og3_label_clear).to eq("OG3 Progressive Outcome")
    expect(helper.og3_label_clear_goal).to eq("OG3 Progressive Outcome (Goal)")
    expect(helper.og3_label(:clear)).to eq("OG3 Progressive Outcome")
  end

  it "includes a hover blurb covering Commit / Stretch / Transform" do
    blurb = helper.og3_hover_blurb
    expect(blurb).to include("Commit")
    expect(blurb).to include("Stretch")
    expect(blurb).to include("Transform")
  end

  it "formats outcome values with a space only before alpha units" do
    expect(helper.og3_format_outcome_value(BigDecimal("60"), "%")).to eq("60%")
    expect(helper.og3_format_outcome_value(BigDecimal("70"), "customers")).to eq("70 customers")
    expect(helper.og3_format_outcome_value(nil, "%")).to be_nil
  end
end

