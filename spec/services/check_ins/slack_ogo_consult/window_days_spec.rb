# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SlackOgoConsult::WindowDays do
  it "defaults to 30 days when since is blank (first check-in)" do
    expect(described_class.call(since: nil)).to eq(30)
  end

  it "snaps up to the next allowed window that covers the since bound" do
    expect(described_class.call(since: 20.days.ago)).to eq(30)
    expect(described_class.call(since: 45.days.ago)).to eq(90)
    expect(described_class.call(since: 100.days.ago)).to eq(180)
  end
end
