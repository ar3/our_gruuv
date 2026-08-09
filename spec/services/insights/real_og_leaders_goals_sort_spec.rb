# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::RealOgLeadersGoalsSort do
  Entry = Struct.new(
    :has_confidence_check,
    :has_connection,
    :has_completion,
    :latest_confidence_check_at,
    :display_name,
    keyword_init: true
  )

  def entry(**attrs)
    Entry.new(
      has_confidence_check: false,
      has_connection: false,
      has_completion: false,
      latest_confidence_check_at: nil,
      display_name: "X",
      **attrs
    )
  end

  describe ".sort_key / ordering" do
    it "puts all three above two-of-three above one-of-three" do
      three = entry(has_confidence_check: true, has_connection: true, has_completion: true)
      two = entry(has_confidence_check: true, has_connection: true)
      one = entry(has_confidence_check: true)

      ordered = [one, two, three].sort_by { |e| described_class.sort_key(e) }
      expect(ordered).to eq([three, two, one])
    end

    it "among singles prioritizes confidence, then connected, then completed" do
      conf = entry(has_confidence_check: true, display_name: "C")
      conn = entry(has_connection: true, display_name: "N")
      comp = entry(has_completion: true, display_name: "P")

      ordered = [comp, conf, conn].sort_by { |e| described_class.sort_key(e) }
      expect(ordered.map(&:display_name)).to eq(%w[C N P])
    end

    it "among pairs prioritizes conf+connected, then conf+completed, then connected+completed" do
      conf_conn = entry(has_confidence_check: true, has_connection: true, display_name: "A")
      conf_comp = entry(has_confidence_check: true, has_completion: true, display_name: "B")
      conn_comp = entry(has_connection: true, has_completion: true, display_name: "C")

      ordered = [conn_comp, conf_comp, conf_conn].sort_by { |e| described_class.sort_key(e) }
      expect(ordered.map(&:display_name)).to eq(%w[A B C])
    end

    it "within a group puts more recent confidence check first" do
      older = entry(
        has_confidence_check: true,
        latest_confidence_check_at: 2.days.ago,
        display_name: "Older"
      )
      newer = entry(
        has_confidence_check: true,
        latest_confidence_check_at: 1.hour.ago,
        display_name: "Newer"
      )

      ordered = [older, newer].sort_by { |e| described_class.sort_key(e) }
      expect(ordered.map(&:display_name)).to eq(%w[Newer Older])
    end
  end
end
