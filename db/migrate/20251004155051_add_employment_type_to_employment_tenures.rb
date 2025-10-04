class AddEmploymentTypeToEmploymentTenures < ActiveRecord::Migration[8.0]
  def change
    add_column :employment_tenures, :employment_type, :string, default: 'full_time'
  end
end
