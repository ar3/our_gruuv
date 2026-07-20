# frozen_string_literal: true

require "rails_helper"

RSpec.describe OgCandidateReview::DefaultObserverToViewer do
  let(:organization) { create(:organization) }
  let(:viewer) { create(:company_teammate, organization: organization) }
  let(:subject_tm) { create(:company_teammate, organization: organization) }

  def item(responder_id:, subject_id:)
    {
      "id" => SecureRandom.uuid,
      "responder_company_teammate_id" => responder_id,
      "subject_company_teammate_id" => subject_id,
      "observer_unknown" => false
    }
  end

  it "defaults observer to viewer when observer equals observee" do
    result = described_class.apply_one(
      item(responder_id: subject_tm.id, subject_id: subject_tm.id),
      viewer: viewer
    )

    expect(result[:responder_company_teammate_id]).to eq(viewer.id)
    expect(result[:subject_company_teammate_id]).to eq(subject_tm.id)
    expect(result[:observer_unknown]).to eq(false)
  end

  it "leaves distinct observer/observee unchanged" do
    original = item(responder_id: viewer.id, subject_id: subject_tm.id)
    result = described_class.apply_one(original, viewer: viewer)

    expect(result[:responder_company_teammate_id]).to eq(viewer.id)
    expect(result[:subject_company_teammate_id]).to eq(subject_tm.id)
  end

  it "leaves self-pair unchanged when viewer is that same teammate" do
    result = described_class.apply_one(
      item(responder_id: viewer.id, subject_id: viewer.id),
      viewer: viewer
    )

    expect(result[:responder_company_teammate_id]).to eq(viewer.id)
    expect(result[:subject_company_teammate_id]).to eq(viewer.id)
  end

  it "no-ops without a viewer" do
    original = item(responder_id: subject_tm.id, subject_id: subject_tm.id)
    result = described_class.apply_one(original, viewer: nil)

    expect(result[:responder_company_teammate_id]).to eq(subject_tm.id)
  end

  it "applies across a list" do
    results = described_class.apply(
      [
        item(responder_id: subject_tm.id, subject_id: subject_tm.id),
        item(responder_id: viewer.id, subject_id: subject_tm.id)
      ],
      viewer: viewer
    )

    expect(results.map { |i| i[:responder_company_teammate_id] }).to eq([viewer.id, viewer.id])
  end
end
