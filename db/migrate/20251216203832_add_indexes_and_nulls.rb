class AddIndexesAndNulls < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :telegram_user_id, false
    add_index :users, :telegram_user_id, unique: true

    change_column_default :users, :currency, from: nil, to: "ARS"

    change_column_null :expenses, :amount_cents, false
    change_column_null :expenses, :currency, false
    change_column_null :expenses, :raw_text, false
    change_column_null :expenses, :spent_at, false
    change_column_null :expenses, :category, false

    change_column_default :expenses, :currency, from: nil, to: "ARS"
  end
end
