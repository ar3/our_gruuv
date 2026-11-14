# frozen_string_literal: true

module Insights
  # Builds last-week OGO announcement copy for Observations Insights (Slack-ready rehearsal).
  # Window is always the previous Monday–Sunday week, independent of Insights timeframe filters.
  class WeeklyOgoAnnouncement
    Result = Struct.new(
      :week_start,
      :week_end,
      :week_label,
      :total_count,
      :most_observed_assignment,
      :most_observed_ability,
      :most_observed_aspiration,
      :top_recognized,
      :top_givers,
      :sources,
      :message_text,
      keyword_init: true
    )

    NamedCount = Struct.new(:name, :count, keyword_init: true)
    SourceCount = Struct.new(:name, :count, :percent, keyword_init: true)

    def self.call(company:, now: Time.current)
      new(company: company, now: now).call
    end

    def self.previous_week_range(now: Time.current)
      week_start = now.in_time_zone.to_date.beginning_of_week(:monday) - 7.days
      week_end = week_start.end_of_week(:monday)
      week_start.beginning_of_day..week_end.end_of_day
    end

    def initialize(company:, now: Time.current)
      @company = company
      @now = now
      @range = self.class.previous_week_range(now: now)
      @week_start = @range.begin.to_date
      @week_end = @range.end.to_date
    end

    def call
      observations = week_observations.to_a
      total = observations.size
      assignment = most_observed_rateable("Assignment")
      ability = most_observed_rateable("Ability")
      aspiration = most_observed_rateable("Aspiration")
      recognized = top_positive_receivers
      givers = top_observers
      sources = source_breakdown(observations)
      message = build_message(
        total: total,
        assignment: assignment,
        ability: ability,
        aspiration: aspiration,
        recognized: recognized,
        givers: givers,
        sources: sources
      )

      Result.new(
        week_start: @week_start,
        week_end: @week_end,
        week_label: week_label,
        total_count: total,
        most_observed_assignment: assignment,
        most_observed_ability: ability,
        most_observed_aspiration: aspiration,
        top_recognized: recognized,
        top_givers: givers,
        sources: sources,
        message_text: message
      )
    end

    private

    def week_observations
      Observation.for_company(@company).not_soft_deleted.published.where(observed_at: @range)
    end

    def week_label
      "#{@week_start.strftime('%a %b %-d')} – #{@week_end.strftime('%a %b %-d, %Y')}"
    end

    def most_observed_rateable(rateable_type)
      row = week_observations
        .reorder(nil)
        .joins(:observation_ratings)
        .where(observation_ratings: { rateable_type: rateable_type })
        .group("observation_ratings.rateable_id")
        .order(Arel.sql("COUNT(DISTINCT observations.id) DESC"))
        .limit(1)
        .pluck("observation_ratings.rateable_id", Arel.sql("COUNT(DISTINCT observations.id)"))
        .first
      return nil unless row

      rateable_id, count = row
      rateable = rateable_type.constantize.find_by(id: rateable_id)
      return nil unless rateable

      NamedCount.new(name: rateable_label(rateable), count: count)
    end

    def rateable_label(rateable)
      case rateable
      when Assignment then rateable.title
      when Ability, Aspiration then rateable.name
      else rateable.try(:display_name) || rateable.to_s
      end
    end

    def top_positive_receivers
      rows = Observee
        .joins(:company_teammate)
        .joins(observation: :observation_ratings)
        .merge(ObservationRating.positive)
        .where(observations: { company_id: @company.id, deleted_at: nil })
        .where.not(observations: { published_at: nil })
        .where(observations: { observed_at: @range })
        .group("teammates.person_id")
        .order(Arel.sql("COUNT(DISTINCT observees.observation_id) DESC"))
        .limit(3)
        .pluck("teammates.person_id", Arel.sql("COUNT(DISTINCT observees.observation_id)"))

      people_by_id = Person.where(id: rows.map(&:first)).index_by(&:id)
      rows.filter_map do |person_id, count|
        person = people_by_id[person_id]
        next unless person

        NamedCount.new(name: person.casual_name.presence || person.display_name, count: count)
      end
    end

    def top_observers
      rows = week_observations
        .reorder(nil)
        .group(:observer_id)
        .order(Arel.sql("COUNT(observations.id) DESC"))
        .limit(3)
        .pluck(:observer_id, Arel.sql("COUNT(observations.id)"))

      people_by_id = Person.where(id: rows.map(&:first)).index_by(&:id)
      rows.filter_map do |person_id, count|
        person = people_by_id[person_id]
        next unless person

        NamedCount.new(name: person.casual_name.presence || person.display_name, count: count)
      end
    end

    def source_breakdown(observations)
      sourcing = ObservationsSourcingChart.call(observations)
      total = sourcing[:total]
      sourcing[:pie].map do |point|
        pct = total.positive? ? ((point[:y].to_f / total) * 100).round : 0
        SourceCount.new(name: point[:name], count: point[:y], percent: pct)
      end
    end

    def build_message(total:, assignment:, ability:, aspiration:, recognized:, givers:, sources:)
      lines = []
      lines << "*Last week's OGOs (#{week_label})*"
      lines << ""
      if total.zero?
        lines << "Quiet week — no published OGOs. Every story helps the organization grow because people get feedback about what's best. Notice something working this week? Add an OGO."
        return lines.join("\n")
      end

      lines << "We captured *#{total}* observation #{'story'.pluralize(total)} last week. Keep noticing what's best — every story helps the organization grow."
      lines << ""
      lines << "*What we noticed most*"
      lines.concat(object_lines(assignment: assignment, ability: ability, aspiration: aspiration))
      lines << ""
      lines << "*Teammates recognized (positive OGOs received)*"
      lines.concat(ranked_people_lines(recognized, empty: "_No positive OGOs received last week._"))
      lines << ""
      lines << "*Teammates who gave the most OGOs*"
      lines.concat(ranked_people_lines(givers, empty: "_No OGOs given last week._"))
      lines << ""
      lines << "*Where OGOs came from*"
      if sources.empty?
        lines << "_No source data._"
      else
        sources.each do |source|
          lines << "• #{source.name}: #{source.count} (#{source.percent}%)"
        end
      end
      lines << ""
      lines << "Saw something worth celebrating? Add an OGO in OurGruuv."
      lines.join("\n")
    end

    def object_lines(assignment:, ability:, aspiration:)
      rows = [
        ["Assignment", assignment],
        ["Value", aspiration],
        ["Ability", ability]
      ]
      present = rows.select { |_label, item| item.present? }
      return ["_Nothing rated on assignments, values, or abilities last week._"] if present.empty?

      present.map { |label, item| "• #{label}: *#{item.name}* (#{item.count} #{'OGO'.pluralize(item.count)})" }
    end

    def ranked_people_lines(people, empty:)
      return [empty] if people.empty?

      people.each_with_index.map do |person, index|
        "#{index + 1}. *#{person.name}* (#{person.count})"
      end
    end
  end
end
