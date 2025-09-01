class RenameVersionToSemanticVersionInAbilities < ActiveRecord::Migration[8.0]
  def change
    rename_column :abilities, :version, :semantic_version
  end
end
