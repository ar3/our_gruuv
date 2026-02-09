# frozen_string_literal: true

module ObservableMoments
  class ObserveWorkAnniversariesService
    PAST_DAYS = 14

    def self.call(organization:)
      new(organization: organization).call
    end

    def initialize(organization:)
      @organization = organization
    end

    def call
      created = 0
      range_start = Date.current - PAST_DAYS.days
      range_end = Date.current

      candidates.each do |teammate|
        next if duplicate_exists?(teammate)

        anniversary_date = anniversary_date_in_window(teammate, range_start, range_end)
        next unless anniversary_date

        primary_observer = PrimaryPotentialObserverResolver.call(organization: organization, teammate: teammate)
        created_by_person = primary_observer.person

        result = BaseObservableMomentService.call(
          momentable: teammate,
          company: organization,
          created_by: created_by_person,
          primary_potential_observer: primary_observer,
          moment_type: :work_anniversary,
          occurred_at: anniversary_date.to_time,
          metadata: { anniversary_date: anniversary_date.iso8601 }
        )
        created += 1 if result.ok?
      end

      { created: created }
    end

    private

    attr_reader :organization

    def candidates
      organization.teammates
        .employed
        .where.not(first_employed_at: nil)
        .where(
          has_active_employment_tenure_sql,
          organization_id: organization.id
        )
        .distinct
    end

    def has_active_employment_tenure_sql
      <<~SQL.squish
        EXISTS (
          SELECT 1 FROM employment_tenures et
          WHERE et.teammate_id = teammates.id
            AND et.company_id = :organization_id
            AND et.ended_at IS NULL
        )
      SQL
    end

    def duplicate_exists?(teammate)
      ObservableMoment
        .where(
          company: organization,
          moment_type: :work_anniversary,
          momentable: teammate
        )
        .where('created_at >= ?', PAST_DAYS.days.ago)
        .exists?
    end

    def anniversary_date_in_window(teammate, range_start, range_end)
      return nil unless teammate.first_employed_at.present?

      month = teammate.first_employed_at.month
      day = teammate.first_employed_at.day

      [Date.current.year, Date.current.year - 1].each do |year|
        date = safe_date(year, month, day)
        return date if date && (range_start..range_end).cover?(date)
      end
      nil
    end

    def safe_date(year, month, day)
      Date.new(year, month, day)
    rescue ArgumentError
      nil
    end
  end
end
