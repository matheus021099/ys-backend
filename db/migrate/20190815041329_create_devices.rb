class CreateDevices < ActiveRecord::Migration[5.0]
  def change
    create_table :devices do |t|
      t.references :user, index: true
      t.string :platform, default: 'ios'
      t.string :token
      t.boolean :enabled, default: true
      t.string :status

      t.timestamps
    end
  end
end
