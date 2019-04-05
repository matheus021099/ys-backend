class CreatePosts < ActiveRecord::Migration[5.0]
  def change
    create_table :posts do |t|
      t.references :user, index: true
      t.string :media_type
      t.string :media
      t.string :media_name
      t.string :description
      t.references :assoc, polymorphic: true
      t.string :assoc_selector

      t.string :status
      t.timestamps
    end
  end
end
