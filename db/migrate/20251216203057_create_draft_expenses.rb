class CreateDraftExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_expenses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :raw_text
      t.json :extracted
      t.string :state
      t.string :error

      t.timestamps
    end
  end
end
