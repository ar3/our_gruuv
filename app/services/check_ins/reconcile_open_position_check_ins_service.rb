# frozen_string_literal: true

module CheckIns
  class ReconcileOpenPositionCheckInsService
    MERGEABLE_ATTRS = %w[
      employee_rating employee_private_notes employee_completed_at
      manager_rating manager_private_notes manager_completed_at manager_completed_by_teammate_id
    ].freeze

    def self.call(teammate:)
      new(teammate: teammate).call
    end

    def initialize(teammate:)
      @teammate = teammate
    end

    def call
      open_list = PositionCheckIn.where(company_teammate: @teammate).open.to_a
      return { merged: false, repointed: false, details: {} } if open_list.empty?

      active_tenure = @teammate.active_employment_tenure
      result = nil

      ApplicationRecord.transaction do
        if open_list.size > 1
          result = merge_open_check_ins!(open_list, active_tenure)
        elsif active_tenure && open_list.first.employment_tenure_id != active_tenure.id
          result = repoint_single!(open_list.first, active_tenure)
        else
          result = { merged: false, repointed: false, details: {} }
        end
      end
      result
    end

    private

    def merge_open_check_ins!(open_list, active_tenure)
      keeper = choose_keeper(open_list, active_tenure)
      others = open_list - [keeper]

      merged_attrs = build_merged_attributes(open_list)
      merged_attrs[:employment_tenure_id] = active_tenure.id if active_tenure

      previous_tenure_id = keeper.employment_tenure_id
      destroyed_ids = others.map(&:id)

      others.each(&:destroy!)
      keeper.update!(merged_attrs)

      result = {
        merged: true,
        repointed: active_tenure && previous_tenure_id != active_tenure.id,
        details: {
          teammate_id: @teammate.id,
          keeper_check_in_id: keeper.id,
          destroyed_check_in_ids: destroyed_ids,
          previous_employment_tenure_id: previous_tenure_id,
          employment_tenure_id: merged_attrs[:employment_tenure_id]
        }
      }
      report_correction_to_sentry(result)
      result
    end

    def repoint_single!(check_in, active_tenure)
      previous_tenure_id = check_in.employment_tenure_id
      check_in.update!(employment_tenure_id: active_tenure.id)
      result = {
        merged: false,
        repointed: true,
        details: {
          teammate_id: @teammate.id,
          keeper_check_in_id: check_in.id,
          previous_employment_tenure_id: previous_tenure_id,
          employment_tenure_id: active_tenure.id
        }
      }
      report_correction_to_sentry(result)
      result
    end

    def choose_keeper(open_list, active_tenure)
      if active_tenure
        on_active = open_list.find { |c| c.employment_tenure_id == active_tenure.id }
        return on_active if on_active
      end
      open_list.max_by(&:updated_at)
    end

    def build_merged_attributes(open_list)
      attrs = {}
      attrs[:check_in_started_on] = open_list.map(&:check_in_started_on).min

      MERGEABLE_ATTRS.each do |attr|
        records_with_value = open_list.select { |c| c.send(attr).present? }
        next if records_with_value.empty?

        chosen = records_with_value.max_by(&:updated_at)
        attrs[attr] = chosen.send(attr)
      end
      attrs
    end

    def report_correction_to_sentry(result)
      return unless result[:merged] || result[:repointed]

      Sentry.set_context("reconcile_open_position_check_ins", {
        teammate_id: result[:details][:teammate_id],
        merged: result[:merged],
        repointed: result[:repointed],
        keeper_check_in_id: result[:details][:keeper_check_in_id],
        previous_employment_tenure_id: result[:details][:previous_employment_tenure_id],
        employment_tenure_id: result[:details][:employment_tenure_id],
        destroyed_check_in_ids: result[:details][:destroyed_check_in_ids]
      }.compact)
      Sentry.capture_message(
        "Position check-in tenure correction: #{result[:merged] ? 'merged' : ''} #{result[:repointed] ? 'repointed' : ''} open check-in(s) for teammate #{result[:details][:teammate_id]}",
        level: :warning,
        extra: result[:details]
      )
    end
  end
end
