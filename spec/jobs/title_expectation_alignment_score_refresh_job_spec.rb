# frozen_string_literal: true

require "rails_helper"

RSpec.describe TitleExpectationAlignmentScoreRefreshJob, type: :job do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: organization, position_major_level: major_level, end_cap: true) }
  let(:level_1) { create(:position_level, position_major_level: major_level, level: "1.1") }

  it "persists the title score after refreshing positions" do
    position = create(:position, title: title, position_level: level_1)
    assignment = create(:assignment, company: organization, title: "Ready")
    create(:position_assignment, :required, position: position, assignment: assignment)
    create(:assignment_outcome, assignment: assignment)
    person = create(:person)
    2.times do
      create(:assignment_ability,
             assignment: assignment,
             ability: create(:ability, company: organization, created_by: person, updated_by: person),
             milestone_level: 2)
    end

    expect {
      described_class.perform_now(title.id)
    }.to change(TitleExpectationAlignmentScore, :count).by(1)

    expect(title.reload.expectation_alignment_score_cache.score.to_f).to eq(50.0)
    expect(position.reload.expectation_alignment_score_cache.score.to_f).to eq(100.0)
  end
end

RSpec.describe DailyRefreshTitleExpectationAlignmentScoresJob, type: :job do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level) }
  let!(:title) { create(:title, company: organization, position_major_level: major_level) }
  let!(:archived) do
    create(:title, company: organization, position_major_level: major_level, external_title: "Archived", deleted_at: Time.current)
  end

  it "enqueues a refresh for each unarchived title" do
    expect {
      described_class.perform_now
    }.to have_enqueued_job(TitleExpectationAlignmentScoreRefreshJob).with(title.id)

    expect(ActiveJob::Base.queue_adapter.enqueued_jobs).not_to include(
      a_hash_including(
        job: TitleExpectationAlignmentScoreRefreshJob,
        args: [archived.id]
      )
    )
  end
end
