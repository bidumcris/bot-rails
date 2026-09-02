# frozen_string_literal: true

class AddOccupationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :occupation, :string
    add_column :users, :onboarding_step, :string
  end
end
