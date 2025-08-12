class AddEmploymentChangeNotesToEmploymentTenures < ActiveRecord::Migration[8.0]
  def change
    add_column :employment_tenures, :employment_change_notes, :text
  end
end
