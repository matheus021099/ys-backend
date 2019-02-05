class CreateFeeds < ActiveRecord::Migration[5.0]
  def change
    create_table :feeds do |t|
      t.references :consumer, references: :user
      t.references :publisher, referecnes: :user
      t.references :ancestor, references: :user
      t.string :feed_type
      # t.integer :assoc_id
      # t.string :assoc_type
      t.references :assoc, polymorphic: true

      t.string :status
      t.timestamps
    end
  end
end
