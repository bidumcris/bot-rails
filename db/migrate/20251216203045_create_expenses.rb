class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount_cents
      t.string :currency
      t.string :description
      t.string :category
      t.string :subcategory
      t.datetime :spent_at
      t.string :raw_text
      t.string :llm_provider
      t.string :llm_model
      t.decimal :llm_confidence
      t.json :metadata

      t.timestamps
    end
  end
end
