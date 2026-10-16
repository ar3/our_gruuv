# frozen_string_literal: true

module MilestoneAwards
  # Opt-grouped co-signer candidates for an award in progress.
  # Order: ability maintainers → same-dept managers → any manager → higher milestone → everyone else.
  class CosignCandidatesQuery
    Group = Data.define(:key, :label, :teammates)

    def self.call(...) = new(...).call

    def initialize(organization:, recipient:, awarder:, ability:, official_level:)
      @organization = organization
      @recipient = recipient
      @awarder = awarder
      @ability = ability
      @official_level = official_level.to_i
    end

    def call
      pool = CompanyTeammate
        .where(organization: @organization, last_terminated_at: nil)
        .where.not(id: [@recipient.id, @awarder.id])
        .includes(:person, :employment_tenures)
        .to_a

      claimed = Set.new
      groups = []

      [
        [:ability_maintainers, "Ability maintainers", method(:ability_maintainers)],
        [:same_dept_managers, "Managers in the same department", method(:same_dept_managers)],
        [:any_managers, "Other managers", method(:any_managers)],
        [:higher_milestone, "Teammates with a higher milestone", method(:higher_milestone_teammates)],
        [:everyone_else, "Everyone else", ->(p) { p }]
      ].each do |key, label, selector|
        selected = Array(selector.call(pool)).reject { |t| claimed.include?(t.id) }
        next if selected.empty?

        selected.each { |t| claimed << t.id }
        groups << Group.new(key: key, label: label, teammates: selected.sort_by { |t| t.person.display_name.to_s })
      end

      groups
    end

    private

    def ability_maintainers(pool)
      maintainer_ids = @ability.maintainers.pluck(:id).to_set
      pool.select { |t| maintainer_ids.include?(t.id) }
    end

    def same_dept_managers(pool)
      dept_id = recipient_department_id
      return [] if dept_id.blank?

      pool.select { |t| manager?(t) && department_id_for(t) == dept_id }
    end

    def any_managers(pool)
      pool.select { |t| manager?(t) }
    end

    def higher_milestone_teammates(pool)
      higher_ids = TeammateMilestone
        .where(ability_id: @ability.id)
        .where("milestone_level > ?", @official_level)
        .where(teammate_id: pool.map(&:id))
        .pluck(:teammate_id)
        .to_set
      pool.select { |t| higher_ids.include?(t.id) }
    end

    def manager?(teammate)
      EmploymentTenure.active.exists?(manager_teammate_id: teammate.id)
    end

    def recipient_department_id
      @recipient_department_id ||= department_id_for(@recipient)
    end

    def department_id_for(teammate)
      tenure = teammate.employment_tenures.find(&:active?) || teammate.active_employment_tenure
      tenure&.position&.title&.department_id
    end
  end
end
