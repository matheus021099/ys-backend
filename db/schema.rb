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

ActiveRecord::Schema.define(version: 20190128034852) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "activities", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "message"
    t.integer  "module_type"
    t.integer  "action_type"
    t.integer  "alert_type"
    t.string   "assoc_id"
    t.string   "assoc_type"
    t.uuid     "sender_id"
    t.uuid     "receiver_id"
    t.integer  "status",      default: 0
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "page_track"
    t.index ["receiver_id"], name: "index_activities_on_receiver_id", using: :btree
    t.index ["sender_id"], name: "index_activities_on_sender_id", using: :btree
  end

  create_table "album_tracks", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid    "album_id"
    t.uuid    "track_id"
    t.integer "position", default: 0
    t.index ["album_id", "track_id"], name: "index_album_tracks_on_album_id_and_track_id", unique: true, using: :btree
  end

  create_table "albums", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "name"
    t.text     "description"
    t.string   "artist_name"
    t.string   "cover"
    t.string   "zip"
    t.integer  "album_type"
    t.integer  "status",                  default: 0
    t.boolean  "recommended"
    t.boolean  "released"
    t.datetime "released_at"
    t.string   "slug"
    t.uuid     "user_id"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.integer  "played",                  default: 0
    t.integer  "downloaded",              default: 0
    t.integer  "reposted",                default: 0
    t.integer  "commented",               default: 0
    t.integer  "collaborators_count",     default: 0
    t.datetime "recommended_at"
    t.datetime "zipped_at"
    t.string   "location",                default: ""
    t.boolean  "is_only_for_live_stream", default: false
    t.boolean  "is_content_acapella",     default: false
    t.boolean  "is_content_instrumental", default: false
    t.boolean  "is_content_stems",        default: false
    t.boolean  "is_content_remix",        default: false
    t.boolean  "is_content_dj_mix",       default: false
    t.boolean  "enabled_sample",          default: false
    t.index ["slug"], name: "index_albums_on_slug", unique: true, using: :btree
    t.index ["user_id"], name: "index_albums_on_user_id", using: :btree
  end

  create_table "attachments", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.integer  "mailboxer_notification_id"
    t.string   "attachable_type"
    t.uuid     "attachable_id"
    t.string   "payment_customer_id"
    t.string   "payment_token"
    t.integer  "repost_price",              default: 100,      null: false
    t.integer  "status"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.string   "attachment_type",           default: "repost"
    t.index ["attachable_type", "attachable_id"], name: "index_attachments_on_attachable_type_and_attachable_id", using: :btree
  end

  create_table "attendees", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "full_name"
    t.string   "display_name"
    t.string   "email"
    t.string   "account_type",     default: "artist"
    t.string   "referred_by",      default: ""
    t.uuid     "referrer_id"
    t.uuid     "user_id"
    t.string   "status",           default: "created"
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.string   "invitation_token"
    t.datetime "invited_at"
    t.index ["display_name"], name: "index_attendees_on_display_name", using: :btree
    t.index ["email"], name: "index_attendees_on_email", using: :btree
    t.index ["invitation_token"], name: "index_attendees_on_invitation_token", using: :btree
    t.index ["referrer_id"], name: "index_attendees_on_referrer_id", using: :btree
    t.index ["user_id"], name: "index_attendees_on_user_id", using: :btree
  end

  create_table "comments", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "user_id"
    t.text     "body"
    t.string   "commentable_type"
    t.uuid     "commentable_id"
    t.integer  "status"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree
  end

  create_table "feeds", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.integer  "feed_type"
    t.string   "assoc_id"
    t.string   "assoc_type"
    t.uuid     "consumer_id"
    t.uuid     "publisher_id"
    t.integer  "status",       default: 0
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.index ["consumer_id"], name: "index_feeds_on_consumer_id", using: :btree
    t.index ["publisher_id"], name: "index_feeds_on_publisher_id", using: :btree
  end

  create_table "follows", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "followable_type",                 null: false
    t.uuid     "followable_id",                   null: false
    t.string   "follower_type",                   null: false
    t.uuid     "follower_id",                     null: false
    t.boolean  "blocked",         default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["followable_id", "followable_type"], name: "fk_followables", using: :btree
    t.index ["follower_id", "follower_type"], name: "fk_follows", using: :btree
  end

  create_table "genres", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string  "name"
    t.text    "description"
    t.integer "position",    default: 0
    t.string  "slug"
    t.string  "ancestry"
    t.index ["ancestry"], name: "index_genres_on_ancestry", using: :btree
    t.index ["slug"], name: "index_genres_on_slug", unique: true, using: :btree
  end

  create_table "mailboxer_conversation_opt_outs", force: :cascade do |t|
    t.string  "unsubscriber_type"
    t.uuid    "unsubscriber_id"
    t.integer "conversation_id"
    t.index ["conversation_id"], name: "index_mailboxer_conversation_opt_outs_on_conversation_id", using: :btree
    t.index ["unsubscriber_id", "unsubscriber_type"], name: "index_mailboxer_conversation_opt_outs_on_unsubscriber_id_type", using: :btree
  end

  create_table "mailboxer_conversations", force: :cascade do |t|
    t.string   "subject",    default: ""
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "mailboxer_notifications", force: :cascade do |t|
    t.string   "type"
    t.text     "body"
    t.string   "subject",              default: ""
    t.string   "sender_type"
    t.uuid     "sender_id"
    t.integer  "conversation_id"
    t.boolean  "draft",                default: false
    t.string   "notification_code"
    t.string   "notified_object_type"
    t.integer  "notified_object_id"
    t.string   "attachment"
    t.datetime "updated_at",                           null: false
    t.datetime "created_at",                           null: false
    t.boolean  "global",               default: false
    t.datetime "expires"
    t.index ["conversation_id"], name: "index_mailboxer_notifications_on_conversation_id", using: :btree
    t.index ["notified_object_id", "notified_object_type"], name: "index_mailboxer_notifications_on_notified_object_id_and_type", using: :btree
    t.index ["sender_id", "sender_type"], name: "index_mailboxer_notifications_on_sender_id_and_sender_type", using: :btree
    t.index ["type"], name: "index_mailboxer_notifications_on_type", using: :btree
  end

  create_table "mailboxer_receipts", force: :cascade do |t|
    t.string   "receiver_type"
    t.uuid     "receiver_id"
    t.integer  "notification_id",                            null: false
    t.boolean  "is_read",                    default: false
    t.boolean  "trashed",                    default: false
    t.boolean  "deleted",                    default: false
    t.string   "mailbox_type",    limit: 25
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
    t.boolean  "is_delivered",               default: false
    t.string   "delivery_method"
    t.string   "message_id"
    t.index ["notification_id"], name: "index_mailboxer_receipts_on_notification_id", using: :btree
    t.index ["receiver_id", "receiver_type"], name: "index_mailboxer_receipts_on_receiver_id_and_receiver_type", using: :btree
  end

  create_table "payments", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "sender_id"
    t.string   "sender_stripe_id"
    t.uuid     "receiver_id"
    t.string   "receiver_stripe_id"
    t.string   "payment_type"
    t.string   "payment_token"
    t.integer  "sent_amount",        default: 0
    t.integer  "received_amount"
    t.integer  "fee",                default: 0
    t.integer  "tax",                default: 0
    t.string   "status"
    t.integer  "shipping_cost",      default: 0
    t.string   "assoc_type"
    t.uuid     "assoc_id"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.uuid     "order_id"
    t.integer  "user_share",         default: 0
    t.uuid     "attachment_id"
    t.string   "description",        default: ""
    t.integer  "refund_amount",      default: 0
    t.index ["attachment_id"], name: "index_payments_on_attachment_id", using: :btree
    t.index ["order_id"], name: "index_payments_on_order_id", using: :btree
  end

  create_table "presets", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "user_id"
    t.string   "context",    limit: 128
    t.string   "name"
    t.text     "data",                   default: ""
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.index ["user_id", "context"], name: "index_presets_on_user_id_and_context", using: :btree
    t.index ["user_id"], name: "index_presets_on_user_id", using: :btree
  end

  create_table "relations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "host_id"
    t.uuid     "client_id"
    t.string   "context"
    t.string   "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_relations_on_client_id", using: :btree
    t.index ["host_id"], name: "index_relations_on_host_id", using: :btree
  end

  create_table "roles", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "name"
    t.string   "resource_type"
    t.uuid     "resource_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id", using: :btree
    t.index ["name"], name: "index_roles_on_name", using: :btree
  end

  create_table "samplings", force: :cascade do |t|
    t.uuid     "sampling_user_id"
    t.uuid     "sampling_album_id"
    t.uuid     "sampling_track_id"
    t.uuid     "sample_user_id"
    t.uuid     "sample_album_id"
    t.uuid     "sample_track_id"
    t.integer  "position",          default: 0
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.index ["sample_album_id", "sample_track_id"], name: "index_samplings_on_sample_album_id_and_sample_track_id", using: :btree
    t.index ["sample_album_id"], name: "index_samplings_on_sample_album_id", using: :btree
    t.index ["sample_track_id"], name: "index_samplings_on_sample_track_id", using: :btree
    t.index ["sample_user_id"], name: "index_samplings_on_sample_user_id", using: :btree
    t.index ["sampling_album_id", "sampling_track_id"], name: "index_samplings_on_sampling_album_id_and_sampling_track_id", using: :btree
    t.index ["sampling_album_id"], name: "index_samplings_on_sampling_album_id", using: :btree
    t.index ["sampling_track_id"], name: "index_samplings_on_sampling_track_id", using: :btree
    t.index ["sampling_user_id"], name: "index_samplings_on_sampling_user_id", using: :btree
  end

  create_table "settings", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "key"
    t.string "value"
  end

  create_table "shop_addresses", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "customer_id"
    t.string   "email"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "unit"
    t.string   "street_1"
    t.string   "street_2"
    t.string   "city"
    t.string   "state"
    t.string   "country"
    t.string   "postcode"
    t.string   "phone_number"
    t.integer  "status"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.index ["customer_id"], name: "index_shop_addresses_on_customer_id", using: :btree
  end

  create_table "shop_carts", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "customer_id"
    t.text     "notes"
    t.integer  "status"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.index ["customer_id"], name: "index_shop_carts_on_customer_id", using: :btree
  end

  create_table "shop_categories", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "name"
    t.string   "description"
    t.integer  "status"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.boolean  "is_digital",  default: false
  end

  create_table "shop_items", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "customer_id"
    t.uuid     "merchant_id"
    t.uuid     "product_id"
    t.uuid     "product_variant_id"
    t.uuid     "cart_id"
    t.uuid     "order_id"
    t.integer  "type"
    t.integer  "price"
    t.integer  "quantity"
    t.integer  "fee"
    t.integer  "shipping_cost"
    t.integer  "status"
    t.datetime "created_at",                                                  null: false
    t.datetime "updated_at",                                                  null: false
    t.integer  "tax",                                         default: 0
    t.decimal  "tax_percent",        precision: 10, scale: 6, default: "0.0"
    t.boolean  "is_vat",                                      default: false
    t.index ["cart_id"], name: "index_shop_items_on_cart_id", using: :btree
    t.index ["customer_id"], name: "index_shop_items_on_customer_id", using: :btree
    t.index ["merchant_id"], name: "index_shop_items_on_merchant_id", using: :btree
    t.index ["order_id"], name: "index_shop_items_on_order_id", using: :btree
    t.index ["product_id"], name: "index_shop_items_on_product_id", using: :btree
    t.index ["product_variant_id"], name: "index_shop_items_on_product_variant_id", using: :btree
  end

  create_table "shop_orders", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "customer_id"
    t.uuid     "merchant_id"
    t.uuid     "cart_id"
    t.uuid     "billing_address_id"
    t.uuid     "shipping_address_id"
    t.integer  "amount"
    t.integer  "fee"
    t.integer  "shipping_cost"
    t.string   "provider"
    t.string   "payment_customer_id"
    t.string   "payment_token"
    t.integer  "status"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.uuid     "payment_id"
    t.string   "ship_method"
    t.string   "tracking_number"
    t.string   "tracking_url"
    t.boolean  "enabled_address",     default: true
    t.string   "track_number"
    t.integer  "tax_cost",            default: 0
    t.index ["billing_address_id"], name: "index_shop_orders_on_billing_address_id", using: :btree
    t.index ["cart_id"], name: "index_shop_orders_on_cart_id", using: :btree
    t.index ["customer_id"], name: "index_shop_orders_on_customer_id", using: :btree
    t.index ["merchant_id"], name: "index_shop_orders_on_merchant_id", using: :btree
    t.index ["shipping_address_id"], name: "index_shop_orders_on_shipping_address_id", using: :btree
  end

  create_table "shop_product_covers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "product_id"
    t.string   "cover"
    t.integer  "position",   default: 0
    t.integer  "status"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.index ["product_id"], name: "index_shop_product_covers_on_product_id", using: :btree
  end

  create_table "shop_product_shipments", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "product_id"
    t.string   "country"
    t.integer  "shipment_alone_price"
    t.integer  "shipment_with_price"
    t.integer  "status"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["product_id"], name: "index_shop_product_shipments_on_product_id", using: :btree
  end

  create_table "shop_product_variants", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "product_id"
    t.uuid     "variant_id"
    t.string   "name"
    t.integer  "price",      default: 100
    t.integer  "quantity",   default: 0
    t.integer  "status"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.index ["product_id"], name: "index_shop_product_variants_on_product_id", using: :btree
    t.index ["variant_id"], name: "index_shop_product_variants_on_variant_id", using: :btree
  end

  create_table "shop_products", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "merchant_id"
    t.uuid     "category_id"
    t.string   "name"
    t.string   "description"
    t.integer  "position",                                      default: 0
    t.integer  "price"
    t.decimal  "weight"
    t.decimal  "height"
    t.decimal  "width"
    t.decimal  "depth"
    t.integer  "status"
    t.datetime "created_at",                                                         null: false
    t.datetime "updated_at",                                                         null: false
    t.integer  "reposted",                                      default: 0
    t.integer  "sold",                                          default: 0
    t.integer  "quantity",                                      default: 0
    t.integer  "collaborators_count",                           default: 0
    t.boolean  "released",                                      default: false
    t.datetime "released_at"
    t.string   "stock_status",                                  default: "active"
    t.string   "show_status",                                   default: "show_all"
    t.decimal  "tax_percent",          precision: 10, scale: 6, default: "0.0"
    t.boolean  "is_vat",                                        default: false
    t.string   "seller_location"
    t.string   "digital_content"
    t.string   "digital_content_name"
    t.index ["category_id"], name: "index_shop_products_on_category_id", using: :btree
    t.index ["merchant_id"], name: "index_shop_products_on_merchant_id", using: :btree
  end

  create_table "shop_variants", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "name"
    t.text     "options_json"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "streams", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "user_id"
    t.string   "name"
    t.text     "description",           default: ""
    t.string   "ml_input_id"
    t.string   "ml_input_dest_1_url"
    t.string   "ml_input_dest_2_url"
    t.string   "ml_channel_id"
    t.string   "mp_channel_1_id"
    t.string   "mp_channel_1_url"
    t.string   "mp_channel_1_ep_1_id"
    t.string   "mp_channel_1_ep_1_url"
    t.string   "mp_channel_2_id"
    t.string   "mp_channel_2_url"
    t.string   "mp_channel_2_ep_1_id"
    t.string   "mp_channel_2_ep_1_url"
    t.string   "cf_domain"
    t.datetime "started_at"
    t.datetime "stopped_at"
    t.string   "assoc_type"
    t.string   "assoc_id"
    t.string   "status",                default: "active"
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.integer  "played_period",         default: 0
    t.integer  "valid_period",          default: 0
    t.uuid     "genre_id"
    t.integer  "view_price",            default: 0
    t.integer  "viewers_limit",         default: 0
    t.string   "cover"
    t.index ["genre_id"], name: "index_streams_on_genre_id", using: :btree
    t.index ["id", "user_id"], name: "index_streams_on_id_and_user_id", using: :btree
    t.index ["user_id"], name: "index_streams_on_user_id", using: :btree
  end

  create_table "taggings", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "tag_id"
    t.string   "taggable_type"
    t.uuid     "taggable_id"
    t.string   "tagger_type"
    t.uuid     "tagger_id"
    t.string   "context",       limit: 128
    t.datetime "created_at"
    t.index ["context"], name: "index_taggings_on_context", using: :btree
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true, using: :btree
    t.index ["tag_id"], name: "index_taggings_on_tag_id", using: :btree
    t.index ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context", using: :btree
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy", using: :btree
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id", using: :btree
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type", using: :btree
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type", using: :btree
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id", using: :btree
  end

  create_table "tags", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string  "name"
    t.integer "taggings_count", default: 0
    t.index ["name"], name: "index_tags_on_name", unique: true, using: :btree
  end

  create_table "tracks", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "name"
    t.text     "description"
    t.string   "audio"
    t.string   "slug"
    t.uuid     "user_id"
    t.integer  "status",      default: 0
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.integer  "played",      default: 0
    t.integer  "downloaded",  default: 0
    t.string   "clip"
    t.string   "acr_id"
    t.index ["slug"], name: "index_tracks_on_slug", unique: true, using: :btree
    t.index ["user_id"], name: "index_tracks_on_user_id", using: :btree
  end

  create_table "users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string   "email",                                         default: "",    null: false
    t.string   "encrypted_password",                            default: "",    null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                                 default: 0,     null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",                               default: 0,     null: false
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.string   "username"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "slug"
    t.string   "avatar"
    t.string   "contact_url"
    t.boolean  "enable_alert"
    t.integer  "repost_price",                                  default: 100,   null: false
    t.uuid     "address_id"
    t.integer  "timezone_offset"
    t.uuid     "invited_user_id"
    t.integer  "invitation_limit"
    t.string   "social_provider"
    t.string   "social_user_id"
    t.string   "social_token"
    t.string   "payment_provider"
    t.string   "payment_account_id"
    t.string   "payment_account_type"
    t.string   "payment_publishable_key"
    t.string   "payment_access_code"
    t.integer  "status"
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
    t.string   "display_name"
    t.string   "social_user_name"
    t.string   "social_token_secret"
    t.integer  "balance_amount",                                default: 0
    t.datetime "repost_price_end_at"
    t.datetime "message_first_visited_time"
    t.uuid     "approver_id"
    t.datetime "approved_at"
    t.boolean  "consigned",                                     default: false
    t.uuid     "inviter_id"
    t.datetime "invited_at"
    t.string   "return_policy",                    limit: 1023, default: ""
    t.string   "shipping_policy",                  limit: 1023, default: ""
    t.string   "size_chart",                       limit: 1023, default: ""
    t.uuid     "genre_id"
    t.integer  "release_count",                                 default: 0
    t.string   "soundcloud_url",                   limit: 1023, default: ""
    t.string   "basecamp_url",                     limit: 1023, default: ""
    t.string   "website_url",                      limit: 1023, default: ""
    t.string   "history",                          limit: 1023, default: ""
    t.string   "denial_reason",                                 default: ""
    t.string   "denial_description",               limit: 1023, default: ""
    t.string   "request_role"
    t.string   "request_status"
    t.boolean  "enabled_live_video",                            default: true
    t.boolean  "enabled_live_video_free",                       default: false
    t.integer  "stream_rolled_time",                            default: 0
    t.integer  "stream_rolled_cost",                            default: 0
    t.string   "privacy_policy",                   limit: 1023, default: ""
    t.integer  "free_streamed_time",                            default: 0
    t.integer  "max_repost_price",                              default: 100
    t.boolean  "enabled_view_direct_messages",                  default: false
    t.integer  "year_of_birth",                                 default: 0
    t.string   "gender",                                        default: ""
    t.string   "country",                                       default: ""
    t.string   "city",                                          default: ""
    t.string   "artist_type",                                   default: ""
    t.integer  "released_albums_count",                         default: 0
    t.integer  "years_since_first_released",                    default: 0
    t.boolean  "will_run_live_video",                           default: true
    t.boolean  "will_sell_products",                            default: true
    t.boolean  "will_sell_physical_copies",                     default: true
    t.integer  "annual_income_on_merch_sales",                  default: 0
    t.integer  "annual_performances_count",                     default: 0
    t.string   "signed_status",                                 default: ""
    t.string   "performance_rights_organization",               default: ""
    t.string   "ipi_cae_number",                                default: ""
    t.string   "website_1_url",                    limit: 1023, default: ""
    t.string   "website_2_url",                    limit: 1023, default: ""
    t.uuid     "sub_genre_id"
    t.boolean  "is_business_registered",                        default: true
    t.integer  "artists_count",                                 default: 0
    t.string   "standard_brand_type",                           default: ""
    t.string   "customized_brand_type",                         default: ""
    t.integer  "employees_count",                               default: 1
    t.integer  "years_in_business",                             default: 0
    t.boolean  "will_sell_music_related_products",              default: true
    t.integer  "products_count",                                default: 0
    t.integer  "annual_income",                                 default: 0
    t.index ["approver_id"], name: "index_users_on_approver_id", using: :btree
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
    t.index ["email"], name: "index_users_on_email", unique: true, using: :btree
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
    t.index ["slug"], name: "index_users_on_slug", unique: true, using: :btree
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true, using: :btree
    t.index ["username"], name: "index_users_on_username", unique: true, using: :btree
  end

  create_table "users_albums", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "user_id"
    t.uuid     "album_id"
    t.string   "user_type"
    t.string   "user_role"
    t.string   "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id"], name: "index_users_albums_on_album_id", using: :btree
    t.index ["user_id"], name: "index_users_albums_on_user_id", using: :btree
  end

  create_table "users_products", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid     "user_id"
    t.uuid     "product_id"
    t.string   "user_type"
    t.integer  "user_share",  default: 100
    t.string   "status"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "recoup_cost", default: 0
    t.index ["product_id"], name: "index_users_products_on_product_id", using: :btree
    t.index ["user_id"], name: "index_users_products_on_user_id", using: :btree
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id", using: :btree
  end

  add_foreign_key "mailboxer_conversation_opt_outs", "mailboxer_conversations", column: "conversation_id", name: "mb_opt_outs_on_conversations_id"
  add_foreign_key "mailboxer_notifications", "mailboxer_conversations", column: "conversation_id", name: "notifications_on_conversation_id"
  add_foreign_key "mailboxer_receipts", "mailboxer_notifications", column: "notification_id", name: "receipts_on_notification_id"
end
