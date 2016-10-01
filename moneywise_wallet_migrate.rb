# This is a quick script migrating data from MoneyWise to Wallet
#
# MoneyWise: https://play.google.com/store/apps/details?id=com.handynorth.moneywise
# Wallet: https://play.google.com/store/apps/details?id=com.droid4you.application.wallet
#
# It uses MoneyWise's CSV export to upload via the Wallet API.
#
# Data loss/Things I did not care about.
#     - Time. All records will be at 00:00 at the correct date.
#     - Accounts. Everything will go into the same account.
#     - Record state/payment type. These are always "cleared" and "cash"
#
# Usage:
# - Set up and log into your Wallet account
# - Get the API key from the app
# - Create all the currencies and categories that you need, this script will NOT do that
# - Configure the script using the constants below, you need
#     - MONEYWISE_CSV: Path to the CSV export
#     - WALLET_AUTH: Credentials and user email to Wallet
#     - BATCH_SIZE: You probably do not need to tweak this
#     - ACCOUNT: Every record will go into this.
#     - CATEGORY_MAP:
#          To configure the CATEGORY_MAP you may switch out the comment at the
#          bottom to display which categories are currently available in both
#          MoneyWise and Wallet. However, the script WILL fail before it tries
#          to upload anything if they do not correspond perfectly.
# - Install httprb if you haven't already: gem install http
# - Run the script: ruby moneywise_wallet_migrate.rb
#
# API Documentation: http://docs.budgetbakersv30apiv1.apiary.io/#

require "http"
require "json"
require "csv"
require "date"

MONEYWISE_CSV = "./moneywise_2016-09-16.csv"

WALLET_AUTH = {
  x_token: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  x_user:  "example@email.com",
}

# The number of records to upload at a time.
BATCH_SIZE=30

ACCOUNT="My account"

# Map MoneyWise categories to the Wallet category they should correspond to
CATEGORY_MAP = {
  "Supplies"               => "Groceries",
  "Restaurant"             => "Eating out",
  "People"                 => "Personal",
  "Entertainment"          => "Entertainment, culture",
  "Entertainment : Book"   => "Entertainment, culture",
  "Entertainment : Cinema" => "Entertainment, culture",
  "Car"                    => "Car",
  "Tech"                   => "Electronics",
  "Public Transport"       => "Transport",
  "Bills"                  => "Bills",
  "Big"                    => "Others",
  "Rent"                   => "Rent",
  "Salary"                 => "Salary",
  "Travel"                 => "Vacation",
  "Apartment"              => "Household, utilities",
  "Services"               => "Others",
  "Clothing"               => "Wardrobe",
  "Sport"                  => "Sport"
}

def conn
  @_CONN ||= HTTP.persistent("https://api.budgetbakers.com").headers(WALLET_AUTH)
end

# Performs a request to path and returns a hash of key_name to the id:s found in the response
def request_id_hash(path, key_name)
  response = JSON.parse(conn.get(path))
  response.each_with_object({}) { |item, result| result[item.fetch(key_name)] = item.fetch("id") }
end

def categories
  @_CATEGORIES ||= request_id_hash("/api/v1/categories", "name")
end

def currencies
  @_CURRENCIES ||= request_id_hash("/api/v1/currencies", "code")
end

def accounts
  @_ACCOUNTS ||= request_id_hash("/api/v1/accounts", "name")
end

def build_record(amount:, account:, note:, date:, currency:, category:)
  {
    "categoryId"  => categories.fetch(CATEGORY_MAP.fetch(category)),
    "accountId"   => accounts.fetch(account),
    "currencyId"  => currencies.fetch(currency),
    "amount"      => amount.to_f,
    "paymentType" => "cash",
    "date"        => Date.parse(date).to_datetime.strftime("%FT%T.000Z"),
    "note"        => note,
    "recordState" => "cleared"
  }
end

def build_records_from_csv
  result = []
  CSV.foreach(MONEYWISE_CSV, headers: true) do |row|
    result << build_record(
      account:  ACCOUNT,
      amount:   row["Amount"],
      category: row["Category"],
      currency: row["Currency"],
      date:     row["Date"],
      note:     row["Description"],
    )
  end
  result
end

def upload_records_to_wallet(records)
  json = JSON.pretty_generate(records)
  conn.headers(content_type: "application/json")
      .post("/api/v1/records-bulk", body: json)
end

def batch_upload(records, batch_size)
  records.each_slice(batch_size) do |record_slice|
    print "Uploading #{batch_size} records... "
    response = upload_records_to_wallet(record_slice)
    if response.code == 201
      puts "Success!"
    else
      puts response
      puts response.inspect
      return
    end
    sleep 0.1
  end
end

def migrate
  batch_upload(build_records_from_csv, BATCH_SIZE)
end

# Helper to get the category map right
def view_existing_categories
  puts "MoneyWise categories:"
  moneywise_categories = []
  CSV.foreach(MONEYWISE_CSV, headers: true) do |row|
    moneywise_categories << row["Category"]
  end
  puts moneywise_categories.uniq
  puts

  puts "Wallet categories:"
  puts categories.keys
end


### RUN

# Comment out the step you'd like to perform
migrate
# view_existing_categories
