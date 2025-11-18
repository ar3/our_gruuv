class HuddlePolicy < ApplicationPolicy
  def show?
    true
  end

  def create?
    true
  end

  def update?
    admin_bypass? || user_participant&.role == 'facilitator'
  end

  def destroy?
    admin_bypass? || user_participant&.role == 'facilitator'
  end

  def join?
    true
  end

  def join_huddle?
    viewing_teammate.present?
  end

  def direct_feedback?
    viewing_teammate.present?
  end

  def feedback?
    return true if admin_bypass?
    return false unless user_participant.present?
    true
  end

  def submit_feedback?
    return true if admin_bypass?
    return false unless user_participant.present?
    true
  end



  # Only department head or facilitators can view the individual responses table
  def view_individual_responses?
    admin_bypass? || facilitator_or_department_head?
  end

  # Only department head can see department head only stuff
  def view_department_head_only?
    admin_bypass? || department_head?
  end

  # Facilitator-only stuff: both facilitators and department heads can see
  def view_facilitator_only?
    admin_bypass? || facilitator_or_department_head?
  end

  private

  def user_participant
    return nil unless viewing_teammate
    person = viewing_teammate.person
    @user_participant ||= record.huddle_participants.joins(:teammate).find_by(teammates: { person: person })
  end

  def facilitator_or_department_head?
    facilitator? || department_head?
  end

  def facilitator?
    user_participant&.role == 'facilitator'
  end

  def department_head?
    # The department head is defined by the huddle's organization
    return false unless viewing_teammate
    person = viewing_teammate.person
    record.organization&.department_head == person
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.active unless viewing_teammate
      person = viewing_teammate.person
      return scope.active unless person
      scope.joins(huddle_participants: :teammate).where(teammates: { person: person })
    end
  end
end
