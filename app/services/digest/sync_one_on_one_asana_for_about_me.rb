# frozen_string_literal: true

module Digest
  # Refreshes the employee's 1:1 Asana project cache before building the weekly About Me Slack digest.
  # Skips unless Asana is linked and has synced at least once. Does not update UI sync status fields.
  class SyncOneOnOneAsanaForAboutMe
    def self.call(employee_teammate:, manager_teammate: nil)
      new(employee_teammate: employee_teammate, manager_teammate: manager_teammate).call
    end

    def initialize(employee_teammate:, manager_teammate: nil)
      @employee_teammate = employee_teammate
      @manager_teammate = manager_teammate
    end

    def call
      link = @employee_teammate.one_on_one_link
      return skipped(:no_link) unless link
      return skipped(:not_asana) unless link.external_project_source == "asana"

      cache = link.external_project_cache_for("asana")
      return skipped(:never_synced) unless cache&.last_synced_at.present?

      sync_teammates = [@employee_teammate, @manager_teammate].compact.uniq(&:id)
      result = ExternalProject::PerformSync.call(
        cacheable: link,
        source: "asana",
        sync_teammates: sync_teammates,
        update_ui_status: false
      )

      if result[:success]
        Rails.logger.info(
          "Digest::SyncOneOnOneAsanaForAboutMe: synced 1:1 Asana for employee #{@employee_teammate.id} " \
          "using teammate #{result[:synced_by_teammate_id]}"
        )
        return { synced: true, synced_by_teammate_id: result[:synced_by_teammate_id] }
      end

      result[:errors]&.each do |error|
        Rails.logger.warn(
          "Digest::SyncOneOnOneAsanaForAboutMe: sync failed for employee #{@employee_teammate.id} " \
          "as teammate #{error[:teammate_id]}: #{error[:error]} (#{error[:error_type]})"
        )
      end

      { synced: false, errors: result[:errors] }
    end

    private

    def skipped(reason)
      { synced: false, skipped: reason }
    end
  end
end
