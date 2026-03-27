# Teammates who may receive a milestone award from the awarding teammate (same rules as
# Organizations::TeammateMilestonesController#select_teammate).
class TeammateMilestoneRecipientEligibilityQuery
  def initialize(awarding_teammate:, organization:)
    @awarding = awarding_teammate
    @organization = organization
  end

  def eligible_teammates
    return CompanyTeammate.none unless @awarding

    if @awarding.can_manage_employment?
      CompanyTeammate.where(organization: @organization)
        .where.not(id: @awarding.id)
        .where(last_terminated_at: nil)
        .joins(:person)
        .includes(:person, :employment_tenures)
        .order("people.last_name, people.first_name")
    else
      reports = EmployeeHierarchyQuery.new(
        person: @awarding.person,
        organization: @organization
      ).call

      if reports.any?
        report_person_ids = reports.map { |r| r[:person_id] }
        CompanyTeammate.where(organization: @organization)
          .where(person_id: report_person_ids, last_terminated_at: nil)
          .joins(:person)
          .includes(:person, :employment_tenures)
          .order("people.last_name, people.first_name")
      else
        CompanyTeammate.none
      end
    end
  end

  def eligible_to_award?(subject_teammate)
    return false if subject_teammate.blank?
    return false if subject_teammate.id == @awarding.id

    eligible_teammates.where(id: subject_teammate.id).exists?
  end

  def ineligibility_explanation(subject_teammate)
    return nil if eligible_to_award?(subject_teammate)

    if subject_teammate.id == @awarding.id
      "You cannot award a milestone to yourself."
    elsif @awarding.can_manage_employment?
      "This teammate is not eligible to receive a milestone from you (for example, they may no longer be active in this organization)."
    elsif EmployeeHierarchyQuery.new(person: @awarding.person, organization: @organization).call.any?
      "You can only award milestones to teammates who report to you, directly or indirectly."
    else
      "Only people with direct or indirect reports—or those with Manage employment permission—can award milestones."
    end
  end
end
