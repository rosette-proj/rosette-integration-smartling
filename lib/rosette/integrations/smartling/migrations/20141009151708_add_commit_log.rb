class AddCommitLog < ActiveRecord::Migration
  def up
    create_table :commit_logs do |t|
      t.string :commit_id, limit: 45, null: false
      t.string :status, limit: 255
      t.timestamps
    end

    add_index :commit_logs, [:commit_id], unique: true
  end

  def down
    drop_table :commit_logs
  end
end
