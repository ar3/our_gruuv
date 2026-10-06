# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transcripts::TeammateResolverService do
  let(:organization) { create(:organization) }
  let(:pat) do
    person = create(:person, first_name: "Pat", last_name: "Subject")
    create(:company_teammate, person: person, organization: organization, first_employed_at: 1.year.ago)
  end
  let(:alex_able) do
    person = create(:person, first_name: "Alex", last_name: "Able")
    create(:company_teammate, person: person, organization: organization, first_employed_at: 1.year.ago)
  end
  let(:alex_baker) do
    person = create(:person, first_name: "Alex", last_name: "Baker")
    create(:company_teammate, person: person, organization: organization, first_employed_at: 1.year.ago)
  end

  before do
    allow_any_instance_of(described_class).to receive(:bedrock_configured?).and_return(false)
    [pat, alex_able, alex_baker]
  end

  def call(label)
    described_class.call(organization: organization, label: label)
  end

  it "returns a unique roster match as sure with no alternates" do
    result = call("Pat")

    expect(result[:company_teammate_id]).to eq(pat.id)
    expect(result[:unknown]).to eq(false)
    expect(result[:alternates]).to eq([])
  end

  it "keeps the best guess and lists up to three other people when the label is ambiguous" do
    result = call("Alex")

    expect(result[:unknown]).to eq(true)
    expect([alex_able.id, alex_baker.id]).to include(result[:company_teammate_id])
    alternate_ids = result[:alternates].map { |alt| alt["company_teammate_id"] }
    expect(alternate_ids).to contain_exactly(([alex_able.id, alex_baker.id] - [result[:company_teammate_id]]).first)
    expect(result[:alternates].first["name"]).to be_present
  end

  it "returns unknown with no guess when nothing matches" do
    result = call("Nobodyhere")

    expect(result[:company_teammate_id]).to eq(nil)
    expect(result[:unknown]).to eq(true)
    expect(result[:alternates]).to eq([])
  end
end
