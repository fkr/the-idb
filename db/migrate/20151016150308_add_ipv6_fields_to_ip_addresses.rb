class AddIpv6FieldsToIpAddresses < ActiveRecord::Migration[4.2]
  def change
    add_column :ip_addresses, :addr_v6, :string
    add_column :ip_addresses, :netmask_v6, :string
  end
end
