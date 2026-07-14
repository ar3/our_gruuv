# frozen_string_literal: true

require "rails_helper"

RSpec.describe SingleItemCheckInHelper do
  include described_class

  describe "#single_item_check_in_bucket_emoji" do
    it "returns ‼️ for red" do
      expect(single_item_check_in_bucket_emoji(:red)).to eq("‼️")
    end

    it "returns ⚠️ for yellow" do
      expect(single_item_check_in_bucket_emoji(:yellow)).to eq("⚠️")
    end

    it "returns ✅ for green" do
      expect(single_item_check_in_bucket_emoji(:green)).to eq("✅")
    end

    it "returns ‼️ for nil or unknown" do
      expect(single_item_check_in_bucket_emoji(nil)).to eq("‼️")
    end
  end

  describe "#single_item_object_queue_viewer_chip_label" do
    it "labels your turn strongly" do
      expect(single_item_object_queue_viewer_chip_label(:your_turn)).to eq("Your turn")
    end
  end

  describe "#single_item_object_queue_row_subcopy" do
    it "uses the counterpart name for waiting" do
      expect(
        single_item_object_queue_row_subcopy(
          { viewer_state: :waiting },
          employee_name: "Pat",
          manager_name: "Alex",
          manager_perspective: false
        )
      ).to eq("Waiting on Alex")
    end
  end

  describe "#single_item_object_queue_health_tooltip" do
    it "says never finalized when blank" do
      expect(single_item_object_queue_health_tooltip({ last_finalized_at: nil })).to eq("Never finalized")
    end

    it "uses time ago in words when present" do
      expect(single_item_object_queue_health_tooltip({ last_finalized_at: 3.days.ago })).to eq("Last finalized 3 days ago")
    end
  end

  describe "research AI prompt helpers" do
    include ApplicationHelper

    let(:organization) { create(:organization) }
    let(:person) { create(:person, first_name: "Jamie", last_name: "Rivera", preferred_name: "Jamie") }
    let(:teammate) { create(:company_teammate, person: person, organization: organization) }

    describe "#single_item_check_in_slack_handle" do
      it "returns nil when there is no Slack identity" do
        expect(single_item_check_in_slack_handle(teammate)).to be_nil
      end

      it "returns @handle from users.list-style raw_data name" do
        create(:teammate_identity, :slack, teammate: teammate, name: "Jamie Rivera",
               raw_data: { "name" => "jamie.rivera", "profile" => { "real_name" => "Jamie Rivera" } })

        expect(single_item_check_in_slack_handle(teammate)).to eq("@jamie.rivera")
      end

      it "omits spaced display names that are not handles" do
        create(:teammate_identity, :slack, teammate: teammate, name: "Jamie Rivera",
               raw_data: { "profile" => { "display_name" => "Jamie Rivera" } })

        expect(single_item_check_in_slack_handle(teammate)).to be_nil
      end
    end

    describe "#single_item_check_in_assignment_research_ai_prompt" do
      let(:assignment) { create(:assignment, company: organization) }
      let!(:outcome) do
        create(:assignment_outcome, assignment: assignment,
               description: "Ship **clarity** outcomes [docs](https://example.com)")
      end

      it "includes name, 90-day lookback when never finalized, and stripped outcomes" do
        prompt = single_item_check_in_assignment_research_ai_prompt(
          teammate: teammate,
          latest_finalized: nil,
          outcomes: [outcome]
        )
        expected_since = 90.days.ago.strftime("%B %-d, %Y")

        expect(prompt).to include("check-in about Jamie Rivera.")
        expect(prompt).not_to include("(@")
        expect(prompt).to include("between #{expected_since} and today")
        expect(prompt).to include("- Ship clarity outcomes docs")
        expect(prompt).not_to include("**")
        expect(prompt).not_to include("https://example.com")
      end

      it "includes Slack handle and last finalized date when present" do
        create(:teammate_identity, :slack, teammate: teammate,
               raw_data: { "name" => "jamie.r" })
        finalized = create(:assignment_check_in, :officially_completed,
                           teammate: teammate, assignment: assignment)
        finalized.update_columns(official_check_in_completed_at: Time.zone.local(2026, 3, 15, 12, 0, 0))

        prompt = single_item_check_in_assignment_research_ai_prompt(
          teammate: teammate,
          latest_finalized: finalized,
          outcomes: [outcome]
        )

        expect(prompt).to include("Jamie Rivera (@jamie.r)")
        expect(prompt).to include("between March 15, 2026 and today")
      end
    end

    describe "#single_item_check_in_aspiration_research_ai_prompt" do
      let(:aspiration) do
        create(:aspiration, company: organization, name: "Curiosity",
               description: "Ask *better* questions")
      end

      it "uses value name and plain description" do
        prompt = single_item_check_in_aspiration_research_ai_prompt(
          teammate: teammate,
          aspiration: aspiration,
          latest_finalized: nil
        )

        expect(prompt).to include("Curiosity")
        expect(prompt).to include("Ask better questions")
        expect(prompt).not_to include("*better*")
      end
    end
  end
end
