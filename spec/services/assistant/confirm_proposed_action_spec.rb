# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::ConfirmProposedAction, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:observee) { create(:teammate, organization: organization) }
  let(:context) do
    Assistant::ContextBuilder.call(organization: organization, company_teammate: teammate)
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: observee, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "invokes create_draft_observation via AgentTools and returns redirect_path" do
    started = Assistant::StartAskOg.call(
      organization: organization,
      company_teammate: teammate,
      query: "draft kudos"
    )
    consultation = started.value[:consultation]
    consultation.result.update!(
      answer_text: "I can draft that.",
      proposed_actions: [
        {
          "tool" => "create_draft_observation",
          "label" => "Draft OGO",
          "summary" => "Create draft",
          "args" => {
            "observee_path" => AgentTools::RecordPaths.teammate_path(context, observee),
            "story" => "Nice work",
            "observation_type" => "kudos"
          }
        }
      ]
    )
    consultation.update!(status: "completed", completed_at: Time.current, units_completed: 1)

    result = described_class.call(
      og_consultation: consultation,
      action_index: 0,
      context: context
    )

    expect(result.ok?).to be(true)
    expect(result.value[:path]).to be_present
    expect(result.value[:redirect_path]).to be_present
    expect(Observation.order(:id).last.published_at).to be_nil
  end
end
