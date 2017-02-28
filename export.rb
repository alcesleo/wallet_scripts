require "http"
require "json"
require "fileutils"
require "dotenv/load"

EXPORT_PATH      = File.expand_path(ENV.fetch("EXPORT_PATH"))
SUBFOLDER        = Date.today.iso8601
FULL_EXPORT_PATH = File.join(EXPORT_PATH, SUBFOLDER)

FileUtils.mkdir_p(File.join(EXPORT_PATH, SUBFOLDER))

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

def write_to_file(path, data)
  File.write(path, JSON.pretty_generate(data))
end

def export(api_path, filename)
  puts "Writing #{api_path} to #{filename}"
  destination = File.join(FULL_EXPORT_PATH, filename)
  write_to_file(destination, get_json(api_path))
end

export("/api/v1/records", "records.json")
export("/api/v1/categories", "categories.json")
export("/api/v1/currencies", "currencies.json")
export("/api/v1/accounts", "accounts.json")
