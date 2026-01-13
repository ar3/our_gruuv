class CreateAssignmentSupplyRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :assignment_supply_relationships do |t|
      t.references :supplier_assignment, null: false, foreign_key: { to_table: :assignments }
      t.references :consumer_assignment, null: false, foreign_key: { to_table: :assignments }

      t.timestamps
    end

    add_index :assignment_supply_relationships, 
              [:supplier_assignment_id, :consumer_assignment_id], 
              unique: true,
              name: 'index_assignment_supply_relationships_on_supplier_and_consumer'

    # Prevent self-referential relationships
    add_check_constraint :assignment_supply_relationships,
                        'supplier_assignment_id != consumer_assignment_id',
                        name: 'check_no_self_referential_supply_relationships'
  end
end
