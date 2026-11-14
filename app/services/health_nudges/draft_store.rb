# frozen_string_literal: true

module HealthNudges
  # Calendar-day sticky draft for Overall Health nudge (suggested + Consult OG).
  # Scoped to nudger person + org + manager filter.
  class DraftStore
    PREFERENCE_KEY_PREFIX = "protect_flow_nudge_draft_v1"

    def self.for(person:, organization:, manager_teammate:)
      new(person: person, organization: organization, manager_teammate: manager_teammate)
    end

    def initialize(person:, organization:, manager_teammate:)
      @person = person
      @organization = organization
      @manager_teammate = manager_teammate
      @prefs = UserPreference.for_person(person)
    end

    def today
      Date.current.iso8601
    end

    def read
      raw = @prefs.preferences[preference_key]
      data = raw.is_a?(Hash) ? raw.deep_stringify_keys : {}
      return blank_payload if data["date"] != today

      data
    end

    def ensure_suggested!(suggested_body)
      data = read
      if data["suggested_body"].blank?
        data = blank_payload.merge(
          "suggested_body" => suggested_body.to_s,
          "body" => suggested_body.to_s,
          "base" => BodySource::SUGGESTED
        )
        write!(data)
      elsif data["body"].blank?
        data["body"] = data["suggested_body"]
        write!(data)
      end
      data
    end

    def restore_suggested!
      data = read
      suggested = data["suggested_body"].to_s
      data["body"] = suggested
      data["base"] = BodySource::SUGGESTED
      write!(data)
      data
    end

    def restore_consultation!
      data = read
      og = data["og_consulted_body"].to_s
      return data if og.blank?

      data["body"] = og
      data["base"] = BodySource::OG_CONSULTED
      write!(data)
      data
    end

    def save_body!(body)
      data = read
      data["body"] = body.to_s
      write!(data)
      data
    end

    def record_consultation!(consultation_id:, og_consulted_body:)
      data = read
      data["og_consultation_id"] = consultation_id
      data["og_consulted_body"] = og_consulted_body.to_s
      data["body"] = og_consulted_body.to_s
      data["base"] = BodySource::OG_CONSULTED
      write!(data)
      data
    end

    def record_inflight_consultation!(consultation_id:)
      data = read
      data["og_consultation_id"] = consultation_id
      write!(data)
      data
    end

    private

    def preference_key
      "#{PREFERENCE_KEY_PREFIX}_org_#{@organization.id}_mgr_#{@manager_teammate.id}"
    end

    def blank_payload
      {
        "date" => today,
        "suggested_body" => "",
        "og_consulted_body" => "",
        "og_consultation_id" => nil,
        "body" => "",
        "base" => BodySource::SUGGESTED
      }
    end

    def write!(data)
      payload = data.stringify_keys.merge("date" => today)
      @prefs.update_preference(preference_key, payload)
      @prefs.reload
      payload
    end
  end
end
