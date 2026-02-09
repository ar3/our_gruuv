# frozen_string_literal: true

class AddBornAtToPeople < ActiveRecord::Migration[7.2]
  def change
    add_column :people, :born_at, :datetime unless column_exists?(:people, :born_at)
  end
end
