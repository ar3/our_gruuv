# frozen_string_literal: true

module Organizations
  module Debug
    # Read-only integrity findings for the org Debug page.
    # Returns structured sections with resolve notes and row data (links built in the view).
    class IntegrityReportService
      Section = Data.define(
        :key,
        :title,
        :resolve_note,
        :heals_nightly,
        :slack_required,
        :items
      )

      def self.call(organization:, slack_users_provider: nil)
        new(organization: organization, slack_users_provider: slack_users_provider).call
      end

      def initialize(organization:, slack_users_provider: nil)
        @organization = organization
        @slack_users_provider = slack_users_provider
      end

      def call
        {
          slack_configured: slack_configured?,
          sections: [
            active_assignments_without_employment_section,
            archived_with_open_check_ins_section,
            teammates_without_slack_section,
            slack_without_teammate_section,
            multiple_open_position_check_ins_section,
            position_check_in_wrong_tenure_section,
            employment_state_drift_section
          ]
        }
      end

      private

      attr_reader :organization

      def teammate_ids
        @teammate_ids ||= organization.teammates.select(:id)
      end

      def slack_configured?
        organization.slack_configured?
      end

      def active_employee_teammate_ids
        @active_employee_teammate_ids ||= EmploymentTenure
          .active
          .where(company: organization)
          .select(:teammate_id)
      end

      def active_assignments_without_employment_section
        tenures = AssignmentTenure
          .active
          .joins(:assignment, :company_teammate)
          .where(assignments: { company_id: organization.id })
          .where.not(teammate_id: active_employee_teammate_ids)
          .includes(:assignment, company_teammate: :person)
          .order("people.last_name, people.first_name")

        by_teammate = tenures.group_by(&:company_teammate)

        items = by_teammate.map do |teammate, tenure_list|
          {
            kind: :active_assignments_without_employment,
            teammate: teammate,
            assignment_titles: tenure_list.map { |t| t.assignment.title }.uniq.sort,
            count: tenure_list.size
          }
        end

        Section.new(
          key: :active_assignments_without_employment,
          title: "Active assignment tenures without active employment",
          resolve_note: "Someone left employment (or never had an active tenure) but still has open assignment tenures. Close those tenures on the teammate’s assignment management page.",
          heals_nightly: false,
          slack_required: false,
          items: items
        )
      end

      def archived_with_open_check_ins_section
        items = []

        AssignmentCheckIn
          .open
          .joins(:assignment, :company_teammate)
          .where(assignments: { company_id: organization.id })
          .where.not(assignments: { deleted_at: nil })
          .includes(:assignment, company_teammate: :person)
          .find_each do |check_in|
            items << {
              kind: :archived_assignment_open_check_in,
              check_in: check_in,
              record_type: "Assignment",
              record_title: check_in.assignment.title,
              teammate: check_in.company_teammate
            }
          end

        AspirationCheckIn
          .open
          .where(teammate_id: teammate_ids)
          .where(
            aspiration_id: Aspiration.with_deleted
              .where.not(deleted_at: nil)
              .where(company_id: organization.id)
              .select(:id)
          )
          .includes(company_teammate: :person)
          .find_each do |check_in|
            aspiration = Aspiration.with_deleted.find_by(id: check_in.aspiration_id)
            next unless aspiration

            items << {
              kind: :archived_aspiration_open_check_in,
              check_in: check_in,
              record_type: "Aspiration",
              record_title: aspiration.name,
              teammate: check_in.company_teammate,
              aspiration: aspiration
            }
          end

        PositionCheckIn
          .open
          .joins(employment_tenure: :position)
          .where(teammate_id: teammate_ids)
          .where.not(positions: { deleted_at: nil })
          .includes(:company_teammate, employment_tenure: { position: :title })
          .find_each do |check_in|
            position = check_in.employment_tenure.position
            items << {
              kind: :archived_position_open_check_in,
              check_in: check_in,
              record_type: "Position",
              record_title: position.display_name,
              teammate: check_in.company_teammate
            }
          end

        Section.new(
          key: :archived_with_open_check_ins,
          title: "Archived MAAP records with open check-ins",
          resolve_note: "An assignment, aspiration, or position is archived but still has an open check-in. For assignments, archiving now system-closes opens; older leftovers need a human to finish or delete the open check-in via the teammate’s check-in flow. Aspiration/position leftovers need a check-in or tenure fix.",
          heals_nightly: false,
          slack_required: false,
          items: items
        )
      end

      def teammates_without_slack_section
        return slack_not_configured_section(
          key: :teammates_without_slack,
          title: "Teammates without a Slack identity"
        ) unless slack_configured?

        teammates = organization.teammates
          .where(last_terminated_at: nil)
          .joins(:person)
          .includes(:person, :teammate_identities)
          .order("people.last_name, people.first_name")
          .to_a
          .reject(&:has_slack_identity?)

        items = teammates.map do |teammate|
          {
            kind: :teammate_without_slack,
            teammate: teammate
          }
        end

        Section.new(
          key: :teammates_without_slack,
          title: "Teammates without a Slack identity",
          resolve_note: "Link each person on the Slack teammate associations page so digests and DMs can reach them.",
          heals_nightly: false,
          slack_required: true,
          items: items
        )
      end

      def slack_without_teammate_section
        return slack_not_configured_section(
          key: :slack_without_teammate,
          title: "Slack users without a teammate"
        ) unless slack_configured?

        linked_uids = TeammateIdentity
          .slack
          .where(teammate_id: teammate_ids)
          .pluck(:uid)
          .to_set

        users = slack_users.reject do |user|
          user["deleted"] ||
            user["is_bot"] ||
            user["id"] == "USLACKBOT" ||
            linked_uids.include?(user["id"])
        end

        items = users.map do |user|
          name = user.dig("profile", "real_name").presence ||
                 user.dig("profile", "display_name").presence ||
                 user["name"]
          {
            kind: :slack_without_teammate,
            slack_user_id: user["id"],
            name: name,
            email: user.dig("profile", "email")
          }
        end

        Section.new(
          key: :slack_without_teammate,
          title: "Slack users without a teammate",
          resolve_note: "Workspace members not linked to a company teammate. Associate them on the Slack teammate associations page (or leave unlinked if they are bots/contractors you do not track).",
          heals_nightly: false,
          slack_required: true,
          items: items
        )
      end

      def multiple_open_position_check_ins_section
        counts = PositionCheckIn
          .open
          .where(teammate_id: teammate_ids)
          .group(:teammate_id)
          .having("COUNT(*) > 1")
          .count

        teammates_by_id = CompanyTeammate
          .where(id: counts.keys)
          .includes(:person)
          .index_by(&:id)

        items = counts.map do |teammate_id, count|
          {
            kind: :multiple_open_position_check_ins,
            teammate: teammates_by_id[teammate_id],
            count: count
          }
        end.compact

        Section.new(
          key: :multiple_open_position_check_ins,
          title: "Multiple open position check-ins",
          resolve_note: "A teammate has more than one open position check-in. Daily operational cleanup merges them (ReconcileOpenPositionCheckIns).",
          heals_nightly: true,
          slack_required: false,
          items: items
        )
      end

      def position_check_in_wrong_tenure_section
        open_check_ins = PositionCheckIn
          .open
          .where(teammate_id: teammate_ids)
          .includes(:company_teammate, :employment_tenure)

        active_tenures_by_teammate = EmploymentTenure
          .active
          .where(company: organization, teammate_id: teammate_ids)
          .index_by(&:teammate_id)

        items = open_check_ins.filter_map do |check_in|
          active = active_tenures_by_teammate[check_in.teammate_id]
          next unless active
          next if check_in.employment_tenure_id == active.id

          {
            kind: :position_check_in_wrong_tenure,
            teammate: check_in.company_teammate,
            check_in: check_in,
            open_employment_tenure_id: check_in.employment_tenure_id,
            active_employment_tenure_id: active.id
          }
        end

        Section.new(
          key: :position_check_in_wrong_tenure,
          title: "Open position check-in on a stale employment tenure",
          resolve_note: "The open position check-in points at an old employment tenure while a different tenure is active. Daily operational cleanup repoints it.",
          heals_nightly: true,
          slack_required: false,
          items: items
        )
      end

      def employment_state_drift_section
        teammates = organization.teammates.includes(:employment_tenures, :person)
        items = teammates.filter_map do |teammate|
          preview = EmploymentStateConsistencyService.preview(teammate: teammate)
          next unless preview.ok?
          next if preview.value[:changed_fields].empty?

          {
            kind: :employment_state_drift,
            teammate: teammate,
            changed_fields: preview.value[:changed_fields],
            desired: preview.value[:attributes]
          }
        end

        Section.new(
          key: :employment_state_drift,
          title: "Employment state fields out of sync with tenures",
          resolve_note: "first_employed_at / last_terminated_at do not match tenure reality. Daily operational cleanup runs EmploymentStateReconciliation and corrects these.",
          heals_nightly: true,
          slack_required: false,
          items: items
        )
      end

      def slack_not_configured_section(key:, title:)
        Section.new(
          key: key,
          title: title,
          resolve_note: "Slack is not configured for this organization. Connect Slack under Slack Settings to enable this check.",
          heals_nightly: false,
          slack_required: true,
          items: []
        )
      end

      def slack_users
        return @slack_users if defined?(@slack_users)

        @slack_users =
          if @slack_users_provider
            Array(@slack_users_provider.call)
          elsif slack_configured?
            begin
              SlackService.new(organization).list_users
            rescue StandardError => e
              Rails.logger.error("IntegrityReportService: list_users failed: #{e.message}")
              []
            end
          else
            []
          end
      end
    end
  end
end
