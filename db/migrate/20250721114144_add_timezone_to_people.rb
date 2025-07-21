class AddTimezoneToPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :timezone, :string
  end
end
