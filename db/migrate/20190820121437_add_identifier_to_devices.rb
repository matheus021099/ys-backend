class AddIdentifierToDevices < ActiveRecord::Migration[5.0]
  def change
    add_column :devices, :identifier, :string
  end
end
