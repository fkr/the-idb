class AddPendingUpdatesPackageNames < ActiveRecord::Migration[4.2]
  def change
    add_column :machines, :pending_updates_package_names, :text
  end
end
