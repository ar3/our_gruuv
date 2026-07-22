# frozen_string_literal: true

module ProtectFlow
  # Manager-scoped weekly EH baselines on UserPreference.
  # Opens the current week on first visit; closes any prior open week with an
  # end-state snapshot so history can be browsed read-only.
  class WeekSnapshotStore
    PREFERENCE_KEY_PREFIX = "protect_flow_weeks_v1_org_"

    def self.for(person:, organization:)
      new(person: person, organization: organization)
    end

    def initialize(person:, organization:)
      @person = person
      @organization = organization
      @prefs = UserPreference.for_person(person)
    end

    def current_week_start
      Date.current.beginning_of_week(:monday).iso8601
    end

    # Ensures the current week has a start baseline. Closes any other open week
    # using +live_baseline+ as that week's end state.
    def ensure_current_week!(live_baseline:)
      week_start = current_week_start
      weeks = weeks_hash
      open_weeks = weeks.select { |_k, w| w["closed"] != true && w["week_start"] != week_start }

      open_weeks.each_key do |key|
        weeks[key] = weeks[key].merge(
          "closed" => true,
          "end_baseline" => live_baseline,
          "closed_at" => Time.current.iso8601
        )
      end

      unless weeks[week_start].is_a?(Hash) && weeks[week_start]["start_baseline"].is_a?(Hash)
        weeks[week_start] = {
          "week_start" => week_start,
          "closed" => false,
          "start_baseline" => live_baseline,
          "end_baseline" => nil,
          "opened_at" => Time.current.iso8601
        }
      end

      write_weeks!(weeks)
      week_payload(weeks[week_start])
    end

    def find_week(week_start)
      key = week_start.to_s
      raw = weeks_hash[key]
      return nil unless raw.is_a?(Hash) && raw["start_baseline"].is_a?(Hash)

      week_payload(raw)
    end

    def available_weeks
      weeks_hash.values
        .select { |w| w.is_a?(Hash) && w["start_baseline"].is_a?(Hash) }
        .map { |w| week_payload(w) }
        .sort_by { |w| w[:week_start] }
        .reverse
    end

    private

    def preference_key
      "#{PREFERENCE_KEY_PREFIX}#{@organization.id}"
    end

    def weeks_hash
      raw = @prefs.preferences[preference_key]
      container = raw.is_a?(Hash) ? raw.deep_stringify_keys : {}
      weeks = container["weeks"]
      weeks.is_a?(Hash) ? weeks.deep_stringify_keys : {}
    end

    def write_weeks!(weeks)
      @prefs.update_preference(preference_key, { "weeks" => weeks })
      @prefs.reload
    end

    def week_payload(raw)
      {
        week_start: raw["week_start"].to_s,
        closed: raw["closed"] == true,
        start_baseline: stringify_baseline(raw["start_baseline"]),
        end_baseline: stringify_baseline(raw["end_baseline"])
      }
    end

    def stringify_baseline(baseline)
      return {} unless baseline.is_a?(Hash)

      baseline.deep_stringify_keys
    end
  end
end
