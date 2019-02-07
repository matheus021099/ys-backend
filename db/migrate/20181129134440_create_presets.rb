class CreatePresets < ActiveRecord::Migration[5.0]
  def change
    create_table :presets do |t|
      t.references :user, index: true
      t.string :context, limit: 128
      t.string :name
      t.text :data, default: ''

      t.timestamps
    end

    add_index :presets, [:user_id, :context]
  end
end
