class CreateActivities < ActiveRecord::Migration[5.0]
  def change
    create_table :activities do |t|
      t.references :sender, references: :user
      t.references :receiver, referecnes: :user

      t.string  :message
      t.string  :module_type
      t.string  :action_type
      t.integer :alert_type
      t.string  :page_track

      # t.integer :assoc_id
      # t.string  :assoc_type
      t.references :assoc, polymorphic: true

      t.string  :status
      t.timestamps
    end
  end
end
