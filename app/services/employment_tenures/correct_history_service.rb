# frozen_string_literal: true

module EmploymentTenures
  # Silent employment-history corrections for manage_employment users.
  # Does not create observable moments, maap snapshots, or notifications.
  class CorrectHistoryService
    def self.update_tenure(teammate:, tenure:, attrs:)
      new(teammate: teammate).update_tenure(tenure: tenure, attrs: attrs)
    end

    def self.prepend(teammate:, attrs:)
      new(teammate: teammate).prepend(attrs: attrs)
    end

    def self.connect_gap(teammate:, earlier_tenure:, later_tenure:)
      new(teammate: teammate).connect_gap(earlier_tenure: earlier_tenure, later_tenure: later_tenure)
    end

    def initialize(teammate:)
      @teammate = teammate
      @company = teammate.organization
    end

    def update_tenure(tenure:, attrs:)
      return Result.err('Tenure does not belong to this teammate') unless tenure.teammate_id == teammate.id
      return Result.err('Tenure company mismatch') unless tenure.company_id == company.id

      adjustments = []

      ApplicationRecord.transaction do
        apply_attrs!(tenure, attrs)
        tenure.save!
        adjustments.concat(resolve_overlaps!(winner: tenure))
        sync_employment_state!
      end

      Result.ok(tenure: tenure, adjustments: adjustments)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(', '))
    rescue StandardError => e
      Result.err(e.message)
    end

    def prepend(attrs:)
      earliest = company_tenures.order(:started_at).first
      started_at = parse_time(attrs[:started_at])
      ended_at = parse_time(attrs[:ended_at])

      return Result.err('Start date is required') if started_at.blank?

      if earliest
        return Result.err('Prepended tenure must start before the current earliest tenure') if started_at >= earliest.started_at
        if ended_at.blank?
          return Result.err('End date is required when other tenures exist (set it to when this stretch ended)')
        end
      end

      tenure = teammate.employment_tenures.build(
        company: company,
        position_id: attrs[:position_id],
        manager_teammate_id: blank_to_nil(attrs[:manager_teammate_id]),
        started_at: started_at,
        ended_at: ended_at,
        employment_change_notes: attrs[:employment_change_notes]
      )

      adjustments = []

      ApplicationRecord.transaction do
        tenure.save!
        adjustments.concat(resolve_overlaps!(winner: tenure))
        sync_employment_state!
      end

      Result.ok(tenure: tenure, adjustments: adjustments)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(', '))
    rescue StandardError => e
      Result.err(e.message)
    end

    def connect_gap(earlier_tenure:, later_tenure:)
      return Result.err('Invalid tenure pair') unless earlier_tenure && later_tenure
      return Result.err('Tenures must belong to this teammate') unless earlier_tenure.teammate_id == teammate.id && later_tenure.teammate_id == teammate.id
      return Result.err('Earlier tenure must start before later tenure') if earlier_tenure.started_at >= later_tenure.started_at
      return Result.err('Earlier tenure has no end date') if earlier_tenure.ended_at.nil?
      return Result.err('No gap between these tenures') if later_tenure.started_at <= earlier_tenure.ended_at

      ApplicationRecord.transaction do
        earlier_tenure.update!(ended_at: later_tenure.started_at)
        sync_employment_state!
      end

      Result.ok(
        tenure: earlier_tenure,
        adjustments: [
          "Connected tenures: set earlier tenure end to #{format_stamp(later_tenure.started_at)} so employment is continuous."
        ]
      )
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages.join(', '))
    rescue StandardError => e
      Result.err(e.message)
    end

    private

    attr_reader :teammate, :company

    def company_tenures
      teammate.employment_tenures.where(company: company)
    end

    def apply_attrs!(tenure, attrs)
      tenure.position_id = attrs[:position_id] if attrs.key?(:position_id)
      if attrs.key?(:manager_teammate_id)
        tenure.manager_teammate_id = blank_to_nil(attrs[:manager_teammate_id])
      end
      tenure.started_at = parse_time(attrs[:started_at]) if attrs.key?(:started_at) && attrs[:started_at].present?
      if attrs.key?(:ended_at)
        tenure.ended_at = attrs[:ended_at].present? ? parse_time(attrs[:ended_at]) : nil
      end
      if attrs.key?(:employment_change_notes)
        tenure.employment_change_notes = attrs[:employment_change_notes]
      end
    end

    def resolve_overlaps!(winner:)
      adjustments = []
      open_end = Time.zone.parse('9999-12-31')

      company_tenures.where.not(id: winner.id).order(:started_at).find_each do |other|
        winner_end = winner.ended_at || open_end
        other_end = other.ended_at || open_end
        next unless winner.started_at < other_end && other.started_at < winner_end

        if other.started_at < winner.started_at
          new_end = winner.started_at
          if other.started_at >= new_end
            raise StandardError, "Cannot resolve overlap: adjusting tenure ##{other.id} would remove it. Narrow the saved tenure or fix dates manually."
          end
          if other.ended_at != new_end
            other.update!(ended_at: new_end)
            adjustments << "Adjusted tenure ##{other.id} end date to #{format_stamp(new_end)} (saved tenure wins)."
          end
        else
          if winner.ended_at.nil?
            raise StandardError, "Open tenure overlaps a later tenure (##{other.id}). Set an end date on the saved tenure, or adjust the later tenure first."
          end

          new_start = winner.ended_at
          if other.ended_at.present? && other.ended_at <= new_start
            raise StandardError, "Cannot resolve overlap: adjusting tenure ##{other.id} start would invalidate its end date."
          end
          if other.started_at != new_start
            other.update!(started_at: new_start)
            adjustments << "Adjusted tenure ##{other.id} start date to #{format_stamp(new_start)} (saved tenure wins)."
          end
        end
      end

      adjustments
    end

    def sync_employment_state!
      earliest = teammate.employment_tenures.minimum(:started_at)&.to_date
      active = teammate.employment_tenures.active.exists?
      latest_ended = teammate.employment_tenures.where.not(ended_at: nil).maximum(:ended_at)&.to_date

      teammate.update!(
        first_employed_at: earliest,
        last_terminated_at: active ? nil : latest_ended
      )
    end

    def parse_time(value)
      return nil if value.blank?
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return value.to_time if value.is_a?(Date)

      Time.zone.parse(value.to_s)
    end

    def blank_to_nil(value)
      value.present? ? value : nil
    end

    def format_stamp(time)
      time.in_time_zone.to_date.iso8601
    end
  end
end
