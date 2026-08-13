# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionSuggestions::RoundSummaryBuilder do
  let(:organization) { create(:organization) }
  let(:opener) { create(:company_teammate, organization: organization) }
  let(:participant_tm) { create(:company_teammate, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level, level: "1.1") }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: "Client Discovery") }
  let(:ability) { create(:ability, company: organization, name: "Communication") }
  let!(:assignment_ability) do
    create(:position_assignment, position: position, assignment: assignment)
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
  end
  let!(:suggestion) do
    create(:position_suggestion, position: position, organization: organization, opened_by: opener)
  end
  let!(:participant) do
    create(:position_suggestion_participant, position_suggestion: suggestion, company_teammate: participant_tm)
  end

  describe "#call" do
    it "builds chronological timeline events and process rows" do
      free_comment = Comment.create!(
        commentable: assignment,
        organization: organization,
        creator: participant_tm.person,
        position_suggestion: suggestion,
        body: "Please clarify outcomes"
      )
      system_comment = Comment.create!(
        commentable: assignment,
        organization: organization,
        creator: participant_tm.person,
        position_suggestion: suggestion,
        suggestion_thread_subject: assignment_ability,
        body: "Milestone system note"
      )
      milestone = create(
        :position_suggestion_milestone,
        position_suggestion: suggestion,
        milestoneable: assignment_ability,
        last_modified_by: participant_tm,
        suggested_milestone_level: 3
      )

      result = described_class.call(suggestion: suggestion)
      texts = result[:timeline].map(&:text)

      expect(texts).to include("Suggestion round started")
      expect(texts.any? { |t| t.include?("began thinking about suggestions") }).to be true
      expect(texts.any? { |t| t.include?("added comment on Assignment Client Discovery") }).to be true
      expect(texts.any? { |t| t.include?("Communication") && t.include?("Milestone 3") }).to be true
      expect(texts.none? { |t| t.include?("Milestone system note") }).to be true
      # Free-text only in comment lines — system root is not a free_text timeline line beyond milestone event
      expect(result[:timeline].count { |e| e.kind == :comment }).to eq(1)

      kinds = result[:process_rows].map(&:kind)
      expect(kinds).to include(:free_text, :milestone)
      free_row = result[:process_rows].find { |r| r.kind == :free_text }
      expect(free_row.comment).to eq(free_comment)
      expect(free_row.anchor).to eq("assignment-#{assignment.id}")
      ms_row = result[:process_rows].find { |r| r.kind == :milestone }
      expect(ms_row.milestone).to eq(milestone)
      expect(ms_row.anchor).to eq("assignment-ability-#{assignment_ability.id}")
      expect(system_comment).to be_present
    end

    it "includes assignment link timeline and process rows" do
      allow(Comments::PostNotificationJob).to receive(:perform_and_get_result)
      link = PositionSuggestions::UpsertAssignmentLinkService.call(
        suggestion: suggestion,
        assignment: assignment,
        attributes: {
          action: "update",
          assignment_type: "suggested",
          min_estimated_energy: 10,
          max_estimated_energy: 30
        },
        modified_by: participant_tm
      ).value

      result = described_class.call(suggestion: suggestion)
      expect(result[:timeline].any? { |e| e.kind == :assignment_link && e.text.include?("association changes") }).to be true
      link_row = result[:process_rows].find { |r| r.kind == :assignment_link }
      expect(link_row.assignment_link).to eq(link)
      expect(link_row.anchor).to eq("assignment-#{assignment.id}-link")
    end
  end
end
