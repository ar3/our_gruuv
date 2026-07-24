# frozen_string_literal: true

module MyGrowth
  # Celebratory completed-goals journey for Grow by Goals: milestone-path chart + list rows.
  # Outcomes: hit, hit_late, learning (stored miss reframed as learning).
  class CompletedGoalsJourney
    OUTCOME_META = {
      hit: {
        label: 'Hit',
        chart_name: 'Hit',
        color: '#198754',
        symbol: 'circle',
        badge_class: 'text-bg-success'
      },
      hit_late: {
        label: 'Hit (took longer)',
        chart_name: 'Hit (took longer)',
        color: '#0dcaf0',
        symbol: 'diamond',
        badge_class: 'text-bg-info'
      },
      learning: {
        label: 'Learning',
        chart_name: 'Learning',
        color: '#fd7e14',
        symbol: 'triangle',
        badge_class: 'text-bg-warning'
      }
    }.freeze

    Entry = Struct.new(
      :goal_id,
      :title,
      :completed_at,
      :outcome,
      :learnings,
      :path,
      keyword_init: true
    ) do
      def meta
        OUTCOME_META[outcome]
      end

      def label
        meta&.fetch(:label) || 'Completed'
      end

      def badge_class
        meta&.fetch(:badge_class) || 'text-bg-secondary'
      end

      def color
        meta&.fetch(:color) || '#6c757d'
      end

      def symbol
        meta&.fetch(:symbol) || 'circle'
      end
    end

    def self.build(organization:, teammate:, completed_in: nil)
      new(organization: organization, teammate: teammate, completed_in: completed_in).build
    end

    def initialize(organization:, teammate:, completed_in: nil)
      @organization = organization
      @teammate = teammate
      @completed_in = completed_in
    end

    def build
      entries = load_entries
      {
        entries: entries,
        chart_data: chart_data_for(entries),
        empty: entries.empty?
      }
    end

    private

    attr_reader :organization, :teammate, :completed_in

    def load_entries
      scope = Goal.where(company: organization, owner: teammate)
                  .completed
                  .where(deleted_at: nil)
                  .includes(:goal_check_ins)
                  .order(completed_at: :desc)

      scope = scope.where(completed_at: completed_in) if completed_in.present?

      scope.filter_map { |goal| entry_for(goal) }
    end

    def entry_for(goal)
      check_in = goal.goal_check_ins.max_by(&:check_in_week_start)
      Entry.new(
        goal_id: goal.id,
        title: goal.title,
        completed_at: goal.completed_at,
        outcome: outcome_for(goal, check_in),
        learnings: check_in&.confidence_reason.to_s.strip.presence,
        path: organization_goal_path(organization, goal)
      )
    end

    def outcome_for(goal, check_in)
      return nil unless check_in&.confidence_percentage

      case check_in.confidence_percentage
      when 100
        if goal.most_likely_target_date.present? && goal.completed_at.to_date > goal.most_likely_target_date
          :hit_late
        else
          :hit
        end
      when 0
        :learning
      end
    end

    def chart_data_for(entries)
      chronological = entries.reverse
      y_by_id = chronological.each_with_index.to_h { |entry, index| [entry.goal_id, path_y(index, chronological.length)] }

      path_points = chronological.map do |entry|
        { x: entry.completed_at.to_i * 1000, y: y_by_id[entry.goal_id] }
      end

      series = [
        {
          name: 'Journey',
          type: 'spline',
          data: path_points,
          color: '#ced4da',
          lineWidth: 3,
          marker: { enabled: false },
          showInLegend: false,
          enableMouseTracking: false,
          zIndex: 1
        }
      ]

      OUTCOME_META.each do |key, meta|
        points = chronological.select { |e| e.outcome == key }.map do |entry|
          point_payload(entry, y_by_id[entry.goal_id])
        end
        # Include outcomes with no points so the legend still explains the path.
        series << {
          name: meta[:chart_name],
          type: 'scatter',
          data: points,
          color: meta[:color],
          marker: { symbol: meta[:symbol], radius: 10, lineColor: '#ffffff', lineWidth: 2 },
          showInLegend: true,
          enableMouseTracking: true,
          zIndex: 2
        }
      end

      # Completions without a 0/100 final check-in still appear on the path.
      other = chronological.reject { |e| e.outcome.present? }.map do |entry|
        point_payload(entry, y_by_id[entry.goal_id])
      end
      if other.any?
        series << {
          name: 'Completed',
          type: 'scatter',
          data: other,
          color: '#6c757d',
          marker: { symbol: 'circle', radius: 9, lineColor: '#ffffff', lineWidth: 2 },
          showInLegend: true,
          zIndex: 2
        }
      end

      { series: series }
    end

    def point_payload(entry, y)
      {
        x: entry.completed_at.to_i * 1000,
        y: y,
        goalId: entry.goal_id,
        title: entry.title,
        outcomeLabel: entry.label,
        learnings: entry.learnings,
        url: entry.path
      }
    end

    # Gentle wave so the path feels like a trail, not a flat baseline.
    def path_y(index, total)
      return 1.0 if total <= 1

      1.0 + (0.35 * Math.sin((index.to_f / (total - 1)) * Math::PI * 2))
    end

    def organization_goal_path(organization, goal)
      Rails.application.routes.url_helpers.organization_goal_path(organization, goal)
    end
  end
end
