# frozen_string_literal: true

require "rails_helper"

RSpec.describe AskOgResult do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }

  def build_result
    consultation = OgConsultation.create!(
      kind: OgConsultation::KIND_ASK_OG,
      subject: organization,
      organization: organization,
      triggered_by_teammate: teammate,
      status: "completed",
      billable: true,
      prompt_version: Assistant::Prompts::ASK_OG_PROMPT_VERSION,
      units_total: 1,
      units_completed: 1
    )
    result = AskOgResult.create!(og_consultation: consultation, query: "hello")
    consultation.update!(result: result)
    result
  end

  it "returns only the last TURN_WINDOW messages for the prompt" do
    result = build_result
    6.times do |i|
      result.append_message!(role: AskOgMessage::ROLE_USER, body: "msg #{i + 1}")
    end

    window = result.messages_for_prompt
    expect(window.size).to eq(5)
    expect(window.map(&:body)).to eq(["msg 2", "msg 3", "msg 4", "msg 5", "msg 6"])
  end
end
