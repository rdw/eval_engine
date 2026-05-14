class CreateEvalEngineTables < ActiveRecord::Migration[8.1]
  def change
    create_table :eval_engine_runs do |t|
      t.string :eval_name, null: false
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :example_count, null: false, default: 0
      t.timestamps
    end
    add_index :eval_engine_runs, :eval_name
    add_index :eval_engine_runs, %i[eval_name finished_at]

    create_table :eval_engine_run_examples do |t|
      t.references :run, null: false, foreign_key: { to_table: :eval_engine_runs }
      t.string :example_key, null: false
      t.string :status, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.json :input
      t.json :expected
      t.json :output
      t.json :score_tree
      t.float :score
      t.text :error
      t.timestamps
    end
    add_index :eval_engine_run_examples, :example_key
    add_index :eval_engine_run_examples, :finished_at

    create_table :eval_engine_checkpoints do |t|
      t.string :eval_name, null: false
      t.datetime :checkpointed_at, null: false
      t.timestamps
    end
    add_index :eval_engine_checkpoints, :eval_name, unique: true
  end
end
