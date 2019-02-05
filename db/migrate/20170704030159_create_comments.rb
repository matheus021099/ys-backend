class CreateComments < ActiveRecord::Migration[5.0]
  def change
    create_table :comments do |t|
      t.references :user, index: false
      t.text :body
      # t.integer :commentable_id
      # t.string :commentable_type
      t.references :commentable, polymorphic: true

      t.string :status
      t.timestamps
    end
  end
end
