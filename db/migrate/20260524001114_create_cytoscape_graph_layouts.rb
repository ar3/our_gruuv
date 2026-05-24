class CreateCytoscapeGraphLayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :cytoscape_graph_layouts do |t|
      t.references :layoutable, polymorphic: true, null: false
      t.string :graph_kind, null: false
      t.jsonb :positions, null: false, default: {}
      t.string :node_fingerprint

      t.timestamps
    end

    add_index :cytoscape_graph_layouts,
              %i[layoutable_type layoutable_id graph_kind],
              unique: true,
              name: "index_cytoscape_graph_layouts_on_layoutable_and_kind"
  end
end
