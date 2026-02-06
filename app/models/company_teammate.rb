class CompanyTeammate < ApplicationRecord
  self.table_name = 'teammates'

  belongs_to :person
  belongs_to :organization

  # Reverse associations
  has_many :teammate_milestones, foreign_key: 'teammate_id', dependent: :nullify
  has_many :assignment_check_ins, foreign_key: 'teammate_id', dependent: :nullify
  has_many :aspiration_check_ins, foreign_key: 'teammate_id', dependent: :nullify
  has_many :assignment_tenures, foreign_key: 'teammate_id', dependent: :nullify
  has_many :assignments, through: :assignment_tenures
  has_many :employment_tenures, foreign_key: 'teammate_id', dependent: :nullify
  has_many :position_check_ins, through: :employment_tenures
  has_many :observees, foreign_key: 'teammate_id', dependent: :destroy
  has_many :observations, through: :observees
  has_many :teammate_identities, foreign_key: 'teammate_id', dependent: :destroy
  has_one :one_on_one_link, foreign_key: 'teammate_id', dependent: :destroy
  has_many :huddle_feedbacks, foreign_key: 'teammate_id', dependent: :nullify
  has_many :huddle_participants, foreign_key: 'teammate_id', dependent: :nullify

  has_many :prompts, foreign_key: 'company_teammate_id', dependent: :destroy

  # Highlights associations
  has_one :highlights_points_ledger, foreign_key: :company_teammate_id, dependent: :destroy
  has_many :highlights_transactions, foreign_key: :company_teammate_id, dependent: :destroy
  has_many :highlights_redemptions, foreign_key: :company_teammate_id, dependent: :destroy
  has_many :bank_awards_given, class_name: 'BankAwardTransaction', foreign_key: :company_teammate_banker_id, dependent: :nullify

  # Validations
  validates :person_id, uniqueness: { scope: :organization_id }
  validates :first_employed_at, presence: true, if: :employed?
  validates :last_terminated_at, comparison: { greater_than: :first_employed_at }, allow_nil: true
  validate :company_level_permissions

  # Scopes
  scope :for_organization_hierarchy, ->(org) {
    if org.company?
      where(organization: org.self_and_descendants)
    else
      where(organization: [org, org.parent].compact)
    end
  }
  scope :with_employment_management, -> { where(can_manage_employment: true) }
  scope :with_employment_creation, -> { where(can_create_employment: true) }
  scope :with_maap_management, -> { where(can_manage_maap: true) }
  scope :with_prompts_management, -> { where(can_manage_prompts: true) }
  scope :with_departments_and_teams_management, -> { where(can_manage_departments_and_teams: true) }
  scope :with_customize_company, -> { where(can_customize_company: true) }
  scope :with_highlights_management, -> { where(can_manage_highlights_rewards: true) }

  # Employment state scopes
  scope :followers, -> { where(first_employed_at: nil, last_terminated_at: nil) }
  scope :huddlers, -> { where(first_employed_at: nil, last_terminated_at: nil) }
  scope :employed, -> { where.not(first_employed_at: nil).where(last_terminated_at: nil) }
  scope :unassigned_employees, -> { where.not(first_employed_at: nil).where(last_terminated_at: nil) }
  scope :assigned_employees, -> { where.not(first_employed_at: nil).where(last_terminated_at: nil) }
  scope :terminated, -> { where.not(last_terminated_at: nil) }

  # Instance methods - permission accessors
  def can_manage_employment?
    self[:can_manage_employment] == true
  end

  def can_create_employment?
    self[:can_create_employment] == true
  end

  def can_manage_maap?
    self[:can_manage_maap] == true
  end

  def can_manage_prompts?
    self[:can_manage_prompts] == true
  end

  def can_manage_departments_and_teams?
    self[:can_manage_departments_and_teams] == true
  end

  def can_customize_company?
    self[:can_customize_company] == true
  end

  def can_manage_highlights_rewards?
    self[:can_manage_highlights_rewards] == true
  end

  def can_be_points_banker?
    can_manage_highlights_rewards?
  end

  # Highlights helper methods
  def highlights_ledger
    highlights_points_ledger || create_highlights_points_ledger(organization: organization)
  end

  # Employment state methods
  def huddler?
    follower? && has_huddle_participation?
  end

  def follower?
    first_employed_at.nil? && last_terminated_at.nil? && !has_huddle_participation?
  end

  def unassigned_employee?
    first_employed_at.present? && last_terminated_at.nil? && !has_active_employment_tenure?
  end

  def assigned_employee?
    first_employed_at.present? && last_terminated_at.nil? && has_active_employment_tenure?
  end

  def terminated?
    last_terminated_at.present?
  end

  def employed?
    first_employed_at.present? && last_terminated_at.nil?
  end

  def has_huddle_participation?
    company_id = organization.company? ? organization.id : organization.parent_id
    return false unless company_id

    person.huddle_participants.joins(huddle: :team)
          .where(teams: { company_id: company_id })
          .exists?
  end

  def has_active_employment_tenure?
    employment_tenures.active.exists?(company: organization)
  end

  # TeammateIdentity helper methods
  def slack_identity
    teammate_identities.slack.first
  end

  def slack_user_id
    slack_identity&.uid
  end

  def has_slack_identity?
    teammate_identities.slack.exists?
  end

  def asana_identity
    teammate_identities.asana.first
  end

  def asana_user_id
    asana_identity&.uid
  end

  def has_asana_identity?
    teammate_identities.asana.exists?
  end

  def jira_identity
    teammate_identities.jira.first
  end

  def jira_user_id
    jira_identity&.uid
  end

  def has_jira_identity?
    teammate_identities.jira.exists?
  end

  def linear_identity
    teammate_identities.linear.first
  end

  def linear_user_id
    linear_identity&.uid
  end

  def has_linear_identity?
    teammate_identities.linear.exists?
  end

  def identity_for(provider)
    teammate_identities.find_by(provider: provider.to_s)
  end

  def profile_image_url
    slack_identity&.profile_image_url || person.google_profile_image_url
  end

  def to_s
    "(#{id}) #{person.display_name} @ #{organization.name}"
  end

  def can_manage_anything?
    can_manage_employment? && can_manage_maap?
  end

  def has_full_access?
    can_manage_employment? && can_manage_maap? && can_create_employment?
  end

  # Active employment tenure for this teammate's company
  def active_employment_tenure
    employment_tenures.active.where(company: organization).first
  end

  # Milestone-related methods
  def milestone_attainments
    teammate_milestones.by_milestone_level.includes(:ability)
  end

  def milestone_attainments_count
    teammate_milestones.count
  end

  def has_milestone_attainments?
    teammate_milestones.exists?
  end

  def highest_milestone_for_ability(ability)
    teammate_milestones.where(ability: ability).maximum(:milestone_level)
  end

  def has_milestone_for_ability?(ability, level)
    teammate_milestones.where(ability: ability, milestone_level: level).exists?
  end

  def add_milestone_attainment(ability, level, certified_by)
    teammate_milestones.create!(ability: ability, milestone_level: level, certifying_teammate: certified_by, attained_at: Date.current)
  end

  def remove_milestone_attainment(ability, level)
    teammate_milestones.where(ability: ability, milestone_level: level).destroy_all
  end

  # Assignment-related methods
  def active_assignment_tenures
    assignment_tenures
      .joins(:assignment)
      .where(ended_at: nil)
      .where('assignment_tenures.anticipated_energy_percentage > 0')
      .where(assignments: { company: organization })
  end

  def assignments_ready_for_finalization_count
    AssignmentCheckIn.joins(:assignment)
                     .where(company_teammate: self, assignments: { company: organization })
                     .ready_for_finalization
                     .count
  end

  def active_assignments
    assignments.joins(:assignment_tenures)
               .where(assignment_tenures: {
                 assignments: { company: organization },
                 ended_at: nil
               })
               .where('assignment_tenures.anticipated_energy_percentage > 0')
               .distinct
  end

  def has_direct_reports?
    EmploymentTenure.where(company: organization, manager_teammate: self, ended_at: nil)
                    .exists?
  end

  def in_managerial_hierarchy_of?(other_teammate)
    return false unless other_teammate
    return false unless other_teammate.organization == organization

    company = organization
    visited = Set.new

    check_hierarchy = lambda do |teammate, visited_set|
      return false if visited_set.include?(teammate.id)
      visited_set.add(teammate.id)

      tenures = EmploymentTenure.where(company_teammate: teammate, company: company, ended_at: nil).includes(:manager_teammate)

      tenures.each do |tenure|
        manager_teammate = tenure.manager_teammate
        next unless manager_teammate

        return true if manager_teammate == self
        return true if check_hierarchy.call(manager_teammate, visited_set)
      end

      false
    end

    check_hierarchy.call(other_teammate, visited)
  end

  def current_manager
    employment_tenures.active.first&.manager_teammate&.person
  end

  # Class methods for permission checking
  def self.can_manage_employment?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_manage_employment? || false
  end

  def self.can_create_employment?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_create_employment? || false
  end

  def self.can_manage_maap?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_manage_maap? || false
  end

  def self.can_manage_departments_and_teams?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_manage_departments_and_teams? || false
  end

  def self.can_customize_company?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_customize_company? || false
  end

  def self.can_manage_highlights_rewards?(person, organization)
    return true if person.og_admin?
    access = find_by(person: person, organization: organization)
    access&.can_manage_highlights_rewards? || false
  end

  def self.can_manage_employment_in_hierarchy?(person, organization)
    return true if person.og_admin?

    if organization.company?
      company_access = find_by(person: person, organization: organization)
      return company_access.can_manage_employment? if company_access

      descendant_access = where(organization: organization.descendants).find_by(person: person)
      descendant_access&.can_manage_employment? || false
    else
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent

      current_access&.can_manage_employment? || parent_access&.can_manage_employment? || false
    end
  end

  def self.can_manage_maap_in_hierarchy?(person, organization)
    return true if person.og_admin?

    if organization.company?
      company_access = find_by(person: person, organization: organization)
      return company_access.can_manage_maap? if company_access

      descendant_access = where(organization: organization.descendants).find_by(person: person)
      descendant_access&.can_manage_maap? || false
    else
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent

      current_access&.can_manage_maap? || parent_access&.can_manage_maap? || false
    end
  end

  def self.can_manage_prompts_in_hierarchy?(person, organization)
    return true if person.og_admin?

    if organization.company?
      company_access = find_by(person: person, organization: organization)
      return company_access.can_manage_prompts? if company_access

      descendant_access = where(organization: organization.descendants).find_by(person: person)
      descendant_access&.can_manage_prompts? || false
    else
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent

      current_access&.can_manage_prompts? || parent_access&.can_manage_prompts? || false
    end
  end

  def self.can_create_employment_in_hierarchy?(person, organization)
    return true if person.og_admin?

    if organization.company?
      company_access = find_by(person: person, organization: organization)
      return company_access.can_create_employment? if company_access

      descendant_access = where(organization: organization.descendants).find_by(person: person)
      descendant_access&.can_create_employment? || false
    else
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent

      current_access&.can_create_employment? || parent_access&.can_create_employment? || false
    end
  end

  def self.can_manage_departments_and_teams_in_hierarchy?(person, organization)
    return true if person.og_admin?

    if organization.company?
      company_access = find_by(person: person, organization: organization)
      return company_access.can_manage_departments_and_teams? if company_access

      descendant_access = where(organization: organization.descendants).find_by(person: person)
      descendant_access&.can_manage_departments_and_teams? || false
    else
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent

      current_access&.can_manage_departments_and_teams? || parent_access&.can_manage_departments_and_teams? || false
    end
  end

  def self.can_customize_company_in_hierarchy?(person, organization)
    return true if person.og_admin?

    if organization.company?
      company_access = find_by(person: person, organization: organization)
      return company_access.can_customize_company? if company_access

      descendant_access = where(organization: organization.descendants).find_by(person: person)
      descendant_access&.can_customize_company? || false
    else
      current_access = find_by(person: person, organization: organization)
      parent_access = find_by(person: person, organization: organization.parent) if organization.parent

      current_access&.can_customize_company? || parent_access&.can_customize_company? || false
    end
  end

  private

  def company_level_permissions
    # Company teammates can have any combination of permissions
  end
end
