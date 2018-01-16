# Converts a Wallet JSON export to a more manageable CSV

require "csv"
require "dotenv/load"
require "fileutils"
require "http"
require "json"
require "pp"

EXPORT_PATH      = File.expand_path(ENV.fetch("EXPORT_PATH"))
SUBFOLDER        = Date.today.iso8601
FULL_EXPORT_PATH = File.join(EXPORT_PATH, SUBFOLDER)

def currencies
  @_currencies = get_json("currencies").each_with_object({}) { |currency, hash|
    hash[currency.fetch("id")] = currency.fetch("code")
  }
end

def categories
  @_categories = get_json("categories").each_with_object({}) { |category, hash|
    hash[category.fetch("id")] = category.fetch("name")
  }
end

def accounts
  @_accounts = get_json("accounts").each_with_object({}) { |account, hash|
    hash[account.fetch("id")] = account.fetch("name")
  }
end

def parse_category(transaction)
  categories.fetch(transaction.fetch("categoryId"))
end

def parse_date(transaction)
  Date.parse(transaction.fetch("date"))
end

def parse_currency(transaction)
  currencies.fetch(transaction.fetch("currencyId"))
end

def parse_account(transaction)
  accounts.fetch(transaction.fetch("accountId"))
end

def transactions
  @_transactions = get_json("records")
end

def get_json(filename)
  JSON.parse(File.read(File.join(FULL_EXPORT_PATH, "#{filename}.json")))
end

def write_csv
  CSV.open("wallet_backup.csv", "w") do |csv|
    csv << ["Date", "Category", "Description", "Amount", "Currency", "Amount in EUR", "Account"]
    write_rows(csv)
  end
end

def write_rows(csv)
  transactions
    .sort_by { |t| parse_date(t) }
    .each do |t|
    csv << [
      parse_date(t),
      parse_category(t),
      t.fetch("note", ""),
      t.fetch("amount"),
      parse_currency(t),
      t.fetch("refAmount"),
      parse_account(t),
    ]
  end
end

write_csv
