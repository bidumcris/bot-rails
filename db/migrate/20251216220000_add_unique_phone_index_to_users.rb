class AddUniquePhoneIndexToUsers < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :phone_e164, unique: true, where: "phone_e164 IS NOT NULL"
  end
end


