# frozen_string_literal: true

class KudosPolicy < ApplicationPolicy
  # Manage rewards catalog and settings
  def manage_rewards?
    return false unless viewing_teammate.is_a?(CompanyTeammate)
    admin_bypass? || viewing_teammate.can_manage_kudos_rewards?
  end

  # Manage kudos settings for the organization
  def manage_settings?
    manage_rewards?
  end

  # View own balance - any company teammate can view their own
  def view_own_balance?
    viewing_teammate.is_a?(CompanyTeammate)
  end

  # View transactions - own transactions or manage permission
  def view_transactions?
    view_own_balance?
  end

  # View dashboard - any company teammate
  def view_dashboard?
    viewing_teammate.is_a?(CompanyTeammate)
  end

  # Award bank points - requires kudos management permission
  def award_bank_points?
    manage_rewards?
  end

  # View rewards catalog - any teammate in enabled org
  def view_rewards_catalog?
    view_dashboard?
  end

  # Create/update/delete rewards - requires management permission
  def manage_rewards_catalog?
    manage_rewards?
  end

  # Redeem rewards - any teammate with sufficient balance
  def redeem_reward?
    view_dashboard?
  end

  # View own redemptions
  def view_own_redemptions?
    view_own_balance?
  end

  # View all redemptions (admin)
  def view_all_redemptions?
    manage_rewards?
  end

  # Manage redemption status (fulfill, cancel, etc.)
  def manage_redemption_status?
    manage_rewards?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate.is_a?(CompanyTeammate)

      if admin_bypass? || viewing_teammate.can_manage_kudos_rewards?
        scope.where(organization: viewing_teammate.organization)
      else
        scope.where(company_teammate: viewing_teammate)
      end
    end
  end
end
