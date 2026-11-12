module Groupsio
  # Pulls recently active topics from groups.io into games/messages, then asks
  # Claude to (re)read any thread that has new messages.
  class Sync
    def self.call(...) = new(...).call

    def initialize(max_topics: 20, client: Client.new, extract: true)
      @max_topics = max_topics
      @client = client
      @extract = extract
    end

    def call
      stats = { topics: 0, new_messages: 0, extracted: 0, errors: [] }

      @client.topics(max: @max_topics).each do |topic|
        stats[:topics] += 1
        game = sync_topic(topic, stats)
        next unless @extract && game.needs_extraction?

        GameExtractor.call(game)
        stats[:extracted] += 1
      rescue GameExtractor::Error, Anthropic::Errors::APIError => e
        # One bad thread shouldn't stop the rest of the sync.
        Rails.logger.error("[groupsio] extraction failed for topic #{topic["id"]}: #{e.message}")
        stats[:errors] << "#{topic["id"]}: #{e.message}"
      end

      Rails.logger.info("[groupsio] sync #{stats.except(:errors)} errors=#{stats[:errors].size}")
      stats
    end

    private

    def sync_topic(topic, stats)
      game = Game.find_or_initialize_by(groupsio_topic_id: topic["id"])
      last_post_at = Time.zone.parse(topic["updated"].to_s)
      return game if game.persisted? && game.last_post_at == last_post_at

      game.update!(
        subject: topic["subject"].presence || "(no subject)",
        started_by: topic["name"],
        thread_started_at: Time.zone.parse(topic["created"].to_s),
        last_post_at:
      )

      known = game.messages.pluck(:msg_num).to_set
      @client.topic_messages(topic["id"]).each do |m|
        next if known.include?(m["msg_num"])

        game.messages.create!(
          msg_num: m["msg_num"],
          groupsio_user_id: m["user_id"],
          author_name: m["name"],
          sent_at: Time.zone.parse(m["created"].to_s),
          body: ReplyStripper.call(m["body"], plain_text: m["is_plain_text"] != false)
        )
        stats[:new_messages] += 1
      end

      game
    end
  end
end
