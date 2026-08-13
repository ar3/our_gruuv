# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::RealOgLeadersFeedbackRequestsSort do
  Entry = Struct.new(
    :has_requested_about,
    :has_sent,
    :has_received,
    :has_completed,
    :most_recent_at,
    :display_name,
    keyword_init: true
  )

  def entry(**attrs)
    Entry.new(
      has_requested_about: false,
      has_sent: false,
      has_received: false,
      has_completed: false,
      most_recent_at: nil,
      display_name: "X",
      **attrs
    )
  end

  describe ".sort_key / ordering" do
    it "puts all four above three above two above one" do
      four = entry(has_requested_about: true, has_sent: true, has_received: true, has_completed: true)
      three = entry(has_requested_about: true, has_sent: true, has_received: true)
      two = entry(has_requested_about: true, has_sent: true)
      one = entry(has_requested_about: true)

      ordered = [one, two, three, four].sort_by { |e| described_class.sort_key(e) }
      expect(ordered).to eq([four, three, two, one])
    end

    it "among singles prioritizes subject, then requestor, then respondent, then completed" do
      subject_only = entry(has_requested_about: true, display_name: "S")
      sent = entry(has_sent: true, display_name: "R")
      received = entry(has_received: true, display_name: "V")
      completed = entry(has_completed: true, display_name: "C")

      ordered = [completed, received, sent, subject_only].sort_by { |e| described_class.sort_key(e) }
      expect(ordered.map(&:display_name)).to eq(%w[S R V C])
    end

    it "among pairs prefers subject+requestor over subject+completed" do
      subject_sent = entry(has_requested_about: true, has_sent: true, display_name: "A")
      subject_completed = entry(has_requested_about: true, has_completed: true, display_name: "B")

      ordered = [subject_completed, subject_sent].sort_by { |e| described_class.sort_key(e) }
      expect(ordered.map(&:display_name)).to eq(%w[A B])
    end

    it "within a group puts more recent activity first" do
      older = entry(has_sent: true, most_recent_at: 2.days.ago, display_name: "Older")
      newer = entry(has_sent: true, most_recent_at: 1.hour.ago, display_name: "Newer")

      ordered = [older, newer].sort_by { |e| described_class.sort_key(e) }
      expect(ordered.map(&:display_name)).to eq(%w[Newer Older])
    end
  end
end
