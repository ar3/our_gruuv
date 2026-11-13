# frozen_string_literal: true

module Digest
  # One-time admin action: turn a digest preference on for employed teammates who have
  # never manually toggled it (no *_explicitly_set flag) and do not already have it on.
  class BulkEnablePreference
    KINDS = {
      'gsd' => {
        digest_key: 'gsd_digest_enabled',
        label: 'Get Shit Done'
      },
      'interesting_things' => {
        digest_key: 'interesting_things_digest_enabled',
        label: 'Interesting Things'
      },
      'one_on_one' => {
        digest_key: 'one_on_one_digest_enabled',
        label: '1:1 guide',
        default_weekly_day: '1' # Monday
      }
    }.freeze

    Result = Struct.new(:kind, :label, :digest_key, :eligible_count, :enabled_count, keyword_init: true)

    def self.kind_config(kind)
      KINDS[kind.to_s]
    end

    def self.eligible_counts(company:)
      prefs_by_person_id = preferences_by_person_id(company)
      KINDS.keys.index_with do |kind|
        new(company: company, kind: kind, prefs_by_person_id: prefs_by_person_id).eligible_count
      end
    end

    def self.call(company:, kind:)
      new(company: company, kind: kind).call
    end

    def self.preferences_by_person_id(company)
      person_ids = CompanyTeammate.where(organization: company).employed.pluck(:person_id).uniq
      UserPreference.where(person_id: person_ids).index_by(&:person_id)
    end

    def initialize(company:, kind:, prefs_by_person_id: nil)
      @company = company
      @kind = kind.to_s
      @config = self.class.kind_config(@kind)
      raise ArgumentError, "Unknown digest kind: #{kind}" if @config.nil?

      @prefs_by_person_id = prefs_by_person_id
    end

    def eligible_count
      eligible_teammates.size
    end

    def call
      enabled = 0
      eligible_teammates.each do |teammate|
        prefs = prefs_for(teammate)
        next unless prefs.eligible_for_bulk_digest_enable?(digest_key)

        updates = { digest_key => 'on' }
        if default_weekly_day && !valid_weekly_day?(prefs.preference(:about_me_weekly_day))
          updates['about_me_weekly_day'] = default_weekly_day
        end
        prefs.preferences = prefs.preferences.merge(updates)
        prefs.save!
        enabled += 1
      end

      Result.new(
        kind: kind,
        label: label,
        digest_key: digest_key,
        eligible_count: enabled,
        enabled_count: enabled
      )
    end

    private

    attr_reader :company, :kind, :config

    def digest_key
      config[:digest_key]
    end

    def label
      config[:label]
    end

    def default_weekly_day
      config[:default_weekly_day]
    end

    def employed_teammates
      @employed_teammates ||= CompanyTeammate.where(organization: company).employed.includes(:person)
    end

    def prefs_by_person_id
      @prefs_by_person_id ||= self.class.preferences_by_person_id(company)
    end

    def prefs_for(teammate)
      prefs_by_person_id[teammate.person_id] || UserPreference.for_person(teammate.person)
    end

    def eligible_teammates
      employed_teammates.select do |teammate|
        prefs_for(teammate).eligible_for_bulk_digest_enable?(digest_key)
      end
    end

    def valid_weekly_day?(value)
      value.to_s.match?(/\A[0-6]\z/)
    end
  end
end
