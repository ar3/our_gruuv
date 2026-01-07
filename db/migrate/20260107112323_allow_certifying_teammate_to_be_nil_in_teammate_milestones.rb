class AllowCertifyingTeammateToBeNilInTeammateMilestones < ActiveRecord::Migration[8.0]
  def change
    change_column_null :teammate_milestones, :certifying_teammate_id, true
  end
end
