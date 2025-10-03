class AddTypeToTeammates < ActiveRecord::Migration[8.0]
  def change
    add_column :teammates, :type, :string
  end
end
