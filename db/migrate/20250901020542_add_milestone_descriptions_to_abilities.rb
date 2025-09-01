class AddMilestoneDescriptionsToAbilities < ActiveRecord::Migration[8.0]
  def change
    add_column :abilities, :milestone_1_description, :text
    add_column :abilities, :milestone_2_description, :text
    add_column :abilities, :milestone_3_description, :text
    add_column :abilities, :milestone_4_description, :text
    add_column :abilities, :milestone_5_description, :text
  end
end
