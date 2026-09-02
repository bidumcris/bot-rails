# frozen_string_literal: true

class AddKindToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :kind, :string, null: false, default: "expense"
    add_index :expenses, :kind
  end
end
