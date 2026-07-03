# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EngagementHealth::Calculator do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:reference_time) { Time.current }

  # NOTE: the employment_tenure factory builds its own position (in the tenure's
  # company), so tests read the position off the created tenure.

  def create_goal(state, **attrs)
    timestamps =
      case state
      when :draft then { started_at: nil, completed_at: nil }
      when :active then { started_at: 1.day.ago, completed_at: nil }
      when :completed then { started_at: 1.week.ago, completed_at: 1.day.ago }
      end
    create(:goal, **timestamps.merge(attrs))
  end

  def rows_for(category, level: nil)
    rows = described_class.call(teammate: teammate, organization: organization, reference_time: reference_time)
      .select { |row| row[:category] == category }
    level ? rows.select { |row| row[:level] == level } : rows
  end

  def rollup_for(category)
    rows_for(category, level: 'category').first
  end

  describe 'thresholds (EngagementHealth::Thresholds.status_for_last_event)' do
    def status_at(days_ago)
      EngagementHealth::Thresholds.status_for_last_event(
        days_ago.days.ago,
        healthy_within: 30,
        needs_attention_at: 90
      )
    end

    it 'is MECE across the boundaries' do
      expect(status_at(0)).to eq(EngagementHealth::HEALTHY)
      expect(status_at(30)).to eq(EngagementHealth::HEALTHY)
      expect(status_at(31)).to eq(EngagementHealth::AT_RISK)
      expect(status_at(89)).to eq(EngagementHealth::AT_RISK)
      expect(status_at(90)).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(status_at(365)).to eq(EngagementHealth::NEEDS_ATTENTION)
    end

    it 'treats never (nil) as Needs Attention' do
      expect(
        EngagementHealth::Thresholds.status_for_last_event(nil, healthy_within: 30, needs_attention_at: 90)
      ).to eq(EngagementHealth::NEEDS_ATTENTION)
    end

    it 'treats events after reference_time as never (negative days_since)' do
      days = EngagementHealth::Thresholds.days_since(1.day.from_now, reference_time: Time.current)
      expect(days).to be_nil
      expect(
        EngagementHealth::Thresholds.status_for_last_event(
          1.day.from_now,
          healthy_within: 30,
          needs_attention_at: 90,
          reference_time: Time.current
        )
      ).to eq(EngagementHealth::NEEDS_ATTENTION)
    end
  end

  describe 'OGO given and received' do
    it 'is Needs Attention with never flag when no observations exist' do
      %w[ogo_given ogo_received].each do |category|
        item = rows_for(category, level: 'item').first
        expect(item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
        expect(item[:inputs]['never']).to be(true)
        expect(rollup_for(category)[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      end
    end

    it 'rates given by last published observation authored by the teammate' do
      observation = create(:observation, observer: person, company: organization)
      observation.update!(published_at: 45.days.ago)

      item = rows_for('ogo_given', level: 'item').first
      expect(item[:status]).to eq(EngagementHealth::AT_RISK)
      expect(item[:inputs]['days_since_last_event']).to eq(45)
    end

    it 'rates received by last published observation where the teammate is an observee' do
      observation = create(:observation, company: organization)
      observation.observees.destroy_all
      create(:observee, observation: observation, company_teammate: teammate)
      observation.update!(published_at: 10.days.ago)

      expect(rows_for('ogo_received', level: 'item').first[:status]).to eq(EngagementHealth::HEALTHY)
      # Not authored by this teammate, so given is still off track/never
      expect(rows_for('ogo_given', level: 'item').first[:inputs]['never']).to be(true)
    end
  end

  describe 'historical reference_time (point-in-time events)' do
    let(:reference_time) { Time.zone.parse('2025-06-08 23:59:59') }

    it 'ignores OGOs published after reference_time and rates by the prior event' do
      old_obs = create(:observation, observer: person, company: organization)
      old_obs.update!(published_at: reference_time - 120.days)

      future_obs = create(:observation, observer: person, company: organization)
      future_obs.update!(published_at: reference_time + 60.days)

      item = rows_for('ogo_given', level: 'item').first
      expect(item[:inputs]['last_event_id']).to eq(old_obs.id)
      expect(item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(item[:inputs]['days_since_last_event']).to eq(120)
    end

    it 'is Needs Attention when the only OGO was published after reference_time' do
      obs = create(:observation, observer: person, company: organization)
      obs.update!(published_at: reference_time + 1.day)

      item = rows_for('ogo_given', level: 'item').first
      expect(item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(item[:inputs]['never']).to be(true)
    end

    it 'ignores goal check-ins updated after reference_time' do
      goal = create_goal(:active, owner: teammate, creator: teammate, started_at: reference_time - 30.days)
      goal.update_columns(created_at: reference_time - 40.days)
      old_check_in = create(:goal_check_in, goal: goal)
      old_check_in.update_column(:updated_at, reference_time - 10.days)
      new_check_in = create(:goal_check_in, goal: goal, check_in_week_start: 2.weeks.from_now.to_date.beginning_of_week(:monday))
      new_check_in.update_column(:updated_at, reference_time + 30.days)

      item = rows_for('goal_confidence', level: 'item').first
      expect(item[:inputs]['last_event_id']).to eq(old_check_in.id)
      expect(item[:status]).to eq(EngagementHealth::HEALTHY)
    end

    it 'excludes goals created after reference_time from the item set' do
      goal = create_goal(:active, owner: teammate, creator: teammate, started_at: reference_time - 10.days)
      goal.update_columns(created_at: reference_time + 1.day)

      expect(rows_for('goal_confidence', level: 'item')).to be_empty
    end

    it 'excludes goals started after reference_time from the item set' do
      goal = create_goal(:active, owner: teammate, creator: teammate, started_at: reference_time + 1.day)
      goal.update_columns(created_at: reference_time - 10.days)

      expect(rows_for('goal_confidence', level: 'item')).to be_empty
      expect(rollup_for('goal_confidence')[:inputs]['empty_reason']).to eq('never_started_or_completed_a_goal')
    end

    it 'ignores OGOs received published after reference_time' do
      observation = create(:observation, company: organization)
      observation.observees.destroy_all
      create(:observee, observation: observation, company_teammate: teammate)
      observation.update!(published_at: reference_time + 10.days)

      item = rows_for('ogo_received', level: 'item').first
      expect(item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(item[:inputs]['never']).to be(true)
    end

    context 'required clarity' do
      let!(:employment_tenure) do
        create(
          :employment_tenure,
          teammate: teammate,
          company: organization,
          started_at: reference_time - 1.year,
          ended_at: nil
        )
      end
      let!(:aspiration) { create(:aspiration, company: organization, created_at: reference_time - 1.year) }

      it 'ignores position check-ins finalized after reference_time' do
        check_in = create(:position_check_in, :closed, teammate: teammate, employment_tenure: employment_tenure)
        check_in.update_column(:official_check_in_completed_at, reference_time + 5.days)

        position_item = rows_for('required_clarity', level: 'item').find { |item| item[:entity_type] == 'Position' }
        expect(position_item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
        expect(position_item[:inputs]['never']).to be(true)
      end

      it 'omits position requirements when the teammate had no employment tenure at reference_time' do
        employment_tenure.update!(ended_at: reference_time - 10.days)

        items = rows_for('required_clarity', level: 'item')
        expect(items.map { |item| item[:entity_type] }).not_to include('Position')
        expect(items.map { |item| item[:entity_type] }).to include('Aspiration')
      end

      it 'excludes aspirations created after reference_time' do
        aspiration.update_column(:created_at, reference_time + 1.day)

        aspiration_items = rows_for('required_clarity', level: 'item').select { |item| item[:entity_type] == 'Aspiration' }
        expect(aspiration_items).to be_empty
      end
    end

    context 'milestones' do
      let!(:employment_tenure) do
        create(
          :employment_tenure,
          teammate: teammate,
          company: organization,
          started_at: reference_time - 1.year,
          ended_at: nil
        )
      end

      def require_ability(level: 2)
        ability = create(:ability, company: organization)
        create(:position_ability, position: employment_tenure.position, ability: ability, milestone_level: level)
        ability
      end

      it 'ignores milestones attained after reference_time' do
        ability = require_ability(level: 2)
        create(
          :teammate_milestone,
          company_teammate: teammate,
          ability: ability,
          milestone_level: 2,
          attained_at: reference_time + 5.days
        )

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      end

      it 'does not count goals created after reference_time when evaluating attached goals' do
        ability = require_ability
        goal = create_goal(:active, owner: teammate, creator: teammate)
        goal.update_columns(created_at: reference_time + 1.day, started_at: reference_time + 2.days)
        create(:goal_association, goal: goal, associable: ability)

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      end

      it 'treats goals not yet started at reference_time as draft attachments' do
        ability = require_ability
        goal = create_goal(:draft, owner: teammate, creator: teammate)
        goal.update_columns(created_at: reference_time - 10.days, started_at: nil)
        create(:goal_association, goal: goal, associable: ability)

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::AT_RISK)
        expect(item[:inputs]['reason']).to eq('draft_goal_attached')
      end

      it 'is vacuously Healthy when the teammate had no employment tenure at reference_time' do
        employment_tenure.update!(ended_at: reference_time - 10.days)
        require_ability

        expect(rows_for('milestones', level: 'item')).to be_empty
        expect(rollup_for('milestones')[:status]).to eq(EngagementHealth::HEALTHY)
      end
    end
  end

  describe 'goal confidence' do
    it 'is category Needs Attention when the teammate has never started or completed a goal' do
      create_goal(:draft, owner: teammate, creator: teammate) # drafts are not items

      rollup = rollup_for('goal_confidence')
      expect(rollup[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      expect(rollup[:inputs]['empty_reason']).to eq('never_started_or_completed_a_goal')
      expect(rows_for('goal_confidence', level: 'item')).to be_empty
    end

    it 'rates each started goal by days since its last confidence check' do
      fresh_goal = create_goal(:active, owner: teammate, creator: teammate)
      check_in = create(:goal_check_in, goal: fresh_goal)
      check_in.update_column(:updated_at, 5.days.ago)

      stale_goal = create_goal(:active, owner: teammate, creator: teammate)
      stale_check_in = create(:goal_check_in, goal: stale_goal, check_in_week_start: 10.weeks.ago.to_date.beginning_of_week(:monday))
      stale_check_in.update_column(:updated_at, 45.days.ago)

      never_goal = create_goal(:active, owner: teammate, creator: teammate)

      items = rows_for('goal_confidence', level: 'item')
      statuses = items.index_by { |item| item[:entity_id] }.transform_values { |item| item[:status] }
      expect(statuses[fresh_goal.id]).to eq(EngagementHealth::HEALTHY)
      expect(statuses[stale_goal.id]).to eq(EngagementHealth::AT_RISK)
      expect(statuses[never_goal.id]).to eq(EngagementHealth::NEEDS_ATTENTION)

      rollup = rollup_for('goal_confidence')
      expect(rollup[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      determining_ids = rollup[:inputs]['determined_by'].map { |d| d['entity_id'] }
      expect(determining_ids).to eq([never_goal.id])
    end

    it 'includes goals completed within 90 days and drops older completions' do
      recent_completed = create(:goal, owner: teammate, creator: teammate,
                                started_at: 100.days.ago, completed_at: 10.days.ago)
      old_completed = create(:goal, owner: teammate, creator: teammate,
                             started_at: 200.days.ago, completed_at: 120.days.ago)

      item_ids = rows_for('goal_confidence', level: 'item').map { |item| item[:entity_id] }
      expect(item_ids).to include(recent_completed.id)
      expect(item_ids).not_to include(old_completed.id)
    end
  end

  describe 'required clarity check-ins' do
    it 'is vacuously Healthy when there are zero required items' do
      rollup = rollup_for('required_clarity')
      expect(rollup[:status]).to eq(EngagementHealth::HEALTHY)
      expect(rollup[:inputs]['empty_reason']).to eq('no_required_items_vacuously_healthy')
    end

    context 'with a position and an aspiration' do
      let!(:employment_tenure) do
        create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      end
      let!(:aspiration) { create(:aspiration, company: organization) }

      it 'uses the stricter 60/90 window on finalized check-ins' do
        check_in = create(:position_check_in, :closed, teammate: teammate, employment_tenure: employment_tenure)
        check_in.update_column(:official_check_in_completed_at, 70.days.ago)

        items = rows_for('required_clarity', level: 'item')
        position_item = items.find { |item| item[:entity_type] == 'Position' }
        aspiration_item = items.find { |item| item[:entity_type] == 'Aspiration' }

        expect(position_item[:status]).to eq(EngagementHealth::AT_RISK)
        expect(position_item[:inputs]['healthy_within_days']).to eq(60)
        expect(aspiration_item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
        expect(aspiration_item[:inputs]['never']).to be(true)
        expect(rollup_for('required_clarity')[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      end

      it 'is Healthy when finalized within 60 days' do
        check_in = create(:position_check_in, :closed, teammate: teammate, employment_tenure: employment_tenure)
        check_in.update_column(:official_check_in_completed_at, 50.days.ago)

        position_item = rows_for('required_clarity', level: 'item').find { |item| item[:entity_type] == 'Position' }
        expect(position_item[:status]).to eq(EngagementHealth::HEALTHY)
      end
    end
  end

  describe 'milestones' do
    it 'is vacuously Healthy when there are no required abilities' do
      rollup = rollup_for('milestones')
      expect(rollup[:status]).to eq(EngagementHealth::HEALTHY)
      expect(rollup[:inputs]['empty_reason']).to eq('no_required_abilities_vacuously_healthy')
    end

    context 'with required abilities from the position' do
      let!(:employment_tenure) do
        create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      end

      def require_ability(level: 2)
        ability = create(:ability, company: organization)
        create(:position_ability, position: employment_tenure.position, ability: ability, milestone_level: level)
        ability
      end

      it 'is Healthy when the required milestone level is earned' do
        ability = require_ability(level: 2)
        create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 2)

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::HEALTHY)
        expect(item[:inputs]['reason']).to eq('earned_required_milestone')
      end

      it 'is Healthy when an active teammate-owned goal targets the ability' do
        ability = require_ability
        goal = create_goal(:active, owner: teammate, creator: teammate)
        create(:goal_association, goal: goal, associable: ability)

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::HEALTHY)
        expect(item[:inputs]['reason']).to eq('active_goal_attached')
      end

      it 'is At Risk when an earlier milestone is earned but not the required level' do
        ability = require_ability(level: 3)
        create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 1)

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::AT_RISK)
        expect(item[:inputs]['reason']).to eq('earlier_milestone_earned')
      end

      it 'is At Risk when only a draft goal is attached' do
        ability = require_ability
        goal = create_goal(:draft, owner: teammate, creator: teammate)
        create(:goal_association, goal: goal, associable: ability)

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::AT_RISK)
        expect(item[:inputs]['reason']).to eq('draft_goal_attached')
      end

      it 'is Needs Attention with no milestone and no active/draft goal (completed goals do not count)' do
        ability = require_ability
        goal = create_goal(:completed, owner: teammate, creator: teammate)
        create(:goal_association, goal: goal, associable: ability)

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
        expect(item[:inputs]['reason']).to eq('no_milestone_and_no_goal')
      end

      it 'ignores goals attached to the ability but owned by someone else' do
        ability = require_ability
        other_teammate = create(:company_teammate, organization: organization)
        goal = create_goal(:active, owner: other_teammate, creator: other_teammate)
        create(:goal_association, goal: goal, associable: ability)

        item = rows_for('milestones', level: 'item').find { |row| row[:entity_id] == ability.id }
        expect(item[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
      end
    end
  end

  describe 'rollup rule' do
    it 'worst status wins' do
      expect(EngagementHealth.worst_status(%w[healthy at_risk])).to eq('at_risk')
      expect(EngagementHealth.worst_status(%w[healthy at_risk needs_attention])).to eq('needs_attention')
      expect(EngagementHealth.worst_status(%w[healthy healthy])).to eq('healthy')
      expect(EngagementHealth.worst_status([])).to eq('healthy')
    end
  end
end
