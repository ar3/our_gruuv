# frozen_string_literal: true

require "rails_helper"

RSpec.describe OgCandidateIdentityHelper, type: :helper do
  it "keeps up to three named alternate teammates" do
    item = {
      observer_alternates: [
        { "company_teammate_id" => 11, "name" => "Alex Able" },
        { company_teammate_id: 12, name: "Alex Baker" }
      ]
    }

    expect(helper.og_identity_alternates(item, :observer_alternates)).to eq(
      [
        { company_teammate_id: 11, name: "Alex Able" },
        { company_teammate_id: 12, name: "Alex Baker" }
      ]
    )
  end
end
