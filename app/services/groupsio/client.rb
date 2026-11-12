require "net/http"

module Groupsio
  # Read-only client for https://groups.io/api, authenticated with an API key
  # (https://groups.io/settings/apikeys) sent as a Bearer token.
  class Client
    BASE = "https://groups.io/api/v1".freeze

    class Error < StandardError
      attr_reader :type, :status

      def initialize(type, extra, status)
        @type = type
        @status = status
        super("groups.io #{type}#{": #{extra}" if extra.present?} (HTTP #{status})")
      end
    end

    def initialize(api_key: ENV["GROUPSIO_API_KEY"], group: Groupsio.group_name)
      raise ArgumentError, "GROUPSIO_API_KEY is not set" if api_key.blank?

      @api_key = api_key
      @group = group
    end

    # Most recently active topics first.
    def topics(max: 20)
      paginate("gettopics", { group_name: @group, sort_field: "recentpostdate", sort_dir: "desc" }, max:)
    end

    # All messages in a topic, oldest first.
    def topic_messages(topic_id)
      paginate("gettopic", { topic_id:, sort_field: "Created", sort_dir: "asc" }, max: 1_000)
    end

    private

    def paginate(endpoint, params, max:)
      items = []
      page_token = nil
      loop do
        page = get(endpoint, params.merge(limit: [max - items.size, 100].min, page_token:))
        items.concat(page["data"] || [])
        page_token = page["has_more"] ? page["next_page_token"] : nil
        break if page_token.blank? || items.size >= max
      end
      items
    end

    def get(endpoint, params)
      uri = URI("#{BASE}/#{endpoint}")
      uri.query = URI.encode_www_form(params.compact)
      attempts = 0

      loop do
        req = Net::HTTP::Get.new(uri, "Authorization" => "Bearer #{@api_key}", "Accept" => "application/json")
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { _1.request(req) }

        # 429s come back with an empty body; back off with jitter and retry.
        if res.code == "429" && (attempts += 1) <= 4
          sleep(0.5 * 2**attempts + rand * 0.25)
          next
        end

        json = begin
          res.body.present? ? JSON.parse(res.body) : {}
        rescue JSON::ParserError
          raise Error.new("bad_response", res.body.to_s[0, 200], res.code.to_i)
        end

        if !res.is_a?(Net::HTTPSuccess) || json["object"] == "error"
          raise Error.new(json["type"] || "http_error", json["extra"], res.code.to_i)
        end

        return json
      end
    end
  end
end
