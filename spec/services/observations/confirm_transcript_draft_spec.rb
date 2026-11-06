require "rails_helper"

RSpec.describe Observations::ConfirmTranscriptDraft do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observation) do
    create(
      :observation,
      observer: observer,
      company: company,
      published_at: nil,
      privacy_level: :observed_only,
      created_as_type: Observation::CREATED_AS_OGO_CONSULT,
      story: "You already said this in the meeting."
    )
  end

  describe "quiet" do
    it "publishes for the observee and their manager without notifying anyone" do
      result = described_class.call(observation: observation, intent: "quiet")

      expect(result.ok?).to be(true)
      observation.reload
      expect(observation).to be_published
      expect(observation.privacy_level).to eq("observed_and_managers")
      expect(observation.notifications).to be_empty
    end
  end

  describe "channel" do
    it "refuses when the company has no channel and leaves the draft unpublished" do
      result = described_class.call(observation: observation, intent: "channel")

      expect(result.ok?).to be(false)
      expect(result.error).to include("No company channel")
      expect(observation.reload).to be_draft
    end

    it "publishes to the company and posts in the channel" do
      channel = create(:third_party_object, :slack_channel, organization: company, display_name: "#wins", third_party_id: "C555")
      company.kudos_channel_id = channel.third_party_id
      allow(Observations::PostNotificationJob).to receive(:perform_and_get_result)

      result = described_class.call(observation: observation, intent: "channel")

      expect(result.ok?).to be(true)
      expect(result.value).to include("#wins")
      observation.reload
      expect(observation).to be_published
      expect(observation.privacy_level).to eq("public_to_company")
      expect(Observations::PostNotificationJob).to have_received(:perform_and_get_result).with(observation.id, [], company.id)
    end
  end

  it "rejects a draft that did not come from a transcript consult" do
    handwritten = create(:observation, observer: observer, company: company, published_at: nil, story: "Typed by hand")

    result = described_class.call(observation: handwritten, intent: "quiet")

    expect(result.ok?).to be(false)
    expect(handwritten.reload).to be_draft
  end
end
