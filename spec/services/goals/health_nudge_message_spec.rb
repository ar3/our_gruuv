# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::HealthNudgeMessage do
  let(:company) { create(:organization, :company) }
  let(:manager_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:stats) do
    {
      total_employees: 4,
      healthy_count: 2,
      warning_count: 1,
      needs_attention_count: 1,
      ok_count: 1,
      concerning_count: 1
    }
  end

  subject(:message) do
    described_class.new(
      organization: company,
      manager_teammate: manager_teammate,
      spotlight_stats: stats
    )
  end

  it "includes counts and why Goal Confidence matters when the team is not fully healthy" do
    expect(message.body_mrkdwn).to include("Goals Health check-in")
    expect(message.body_mrkdwn).to include("Of *4* people")
    expect(message.body_mrkdwn).to include("*2* Healthy")
    expect(message.body_mrkdwn).to include(Goals::HealthNudgeMessage::IMPORTANCE_WHEN_UNHEALTHY)
    expect(message.fallback_text).to include("Open:")
  end

  it "stays encouraging without the importance paragraph when everyone is healthy" do
    healthy_message = described_class.new(
      organization: company,
      manager_teammate: manager_teammate,
      spotlight_stats: stats.merge(warning_count: 0, needs_attention_count: 0, ok_count: 0, concerning_count: 0)
    )
    expect(healthy_message.body_mrkdwn).not_to include(Goals::HealthNudgeMessage::IMPORTANCE_WHEN_UNHEALTHY)
    expect(healthy_message.body_mrkdwn).to include("Nice work")
  end
end
