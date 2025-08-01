class HuddlePolicy < ApplicationPolicy
  def show?
    true
  end

  def create?
    true
  end

  def update?
    user_participant&.role == 'facilitator'
  end

  def destroy?
    user_participant&.role == 'facilitator'
  end

  def join?
    true
  end

  def join_huddle?
    true
  end

  def feedback?
    return false unless user_participant.present?
    true
  end

  def submit_feedback?
    return false unless user_participant.present?
    true
  end



  # Only department head or facilitators can view the individual responses table
  def view_individual_responses?
    facilitator_or_department_head?
  end

  # Only department head can see department head only stuff
  def view_department_head_only?
    department_head?
  end

  # Facilitator-only stuff: both facilitators and department heads can see
  def view_facilitator_only?
    facilitator_or_department_head?
  end

  private

  def user_participant
    @user_participant ||= record.huddle_participants.find_by(person: user)
  end

  def facilitator_or_department_head?
    facilitator? || department_head?
  end

  def facilitator?
    user_participant&.role == 'facilitator'
  end

  def department_head?
    # The department head is defined by the huddle's organization
    record.organization&.department_head == user
  end

  class Scope < Scope
    def resolve
      if user
        scope.joins(:huddle_participants).where(huddle_participants: { person: user })
      else
        scope.active
      end
    end
  end
end
