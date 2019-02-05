class CreatePresets < ActiveRecord::Migration[5.0]
  def change
    create_table :presets, id: :uuid do |t|
      t.references :user, index: true, type: :uuid

      t.string :context, limit: 128
      t.string :name
      t.text :data, default: ''

      t.timestamps
    end

    add_index :presets, [:user_id, :context]
  end
end
