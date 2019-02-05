class CreateRelations < ActiveRecord::Migration[5.0]
  def change
    create_table :relations do |t|
      t.references :host, references: :user
      t.references :client, references: :user
      t.string :context

      t.string :status
      t.timestamps
    end
  end
end
