class AddCanCustomizeCompanyToTeammates < ActiveRecord::Migration[8.0]
  def change
    add_column :teammates, :can_customize_company, :boolean, default: false
    add_index :teammates, :can_customize_company
  end
end
