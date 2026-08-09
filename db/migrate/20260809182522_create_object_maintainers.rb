# frozen_string_literal: true

class CreateObjectMaintainers < ActiveRecord::Migration[8.0]
  def change
    create_table :object_maintainers do |t|
      t.string :maintainable_type, null: false
      t.bigint :maintainable_id, null: false
      t.references :company_teammate, null: false, foreign_key: { to_table: :teammates }
      t.references :added_by, null: true, foreign_key: { to_table: :teammates }

      t.timestamps
    end

    add_index :object_maintainers,
              [ :maintainable_type, :maintainable_id, :company_teammate_id ],
              unique: true,
              name: "index_object_maintainers_unique_membership"
    add_index :object_maintainers,
              [ :maintainable_type, :maintainable_id ],
              name: "index_object_maintainers_on_maintainable"
    add_index :object_maintainers,
              [ :company_teammate_id, :maintainable_type ],
              name: "index_object_maintainers_on_teammate_and_type"
  end
end
