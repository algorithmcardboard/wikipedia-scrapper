# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 0) do

  create_table "categories", force: true do |t|
    t.string  "name",           limit: 100
    t.text    "description",                null: false
    t.integer "application_id",             null: false
  end

  create_table "events", force: true do |t|
    t.string  "name",        limit: 50,             null: false
    t.text    "event",                              null: false
    t.integer "day",         limit: 2,              null: false
    t.integer "month",       limit: 2,              null: false
    t.integer "year",                   default: 0
    t.integer "user_id",                default: 0, null: false
    t.integer "category_id", limit: 1,              null: false
    t.integer "status",                 default: 0, null: false
    t.integer "has_image",                          null: false
    t.integer "link_id"
  end

  add_index "events", ["day", "month", "category_id", "status"], name: "day", using: :btree
  add_index "events", ["user_id"], name: "user_id", using: :btree

  create_table "events_links", id: false, force: true do |t|
    t.integer "link_id",  null: false
    t.integer "event_id", null: false
  end

  add_index "events_links", ["event_id", "link_id"], name: "event_id", unique: true, using: :btree

  create_table "links", force: true do |t|
    t.string "url",       limit: 330, null: false
    t.string "name",      limit: 50,  null: false
    t.string "image_url", limit: 200
  end

  add_index "links", ["url"], name: "url", using: :btree

end
