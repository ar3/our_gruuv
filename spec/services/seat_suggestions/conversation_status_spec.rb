# frozen_string_literal: true

require "rails_helper"

RSpec.describe SeatSuggestions::ConversationStatus do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, :unassigned_employee, organization: organization) }

  def build_consultation(status: "completed", confirms_count: 0, proposed_actions: [])
    consultation = OgConsultation.create!(
      kind: OgConsultation::KIND_SEAT_SUGGESTION,
      subject: organization,
      organization: organization,
      triggered_by_teammate: teammate,
      status: status,
      billable: true,
      units_total: 1,
      units_completed: status == "completed" ? 1 : 0,
      completed_at: status == "completed" ? Time.current : nil
    )
    AskOgResult.create!(
      og_consultation: consultation,
      query: "Need a new seat",
      proposed_actions: proposed_actions,
      confirms_count: confirms_count
    )
    consultation.update!(result: consultation.ask_og_result)
    consultation
  end

  it "is In progress while chatting or waiting on the model" do
    expect(described_class.for(build_consultation(status: "pending"))).to eq("In progress")
    expect(described_class.for(build_consultation(status: "processing"))).to eq("In progress")
    expect(described_class.for(build_consultation(status: "failed"))).to eq("In progress")
    expect(described_class.for(build_consultation(status: "completed"))).to eq("In progress")
  end

  it "is Draft being reviewed when a Confirm bundle action is ready" do
    consultation = build_consultation(
      status: "completed",
      proposed_actions: [
        {
          "tool" => "create_seat_suggestion_bundle",
          "label" => "Create Seat proposal drafts",
          "summary" => "Create drafts",
          "args" => {}
        }
      ]
    )

    expect(described_class.for(consultation)).to eq("Draft being reviewed")
    expect(described_class.badge_class_for(consultation)).to eq("text-bg-warning")
  end

  it "is Suggestion created after Confirm runs" do
    consultation = build_consultation(
      status: "completed",
      confirms_count: 1,
      proposed_actions: [
        { "tool" => "create_seat_suggestion_bundle", "label" => "Create", "summary" => "Create", "args" => {} }
      ]
    )

    expect(described_class.for(consultation)).to eq("Suggestion created")
    expect(described_class.badge_class_for(consultation)).to eq("text-bg-success")
  end
end
