# Starts with an empty MoneyWise backup where you have already created the
# categories you want, and fills it up with the records from the CSV

require "csv"
require "sequel"
require "date"


# The exclude_savings file has been modified manually to take the inverted
# Swedish amount instead of the incorrect one converted to Euro
CSV_PATH = "wallet_backup.csv"
BACKUP_PATH = "money_wise_db.mdb"
DB = Sequel.connect("sqlite://#{BACKUP_PATH}")

# Taken from Wallet
# Needed because the default currency is different
EUR_TO_SEK = 9.81583

ACCOUNT_ID = 1

# Map Wallet categories to the MoneyWise category they should correspond to
CATEGORY_MAP = {
  "Vacation"                 => "Travel",
  "Long distance"            => "Travel",
  "Snacking"                 => "Snacking",
  "Eating out"               => "Restaurant",
  "Health and beauty"        => "Health",
  "Wellness, beauty"         => "Health",
  "Health care, doctor"      => "Medical",
  "Income"                   => ["Gifts", "Received"],
  "Electronics, accessories" => "Shopping",
  "Rental income"            => ["Finance", "Rental Income"],
  "Subscriptions"            => ["Technology", "Subscriptions"],
  "Books"                    => ["Entertainment", "Books"],
  "Free time"                => ["Entertainment", "Board Games"],
  "Audio books"              => ["Entertainment", "Books"],
  "Cinema"                   => ["Entertainment", "Cinema"],
  "Charity"                  => ["Gifts", "Donated"],
  "Android apps"             => ["Technology", "Apps"],
  "Fuel"                     => ["Vehicle", "Fuel"],
  "Groceries"                => "Groceries",
  "Shopping"                 => "Shopping",
  "Sale"                     => ["Finance", "Sales"],
  "Public transport"         => "Public Transport",
  "Cleaning"                 => "Home",
  "Bills"                    => "Bills",
  "Gifts"                    => ["Gifts", "Received"],
  "Gifts, joy"               => ["Gifts", "Bought"],
  "Salary"                   => "Salary",
  "Debt"                     => "Personal",
  "Maintenance, repairs"     => ["Bills", "Unforeseen"],
  "Insurances"               => ["Bills", "Insurance"],
  "Home"                     => "Home",
  "Rent"                     => "Rent",
  "Repayments"               => "Personal",
  "Personal"                 => "Personal",
  "Software, apps, games"    => ["Technology", "Apps"],
  "Vehicle"                  => ["Vehicle", "Fees"],
  "Vehicle insurance"        => ["Vehicle", "Vehicle Insurance"],
  "Vehicle maintenance"      => ["Vehicle", "Vehicle Maintenance"],
  "Parking"                  => ["Vehicle", "Parking"],
  "Sport"                    => ["Health", "Exercise"],
  "Console games"            => ["Technology", "Games"],
  "Charges, Fees"            => ["Finance", "Expenses"],
  "Stationery, tools"        => ["Utilities", "Supplies"],
  "Housing"                  => "Home",
  "Postal services"          => ["Utilities", "Postal Services"],
  "Others"                   => "Uncategorized",
  "Transfer"                 => ["Finance", "Investment / Savings"],
  "Events"                   => ["Entertainment", "Events"],
  "Electronics"              => ["Technology", "Electronics"],
  "Taxes"                    => ["Finance", "Taxes"],
  "Refunds (tax, purchase)"  => "Uncategorized",
  "Interests, dividends"     => ["Finance", "Investment / Savings"],
  "Culture, sport events"    => ["Entertainment", "Events"],
  "Clothes & shoes"          => "Clothing",
  "Phone, cell phone"        => ["Bills", "Phone"],
  "Digital service"          => ["Technology", "Subscriptions"],
  "Eating at work"           => ["Restaurant", "Work"],
  "Charity, gifts"           => ["Gifts", "Donated"],
  "Advisory"                 => ["Finance", "Expenses"],
  "Fees, fines"              => ["Vehicle", "Fees"],
}

# Returns [category_index, subcategory_index]
def category_indices(row)
  wallet_category   = row.fetch("Category")
  db_categories     = DB[:categories].all.each_with_object({}) { |c, h| h[c.fetch(:name)] = c.fetch(:_ID) }
  db_sub_categories = DB[:sub_categories].all.each_with_object({}) { |c, h| h[c.fetch(:name)] = c.fetch(:_ID) }

  category_name, sub_category_name = CATEGORY_MAP.fetch(wallet_category)

  [
    db_categories.fetch(category_name),
    db_sub_categories.fetch(sub_category_name, -1)
  ]
end

def amount_in_sek(row)
  currency = row.fetch("Currency")
  amount = row.fetch("Amount").to_f

  if currency == "SEK"
    amount
  elsif currency == "EUR"
    (amount * EUR_TO_SEK).round(2)
  else
    (row.fetch("Amount in EUR").to_f * EUR_TO_SEK).round(2)
  end
end

def insert_rows
  created = (Time.now.to_f * 1000).round

  account_balance = 0.0

  CSV.foreach(CSV_PATH, headers: true) do |row|
    date = Time.parse(row.fetch("Date"))
    category, sub_category = category_indices(row)

    account_balance += amount_in_sek(row)

    puts "Inserting row #{row}"

    DB[:transactions].insert(
      created:                 created,
      year:                    date.year,
      month:                   date.month - 1, # Months are 0-index
      day:                     date.wday + 1, # Weekdays begin on Sunday and are 1-indexed
      week:                    "%d%02d" % [date.year, date.to_date.cweek],
      category:                category,
      sub_category:            sub_category,
      expense:                 row.fetch("Description"),
      amount:                  row.fetch("Amount").to_f,
      currency:                row.fetch("Currency"),
      amount_default_currency: amount_in_sek(row),
      is_expense:              row.fetch("Amount").to_f.negative? ? 1 : 0,
      account_id:              ACCOUNT_ID,
      date:                    date.to_i * 1000, # Unix time in ms
      modified_date:           date.to_i * 1000, # Unix time in ms
      account_balance:         account_balance,
      pending_account_balance: account_balance,
    )
  end
end

insert_rows
