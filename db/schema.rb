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

ActiveRecord::Schema.define(version: 20190327095603) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "activities", force: :cascade do |t|
    t.integer  "sender_id"
    t.integer  "receiver_id"
    t.string   "message"
    t.string   "module_type"
    t.string   "action_type"
    t.integer  "alert_type"
    t.string   "page_track"
    t.string   "assoc_type"
    t.integer  "assoc_id"
    t.string   "status"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.index ["assoc_type", "assoc_id"], name: "index_activities_on_assoc_type_and_assoc_id", using: :btree
    t.index ["receiver_id"], name: "index_activities_on_receiver_id", using: :btree
    t.index ["sender_id"], name: "index_activities_on_sender_id", using: :btree
  end

  create_table "albums", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "name"
    t.string   "slug"
    t.text     "description"
    t.string   "artist_name"
    t.string   "cover"
    t.integer  "album_type"
    t.string   "zip"
    t.datetime "zipped_at"
    t.boolean  "recommended"
    t.datetime "recommended_at"
    t.boolean  "released"
    t.datetime "released_at"
    t.integer  "played",                  default: 0
    t.integer  "downloaded",              default: 0
    t.integer  "reposted",                default: 0
    t.integer  "commented",               default: 0
    t.string   "location",                default: ""
    t.integer  "collaborators_count",     default: 0
    t.boolean  "enabled_sample",          default: false
    t.boolean  "is_only_for_live_stream", default: false
    t.boolean  "is_content_acapella",     default: false
    t.boolean  "is_content_instrumental", default: false
    t.boolean  "is_content_stems",        default: false
    t.boolean  "is_content_remix",        default: false
    t.boolean  "is_content_dj_mix",       default: false
    t.string   "status"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.index ["slug"], name: "index_albums_on_slug", unique: true, using: :btree
    t.index ["user_id"], name: "index_albums_on_user_id", using: :btree
  end

  create_table "albums_tracks", force: :cascade do |t|
    t.integer "album_id"
    t.integer "track_id"
    t.integer "position", default: 0
    t.index ["album_id", "track_id"], name: "index_albums_tracks_on_album_id_and_track_id", unique: true, using: :btree
  end

  create_table "attachments", force: :cascade do |t|
    t.integer  "mailboxer_notification_id"
    t.string   "attachment_type",           default: "repost"
    t.string   "attachable_type"
    t.integer  "attachable_id"
    t.string   "payment_customer_id"
    t.string   "payment_token"
    t.integer  "repost_price",              default: 100,      null: false
    t.string   "status"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.index ["attachable_type", "attachable_id"], name: "index_attachments_on_attachable_type_and_attachable_id", using: :btree
  end

  create_table "attendees", force: :cascade do |t|
    t.string   "full_name"
    t.string   "display_name"
    t.string   "email"
    t.string   "account_type",     default: "artist"
    t.string   "referred_by",      default: ""
    t.integer  "referrer_id"
    t.integer  "user_id"
    t.string   "invitation_token"
    t.datetime "invited_at"
    t.string   "status",           default: "created"
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.index ["display_name"], name: "index_attendees_on_display_name", unique: true, using: :btree
    t.index ["email"], name: "index_attendees_on_email", unique: true, using: :btree
    t.index ["invitation_token"], name: "index_attendees_on_invitation_token", unique: true, using: :btree
    t.index ["referrer_id"], name: "index_attendees_on_referrer_id", using: :btree
    t.index ["user_id"], name: "index_attendees_on_user_id", using: :btree
  end

  create_table "comments", force: :cascade do |t|
    t.integer  "user_id"
    t.text     "body"
    t.string   "commentable_type"
    t.integer  "commentable_id"
    t.string   "status"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id", using: :btree
  end

  create_table "feeds", force: :cascade do |t|
    t.integer  "consumer_id"
    t.integer  "publisher_id"
    t.integer  "ancestor_id"
    t.string   "feed_type"
    t.string   "assoc_type"
    t.integer  "assoc_id"
    t.string   "status"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.index ["ancestor_id"], name: "index_feeds_on_ancestor_id", using: :btree
    t.index ["assoc_type", "assoc_id"], name: "index_feeds_on_assoc_type_and_assoc_id", using: :btree
    t.index ["consumer_id"], name: "index_feeds_on_consumer_id", using: :btree
    t.index ["publisher_id"], name: "index_feeds_on_publisher_id", using: :btree
  end

  create_table "follows", force: :cascade do |t|
    t.string   "followable_type",                 null: false
    t.integer  "followable_id",                   null: false
    t.string   "follower_type",                   null: false
    t.integer  "follower_id",                     null: false
    t.boolean  "blocked",         default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["followable_id", "followable_type"], name: "fk_followables", using: :btree
    t.index ["follower_id", "follower_type"], name: "fk_follows", using: :btree
  end

  create_table "genres", force: :cascade do |t|
    t.string  "name"
    t.text    "description"
    t.integer "position",    default: 0
    t.string  "slug"
    t.string  "ancestry"
    t.string  "color",       default: ""
    t.string  "region",      default: ""
    t.integer "sequence",    default: 0
    t.index ["ancestry"], name: "index_genres_on_ancestry", using: :btree
    t.index ["slug"], name: "index_genres_on_slug", unique: true, using: :btree
  end

  create_table "mailboxer_conversation_opt_outs", force: :cascade do |t|
    t.string  "unsubscriber_type"
    t.integer "unsubscriber_id"
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
    t.integer  "sender_id"
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
    t.integer  "receiver_id"
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

  create_table "payments", force: :cascade do |t|
    t.integer  "sender_id"
    t.string   "sender_stripe_id"
    t.integer  "receiver_id"
    t.string   "receiver_stripe_id"
    t.string   "description",        default: ""
    t.string   "payment_type"
    t.string   "payment_token"
    t.integer  "sent_amount",        default: 0
    t.integer  "received_amount"
    t.integer  "fee",                default: 0
    t.integer  "shipping_cost",      default: 0
    t.integer  "tax",                default: 0
    t.integer  "refund_amount",      default: 0
    t.string   "assoc_type"
    t.integer  "assoc_id"
    t.integer  "order_id"
    t.integer  "user_share",         default: 0
    t.integer  "attachment_id"
    t.string   "status"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.index ["assoc_type", "assoc_id"], name: "index_payments_on_assoc_type_and_assoc_id", using: :btree
    t.index ["attachment_id"], name: "index_payments_on_attachment_id", using: :btree
    t.index ["order_id"], name: "index_payments_on_order_id", using: :btree
    t.index ["receiver_id"], name: "index_payments_on_receiver_id", using: :btree
    t.index ["sender_id"], name: "index_payments_on_sender_id", using: :btree
  end

  create_table "presets", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "context",    limit: 128
    t.string   "name"
    t.text     "data",                   default: ""
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.index ["user_id", "context"], name: "index_presets_on_user_id_and_context", using: :btree
    t.index ["user_id"], name: "index_presets_on_user_id", using: :btree
  end

  create_table "relations", force: :cascade do |t|
    t.integer  "host_id"
    t.integer  "client_id"
    t.string   "context"
    t.string   "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_relations_on_client_id", using: :btree
    t.index ["host_id"], name: "index_relations_on_host_id", using: :btree
  end

  create_table "roles", force: :cascade do |t|
    t.string   "name"
    t.string   "resource_type"
    t.integer  "resource_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id", using: :btree
    t.index ["name"], name: "index_roles_on_name", using: :btree
  end

  create_table "samplings", force: :cascade do |t|
    t.integer  "sampling_user_id"
    t.integer  "sampling_album_id"
    t.integer  "sampling_track_id"
    t.integer  "sample_user_id"
    t.integer  "sample_album_id"
    t.integer  "sample_track_id"
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

  create_table "settings", force: :cascade do |t|
    t.string "key"
    t.string "value"
  end

  create_table "shop_addresses", force: :cascade do |t|
    t.integer  "customer_id"
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
    t.string   "status"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.index ["customer_id"], name: "index_shop_addresses_on_customer_id", using: :btree
  end

  create_table "shop_carts", force: :cascade do |t|
    t.integer  "customer_id"
    t.text     "notes"
    t.string   "status"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.index ["customer_id"], name: "index_shop_carts_on_customer_id", using: :btree
  end

  create_table "shop_categories", force: :cascade do |t|
    t.string   "name"
    t.string   "description"
    t.boolean  "is_digital",  default: false
    t.string   "status"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "shop_items", force: :cascade do |t|
    t.integer  "customer_id"
    t.integer  "merchant_id"
    t.integer  "product_id"
    t.integer  "product_variant_id"
    t.integer  "cart_id"
    t.integer  "order_id"
    t.integer  "price"
    t.integer  "quantity"
    t.integer  "fee",                default: 0
    t.integer  "shipping_cost",      default: 0
    t.integer  "tax",                default: 0
    t.integer  "tax_percent",        default: 0
    t.integer  "decimal",            default: 0
    t.boolean  "is_vat",             default: false
    t.string   "status"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "tracking_site"
    t.text     "tracking_url"
    t.string   "tracking_number"
    t.index ["cart_id"], name: "index_shop_items_on_cart_id", using: :btree
    t.index ["customer_id"], name: "index_shop_items_on_customer_id", using: :btree
    t.index ["merchant_id"], name: "index_shop_items_on_merchant_id", using: :btree
    t.index ["order_id"], name: "index_shop_items_on_order_id", using: :btree
    t.index ["product_id"], name: "index_shop_items_on_product_id", using: :btree
    t.index ["product_variant_id"], name: "index_shop_items_on_product_variant_id", using: :btree
  end

  create_table "shop_orders", force: :cascade do |t|
    t.integer  "customer_id"
    t.integer  "merchant_id"
    t.integer  "cart_id"
    t.integer  "billing_address_id"
    t.integer  "shipping_address_id"
    t.boolean  "enabled_address",     default: true
    t.integer  "amount"
    t.integer  "fee",                 default: 0
    t.integer  "shipping_cost",       default: 0
    t.integer  "tax_cost",            default: 0
    t.string   "provider"
    t.string   "payment_customer_id"
    t.string   "payment_token"
    t.integer  "payment_id"
    t.string   "ship_method"
    t.string   "tracking_number"
    t.string   "tracking_url"
    t.string   "status"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.index ["billing_address_id"], name: "index_shop_orders_on_billing_address_id", using: :btree
    t.index ["cart_id"], name: "index_shop_orders_on_cart_id", using: :btree
    t.index ["customer_id"], name: "index_shop_orders_on_customer_id", using: :btree
    t.index ["merchant_id"], name: "index_shop_orders_on_merchant_id", using: :btree
    t.index ["payment_id"], name: "index_shop_orders_on_payment_id", using: :btree
    t.index ["shipping_address_id"], name: "index_shop_orders_on_shipping_address_id", using: :btree
  end

  create_table "shop_product_covers", force: :cascade do |t|
    t.integer  "product_id"
    t.string   "cover"
    t.integer  "position",   default: 0
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.index ["product_id"], name: "index_shop_product_covers_on_product_id", using: :btree
  end

  create_table "shop_product_shipments", force: :cascade do |t|
    t.integer  "product_id"
    t.string   "country"
    t.integer  "shipment_alone_price"
    t.integer  "shipment_with_price"
    t.string   "status"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["product_id"], name: "index_shop_product_shipments_on_product_id", using: :btree
  end

  create_table "shop_product_variants", force: :cascade do |t|
    t.integer  "product_id"
    t.integer  "variant_id"
    t.string   "name"
    t.integer  "price",      default: 100
    t.integer  "quantity",   default: 0
    t.string   "status"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.index ["product_id"], name: "index_shop_product_variants_on_product_id", using: :btree
    t.index ["variant_id"], name: "index_shop_product_variants_on_variant_id", using: :btree
  end

  create_table "shop_products", force: :cascade do |t|
    t.integer  "merchant_id"
    t.integer  "category_id"
    t.string   "name"
    t.string   "description"
    t.integer  "position",                                      default: 0
    t.integer  "price"
    t.decimal  "weight"
    t.decimal  "height"
    t.decimal  "width"
    t.decimal  "depth"
    t.string   "digital_content"
    t.string   "digital_content_name"
    t.boolean  "is_vat",                                        default: false
    t.decimal  "tax_percent",          precision: 10, scale: 6, default: "0.0"
    t.string   "seller_location"
    t.integer  "reposted",                                      default: 0
    t.integer  "sold",                                          default: 0
    t.integer  "quantity",                                      default: 0
    t.integer  "collaborators_count",                           default: 0
    t.boolean  "released",                                      default: false
    t.datetime "released_at"
    t.string   "stock_status",                                  default: "active"
    t.string   "show_status",                                   default: "show_all"
    t.string   "status"
    t.datetime "created_at",                                                         null: false
    t.datetime "updated_at",                                                         null: false
    t.index ["category_id"], name: "index_shop_products_on_category_id", using: :btree
    t.index ["merchant_id"], name: "index_shop_products_on_merchant_id", using: :btree
  end

  create_table "shop_variants", force: :cascade do |t|
    t.string   "name"
    t.text     "options_json"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "streams", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "genre_id"
    t.string   "name"
    t.text     "description",           default: ""
    t.string   "cover"
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
    t.integer  "assoc_id"
    t.integer  "played_period",         default: 0
    t.integer  "valid_period",          default: 0
    t.integer  "view_price",            default: 0
    t.integer  "viewers_limit",         default: 0
    t.string   "status",                default: "active"
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.index ["assoc_type", "assoc_id"], name: "index_streams_on_assoc_type_and_assoc_id", using: :btree
    t.index ["genre_id"], name: "index_streams_on_genre_id", using: :btree
    t.index ["id", "user_id"], name: "index_streams_on_id_and_user_id", using: :btree
    t.index ["user_id"], name: "index_streams_on_user_id", using: :btree
  end

  create_table "taggings", force: :cascade do |t|
    t.integer  "tag_id"
    t.string   "taggable_type"
    t.integer  "taggable_id"
    t.string   "tagger_type"
    t.integer  "tagger_id"
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

  create_table "tags", force: :cascade do |t|
    t.string  "name"
    t.integer "taggings_count", default: 0
    t.index ["name"], name: "index_tags_on_name", unique: true, using: :btree
  end

  create_table "tracks", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "album_id"
    t.string   "name"
    t.string   "slug"
    t.text     "description"
    t.string   "audio"
    t.string   "clip"
    t.string   "acr_id"
    t.integer  "played",      default: 0
    t.integer  "downloaded",  default: 0
    t.string   "status"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.index ["album_id"], name: "index_tracks_on_album_id", using: :btree
    t.index ["slug"], name: "index_tracks_on_slug", unique: true, using: :btree
    t.index ["user_id"], name: "index_tracks_on_user_id", using: :btree
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                            default: "",         null: false
    t.string   "encrypted_password",               default: "",         null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                    default: 0,          null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",                  default: 0,          null: false
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.string   "username"
    t.string   "display_name"
    t.string   "user_type",                        default: "listener"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "slug"
    t.string   "avatar"
    t.string   "contact_url"
    t.boolean  "enable_alert",                     default: false
    t.integer  "repost_price",                     default: 100,        null: false
    t.integer  "address_id"
    t.integer  "timezone_offset"
    t.integer  "followings_count",                 default: 0
    t.integer  "followers_count",                  default: 0
    t.integer  "invited_user_id"
    t.integer  "invitation_limit"
    t.boolean  "consigned",                        default: false
    t.integer  "inviter_id"
    t.datetime "invited_at"
    t.string   "social_provider"
    t.string   "social_user_id"
    t.string   "social_user_name"
    t.string   "social_token"
    t.string   "social_token_secret"
    t.string   "payment_provider"
    t.string   "payment_account_id"
    t.string   "payment_account_type"
    t.string   "payment_publishable_key"
    t.string   "payment_access_code"
    t.integer  "balance_amount",                   default: 0
    t.datetime "repost_price_end_at"
    t.datetime "message_first_visited_time"
    t.integer  "approver_id"
    t.datetime "approved_at"
    t.text     "return_policy",                    default: ""
    t.text     "shipping_policy",                  default: ""
    t.text     "privacy_policy",                   default: ""
    t.text     "size_chart",                       default: ""
    t.boolean  "enabled_live_video",               default: true
    t.boolean  "enabled_live_video_free",          default: false
    t.boolean  "enabled_view_direct_messages",     default: false
    t.integer  "stream_rolled_time",               default: 0
    t.integer  "stream_rolled_cost",               default: 0
    t.integer  "free_streamed_time",               default: 0
    t.integer  "max_repost_price",                 default: 100
    t.string   "request_role"
    t.string   "request_status"
    t.string   "denial_reason",                    default: ""
    t.text     "denial_description",               default: ""
    t.integer  "genre_id"
    t.integer  "sub_genre_id"
    t.integer  "year_of_birth",                    default: 0
    t.string   "gender",                           default: ""
    t.string   "country",                          default: ""
    t.string   "city",                             default: ""
    t.string   "artist_type",                      default: ""
    t.integer  "released_albums_count",            default: 0
    t.integer  "years_since_first_released",       default: 0
    t.boolean  "will_run_live_video",              default: true
    t.boolean  "will_sell_products",               default: true
    t.boolean  "will_sell_physical_copies",        default: true
    t.integer  "annual_income_on_merch_sales",     default: 0
    t.integer  "annual_performances_count",        default: 0
    t.string   "signed_status",                    default: ""
    t.string   "performance_rights_organization",  default: ""
    t.string   "ipi_cae_number",                   default: ""
    t.text     "website_1_url",                    default: ""
    t.text     "website_2_url",                    default: ""
    t.text     "history",                          default: ""
    t.boolean  "is_business_registered",           default: true
    t.integer  "artists_count",                    default: 0
    t.string   "standard_brand_type",              default: ""
    t.string   "customized_brand_type",            default: ""
    t.integer  "employees_count",                  default: 1
    t.integer  "years_in_business",                default: 0
    t.boolean  "will_sell_music_related_products", default: true
    t.integer  "products_count",                   default: 0
    t.integer  "annual_income",                    default: 0
    t.string   "status"
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
    t.jsonb    "data",                             default: {}
    t.index ["approver_id"], name: "index_users_on_approver_id", using: :btree
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
    t.index ["email"], name: "index_users_on_email", unique: true, using: :btree
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
    t.index ["slug"], name: "index_users_on_slug", unique: true, using: :btree
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true, using: :btree
    t.index ["username"], name: "index_users_on_username", unique: true, using: :btree
  end

  create_table "users_albums", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "album_id"
    t.string   "user_type"
    t.string   "user_role"
    t.string   "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id"], name: "index_users_albums_on_album_id", using: :btree
    t.index ["user_id"], name: "index_users_albums_on_user_id", using: :btree
  end

  create_table "users_products", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "product_id"
    t.string   "user_type"
    t.integer  "user_share",  default: 100
    t.integer  "recoup_cost", default: 0
    t.string   "status"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.index ["product_id"], name: "index_users_products_on_product_id", using: :btree
    t.index ["user_id"], name: "index_users_products_on_user_id", using: :btree
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id", using: :btree
  end

  add_foreign_key "mailboxer_conversation_opt_outs", "mailboxer_conversations", column: "conversation_id", name: "mb_opt_outs_on_conversations_id"
  add_foreign_key "mailboxer_notifications", "mailboxer_conversations", column: "conversation_id", name: "notifications_on_conversation_id"
  add_foreign_key "mailboxer_receipts", "mailboxer_notifications", column: "notification_id", name: "receipts_on_notification_id"
end
