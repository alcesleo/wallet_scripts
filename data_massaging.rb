require "http"
require "json"
require "pp"
require "dotenv"

Dotenv.load

WALLET_AUTH = {
  x_token: ENV.fetch("WALLET_API_KEY"),
  x_user:  ENV.fetch("WALLET_EMAIL"),
}

def conn
  @_CONN ||= HTTP.persistent("https://api.budgetbakers.com")
                 .headers(WALLET_AUTH)
                 .headers(content_type: "application/json")
end

def get_json(path)
  JSON.parse(conn.get(path))
end

def request_id_hash(path, key_name)
  get_json(path).each_with_object({}) { |item, result| result[item.fetch(key_name)] = item.fetch("id") }
end

def categories
  @_CATEGORIES ||= request_id_hash("/api/v1/categories", "name")
end

def currencies
  @_CURRENCIES ||= request_id_hash("/api/v1/currencies", "code")
end

def all_records
  @_ALL_RECORDS ||= get_json("/api/v1/records")
end

def push_updates!(updates)
  counter = 1
  total   = updates.count
  puts "Pushing #{total} record updates"
  updates.each do |id, payload|
    json = JSON.generate(payload)
    response = conn.put("/api/v1/record/#{id}", body: json)
    puts "#{counter}/#{total}: #{response.code} #{response.reason} - #{payload}"
    counter += 1
  end
end

###################################################
# These are the functions you most likely need to tweak

def filtered_records
  all_records.select { |r| r.fetch("note") =~ /Upcase/ }
end

# Return a tuple: [record_id, updated_attributes_hash]
def record_updates
  filtered_records.map { |r|
    [
      r.fetch("id"),
      {
        categoryId: categories.fetch("Digital services"),
        paymentType: "web_payment"
      }
    ]
  }
end

###################################################
# Call functions to run/debug here

pp filtered_records
pp record_updates
# push_updates!(record_updates)
