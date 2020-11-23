class CreateStreamLogs < ActiveRecord::Migration[5.0]
  def change
    create_table :stream_logs do |t|
      t.references :stream, index: true
      t.references :user

      t.timestamps
    end
  end
end
