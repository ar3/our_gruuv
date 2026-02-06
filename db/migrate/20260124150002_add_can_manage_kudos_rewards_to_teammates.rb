class AddCanManageKudosRewardsToTeammates < ActiveRecord::Migration[8.0]
  def change
    add_column :teammates, :can_manage_kudos_rewards, :boolean, default: false, null: false
    add_index :teammates, :can_manage_kudos_rewards
  end
end
