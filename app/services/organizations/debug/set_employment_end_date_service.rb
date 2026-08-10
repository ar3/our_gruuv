# frozen_string_literal: true

module Organizations
  module Debug
    # Apply an employment end date from the Debug page for a single teammate.
    # Updates the most recent employment tenure's ended_at and teammate last_terminated_at
    # (when no active tenure remains). Active last tenures go through TerminateEmploymentService
    # so assignment tenures and MAAP snapshot stay consistent.
    class SetEmploymentEndDateService
      def self.call(organization:, teammate:, end_date:, created_by:)
        new(
          organization: organization,
          teammate: teammate,
          end_date: end_date,
          created_by: created_by
        ).call
      end

      def initialize(organization:, teammate:, end_date:, created_by:)
        @organization = organization
        @teammate = teammate
        @end_date = end_date
        @created_by = created_by
      end

      def call
        return Result.err("Teammate is required") unless teammate
        return Result.err("Teammate is not in this organization") unless teammate.organization_id == organization.id
        return Result.err("End date is required") if end_date.blank?

        tenure = last_employment_tenure
        return Result.err("No employment tenure found for this teammate") unless tenure

        parsed_date = parse_end_date(end_date)

        if tenure.active?
          TerminateEmploymentService.call(
            teammate: teammate,
            current_tenure: tenure,
            termination_date: parsed_date,
            created_by: created_by,
            reason: "Debug: set employment end date"
          )
        else
          update_already_ended_tenure(tenure, parsed_date)
        end
      rescue ArgumentError => e
        Result.err("Invalid end date: #{e.message}")
      rescue ActiveRecord::RecordInvalid => e
        Result.err(e.record.errors.full_messages.join(", "))
      rescue StandardError => e
        Result.err("Failed to set employment end date: #{e.message}")
      end

      def self.default_end_date_for(teammate, organization)
        tenure = teammate.employment_tenures
          .where(company: organization)
          .order(started_at: :desc, id: :desc)
          .first
        return Date.current unless tenure

        tenure.ended_at&.to_date || tenure.started_at&.to_date || Date.current
      end

      def self.last_employment_tenure_for(teammate, organization)
        teammate.employment_tenures
          .where(company: organization)
          .order(started_at: :desc, id: :desc)
          .first
      end

      private

      attr_reader :organization, :teammate, :end_date, :created_by

      def last_employment_tenure
        self.class.last_employment_tenure_for(teammate, organization)
      end

      def update_already_ended_tenure(tenure, parsed_date)
        ApplicationRecord.transaction do
          end_time = tenure.effective_end_time(parsed_date.to_time)
          tenure.update!(ended_at: end_time)

          if teammate.employment_tenures.active.exists?
            # Still employed elsewhere; clear a stale terminated flag if present
            if teammate.last_terminated_at.present?
              teammate.update!(last_terminated_at: nil)
            end
          else
            teammate.update!(last_terminated_at: parsed_date)
          end

          # Fill blank first_employed_at if needed; do not overwrite explicit last_terminated_at
          sync_first_employed_only!

          Result.ok(tenure: tenure.reload, teammate: teammate.reload)
        end
      end

      def sync_first_employed_only!
        tenures = teammate.employment_tenures
        return unless tenures.exists?
        return if teammate.first_employed_at.present?

        earliest = tenures.minimum(:started_at)&.to_date
        teammate.update!(first_employed_at: earliest) if earliest
      end

      def parse_end_date(date_param)
        if date_param.is_a?(Date)
          date_param
        elsif date_param.is_a?(Time) || date_param.is_a?(DateTime)
          date_param.to_date
        elsif date_param.is_a?(String)
          date_str = date_param.strip
          if date_str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
            Date.strptime(date_str, "%Y-%m-%d")
          else
            Date.parse(date_str)
          end
        else
          Date.parse(date_param.to_s)
        end
      end
    end
  end
end
