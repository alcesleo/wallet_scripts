require "json"
require "sequel"
require "dotenv/load"

EXPORT_PATH      = File.expand_path(ENV.fetch("EXPORT_PATH"))
SUBFOLDER        = Date.today.iso8601
FULL_EXPORT_PATH = File.join(EXPORT_PATH, SUBFOLDER)

DB = Sequel.connect('postgres://localhost:5432/wallet')

class Record < Sequel::Model
end

def get_exported_json(name)
  json = File.read(File.join(FULL_EXPORT_PATH, "#{name}.json"))
  JSON.parse(json)
end

def request_id_hash(name, key_name)
  get_exported_json(name).each_with_object({}) { |item, result| result[item.fetch("id")] = item.fetch(key_name) }
end

def categories
  @_CATEGORIES ||= request_id_hash("categories", "name")
end

def currencies
  @_CURRENCIES ||= request_id_hash("currencies", "code")
end

def all_records
  @_ALL_RECORDS ||= get_exported_json("records")
end

# Dump all the records into the database
all_records.each do |record|
  Record.create(
    category:      categories.fetch(record.fetch("categoryId")),
    amount:        record.fetch("amount"),
    currency:      currencies.fetch(record.fetch("currencyId")),
    amount_in_eur: record.fetch("refAmount"),
    description:   record.fetch("note"),
    payment_type:  record.fetch("paymentType"),
    timestamp:     record.fetch("date"),
  )
end
