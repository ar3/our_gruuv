# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyGrowth::CompletedGoalsJourney do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:person) { teammate.person }

  def create_completed_goal(title:, completed_at:, confidence:, most_likely_target_date: nil, learnings: 'Learned a lot', deleted_at: nil)
    goal = create(
      :goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      title: title,
      started_at: completed_at - 2.weeks,
      completed_at: completed_at,
      most_likely_target_date: most_likely_target_date || (completed_at.to_date + 1.week),
      deleted_at: deleted_at
    )
    create(
      :goal_check_in,
      goal: goal,
      confidence_reporter: person,
      check_in_week_start: completed_at.to_date.beginning_of_week(:monday),
      confidence_percentage: confidence,
      confidence_reason: learnings
    )
    goal
  end

  describe '.build' do
    it 'returns empty when there are no completed goals' do
      result = described_class.build(organization: organization, teammate: teammate)

      expect(result[:empty]).to eq(true)
      expect(result[:entries]).to eq([])
    end

    it 'maps hit, hit_late, and miss→learning with celebratory labels' do
      hit = create_completed_goal(
        title: 'Hit Goal',
        completed_at: 10.days.ago,
        confidence: 100,
        most_likely_target_date: 5.days.from_now.to_date,
        learnings: 'Nailed it'
      )
      late = create_completed_goal(
        title: 'Late Goal',
        completed_at: 5.days.ago,
        confidence: 100,
        most_likely_target_date: 3.weeks.ago.to_date,
        learnings: 'Took longer but worth it'
      )
      learning = create_completed_goal(
        title: 'Learning Goal',
        completed_at: 2.days.ago,
        confidence: 0,
        learnings: 'Great lesson for next time'
      )

      result = described_class.build(organization: organization, teammate: teammate)
      entries_by_title = result[:entries].index_by(&:title)

      expect(result[:empty]).to eq(false)
      expect(entries_by_title['Hit Goal'].outcome).to eq(:hit)
      expect(entries_by_title['Hit Goal'].label).to eq('Hit')
      expect(entries_by_title['Late Goal'].outcome).to eq(:hit_late)
      expect(entries_by_title['Late Goal'].label).to eq('Hit (took longer)')
      expect(entries_by_title['Learning Goal'].outcome).to eq(:learning)
      expect(entries_by_title['Learning Goal'].label).to eq('Learning')
      expect(entries_by_title['Learning Goal'].learnings).to eq('Great lesson for next time')
      expect(entries_by_title['Hit Goal'].path).to eq(
        Rails.application.routes.url_helpers.organization_goal_path(organization, hit)
      )
      expect(result[:entries].map(&:goal_id)).to eq([learning.id, late.id, hit.id])
    end

    it 'filters by completed_in range and excludes soft-deleted goals' do
      create_completed_goal(title: 'In Range', completed_at: 10.days.ago, confidence: 100)
      create_completed_goal(title: 'Out of Range', completed_at: 200.days.ago, confidence: 100)
      create_completed_goal(title: 'Deleted', completed_at: 5.days.ago, confidence: 100, deleted_at: 1.day.ago)

      result = described_class.build(
        organization: organization,
        teammate: teammate,
        completed_in: 90.days.ago..Time.current
      )

      expect(result[:entries].map(&:title)).to eq(['In Range'])
    end

    it 'builds chart series with a journey path and outcome scatters' do
      create_completed_goal(title: 'A', completed_at: 3.days.ago, confidence: 100)
      create_completed_goal(title: 'B', completed_at: 1.day.ago, confidence: 0, learnings: 'Learning text')

      series = described_class.build(organization: organization, teammate: teammate)[:chart_data][:series]

      expect(series.first[:name]).to eq('Journey')
      expect(series.first[:type]).to eq('spline')
      expect(series.first[:data].length).to eq(2)
      expect(series.map { |s| s[:name] }).to include('Hit', 'Hit (took longer)', 'Learning')
      learning_series = series.find { |s| s[:name] == 'Learning' }
      expect(learning_series[:data].first[:learnings]).to eq('Learning text')
      expect(learning_series[:data].first[:url]).to be_present
    end
  end
end
