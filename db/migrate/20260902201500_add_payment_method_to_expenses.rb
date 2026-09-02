# frozen_string_literal: true

class AddPaymentMethodToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :payment_method, :string
    add_index :expenses, :payment_method
  end
end
