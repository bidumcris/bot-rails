# frozen_string_literal: true

class AddProFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :pro_until, :datetime
    add_column :users, :trial_used_at, :datetime
    add_column :users, :pro_source, :string
    add_column :users, :mp_payment_id, :string
    add_column :users, :mp_preference_id, :string
    add_index :users, :pro_until
    add_index :users, :mp_payment_id
  end
end
