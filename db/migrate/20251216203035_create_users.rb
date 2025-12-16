class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :telegram_user_id
      t.string :telegram_chat_id
      t.string :phone_e164
      t.string :currency
      t.string :time_zone

      t.timestamps
    end
  end
end
