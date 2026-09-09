# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionExpectationAlignmentScoreRefreshJob, type: :job do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  it "persists the position expectation alignment score" do
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
      described_class.perform_now(position.id)
    }.to change(PositionExpectationAlignmentScore, :count).by(1)

    expect(position.reload.expectation_alignment_score_cache.score.to_f).to eq(100.0)
  end
end

RSpec.describe DailyRefreshPositionExpectationAlignmentScoresJob, type: :job do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:archived) do
    create(:position,
           title: title,
           position_level: create(:position_level, position_major_level: title.position_major_level, level: "9.9"),
           deleted_at: Time.current)
  end

  it "enqueues a refresh for each unarchived position and skips archived ones" do
    expect {
      described_class.perform_now
    }.to have_enqueued_job(PositionExpectationAlignmentScoreRefreshJob).with(position.id)

    expect(ActiveJob::Base.queue_adapter.enqueued_jobs).not_to include(
      a_hash_including(
        job: PositionExpectationAlignmentScoreRefreshJob,
        args: [archived.id]
      )
    )
  end
end
