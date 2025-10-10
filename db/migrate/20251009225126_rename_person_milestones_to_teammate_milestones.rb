class RenamePersonMilestonesToTeammateMilestones < ActiveRecord::Migration[8.0]
  def change
    rename_table :person_milestones, :teammate_milestones
  end
end
