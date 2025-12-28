# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 8) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "epoches", force: :cascade do |t|
    t.integer "epoch_id", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.string "merkle_root"
    t.string "status", default: "pending"
    t.float "total_traffic", default: 0.0
    t.integer "node_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["epoch_id"], name: "index_epoches_on_epoch_id", unique: true
  end

  create_table "heartbeats", force: :cascade do |t|
    t.bigint "node_id", null: false
    t.float "latency", null: false
    t.float "loss", null: false
    t.float "bandwidth", null: false
    t.integer "uptime", null: false
    t.string "signature", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_heartbeats_on_created_at"
    t.index ["node_id"], name: "index_heartbeats_on_node_id"
  end

  create_table "nodes", force: :cascade do |t|
    t.string "address", null: false
    t.string "status", default: "inactive"
    t.float "latency"
    t.float "loss"
    t.float "bandwidth"
    t.integer "uptime"
    t.integer "reputation_score"
    t.datetime "last_heartbeat_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "wireguard_public_key"
    t.string "wireguard_endpoint"
    t.integer "wireguard_listen_port"
    t.string "node_api_url"
    t.index ["address"], name: "index_nodes_on_address", unique: true
  end

  create_table "rewards", force: :cascade do |t|
    t.bigint "node_id", null: false
    t.bigint "epoch_id", null: false
    t.integer "amount", null: false
    t.text "merkle_proof", null: false
    t.boolean "claimed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["epoch_id"], name: "index_rewards_on_epoch_id"
    t.index ["node_id", "epoch_id"], name: "index_rewards_on_node_id_and_epoch_id", unique: true
    t.index ["node_id"], name: "index_rewards_on_node_id"
  end

  create_table "traffic_records", force: :cascade do |t|
    t.bigint "node_id", null: false
    t.bigint "vpn_connection_id"
    t.integer "epoch_id", null: false
    t.float "traffic_mb", null: false
    t.string "signature", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "ai_scored", default: false
    t.float "ai_score"
    t.boolean "has_anomaly", default: false
    t.boolean "reward_eligible", default: false
    t.string "request_source"
    t.text "eligibility_reason"
    t.index ["ai_scored"], name: "index_traffic_records_on_ai_scored"
    t.index ["created_at"], name: "index_traffic_records_on_created_at"
    t.index ["epoch_id"], name: "index_traffic_records_on_epoch_id"
    t.index ["has_anomaly"], name: "index_traffic_records_on_has_anomaly"
    t.index ["node_id"], name: "index_traffic_records_on_node_id"
    t.index ["reward_eligible"], name: "index_traffic_records_on_reward_eligible"
    t.index ["vpn_connection_id"], name: "index_traffic_records_on_vpn_connection_id"
  end

  create_table "vpn_connections", force: :cascade do |t|
    t.string "connection_id", null: false
    t.string "user_address", null: false
    t.bigint "entry_node_id", null: false
    t.bigint "exit_node_id", null: false
    t.string "status", default: "connected"
    t.float "route_score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connection_id"], name: "index_vpn_connections_on_connection_id", unique: true
    t.index ["entry_node_id"], name: "index_vpn_connections_on_entry_node_id"
    t.index ["exit_node_id"], name: "index_vpn_connections_on_exit_node_id"
  end

  add_foreign_key "heartbeats", "nodes"
  add_foreign_key "rewards", "epoches"
  add_foreign_key "rewards", "nodes"
  add_foreign_key "traffic_records", "nodes"
  add_foreign_key "traffic_records", "vpn_connections"
  add_foreign_key "vpn_connections", "nodes", column: "entry_node_id"
  add_foreign_key "vpn_connections", "nodes", column: "exit_node_id"
end
