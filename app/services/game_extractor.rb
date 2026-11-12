# Reads a game's email thread with Claude and fills in when/where the game is,
# whether it's on, and who's coming. Fields an admin has locked are left alone.
class GameExtractor
  class Error < StandardError; end

  MODEL = "claude-opus-5-5".freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You read email threads from the Crozet, Virginia bike polo group's mailing list and
    extract the details of the pickup game being organized, for display on the group's website.

    How the group works:
    - Someone starts a thread a few days ahead proposing a day and time ("Sunday polo?").
      Others reply with whether they're in, out, or what times work for them.
    - The default location is #{Game::DEFAULT_LOCATION}. The backup is #{Game::BACKUP_LOCATION}
      (sometimes "BCR" or "the reservoir"), used when the park is unavailable — wet or
      closed fields, an event at the park, or someone proposes moving there. Use
      #{Game::DEFAULT_LOCATION} unless the thread points to a different place.
    - All times are US Eastern (America/New_York).

    Rules:
    - Resolve relative days ("Sunday", "tomorrow", "this weekend") against the date of the
      message that says them. Each message is labeled with its sent date and weekday.
    - date / start_time: the game being organized. If the thread settled on a time, use it.
      If not settled, use the time with the most support so far, or the time proposed by
      the thread starter. Use null for start_time if no time has been mentioned, and null for
      date if no day can be worked out.
    - status: "confirmed" if the thread agrees the game is on (e.g. "see you at noon", "it's
      on", or a clear consensus with enough players); "cancelled" if it was called off;
      "proposed" otherwise. Use "not_a_game" for threads that aren't organizing a specific
      game (announcements, gear, general discussion).
    - attendees: one entry per person, using the name shown on their messages (or as
      mentioned, for people named by others). "in" = plans to play, "maybe" = unsure or
      conditional, "out" = not playing. The person proposing a game counts as "in" unless they
      say otherwise. note: a short constraint or detail in their words, like "hard stop at 2"
      or "can bring extra mallets"; empty string if none. Later messages override earlier ones.
    - summary: one or two plain sentences for the website, e.g. "Noon at Crozet Park; Bruno
      and Tyler have a hard stop at 2."
  PROMPT

  SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[status date start_time location summary attendees],
    properties: {
      status: { type: "string", enum: %w[proposed confirmed cancelled not_a_game] },
      date: { type: %w[string null], description: "YYYY-MM-DD" },
      start_time: { type: %w[string null], description: "24-hour HH:MM" },
      location: { type: "string" },
      summary: { type: "string" },
      attendees: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: %w[name status note],
          properties: {
            name: { type: "string" },
            status: { type: "string", enum: Attendance::STATUSES },
            note: { type: "string" }
          }
        }
      }
    }
  }.freeze

  def self.call(game, client: Anthropic::Client.new) = new(game, client:).call

  def initialize(game, client:)
    @game = game
    @client = client
  end

  def call
    messages = @game.messages.to_a
    raise Error, "game #{@game.id} has no messages" if messages.empty?

    data = extract(messages)
    apply(data, through_msg_num: messages.map(&:msg_num).max)
    data
  end

  private

  def extract(messages)
    response = @client.beta.messages.create(
      model: MODEL,
      max_tokens: 16_000,
      system_: SYSTEM_PROMPT,
      messages: [{ role: "user", content: transcript(messages) }],
      output_config: { effort: :medium, format_: { type: :json_schema, schema: SCHEMA } },
      # Retry on a substitute model if the request is declined for policy reasons.
      fallbacks: :default,
      betas: ["server-side-fallback-2026-07-01"]
    )

    if response.stop_reason == :refusal
      raise Error, "Claude declined topic #{@game.groupsio_topic_id}: #{response.stop_details&.explanation}"
    end
    raise Error, "response truncated (max_tokens)" if response.stop_reason == :max_tokens

    text = response.content.select { _1.type == :text }.map(&:text).join
    JSON.parse(text)
  rescue JSON::ParserError => e
    raise Error, "unparseable response for topic #{@game.groupsio_topic_id}: #{e.message}"
  end

  def transcript(messages)
    lines = ["Thread subject: #{@game.subject}", ""]
    messages.each do |m|
      lines << "--- #{m.author_name}, sent #{m.sent_at.in_time_zone.strftime("%A %Y-%m-%d %-I:%M %p")} ---"
      lines << (m.body.presence || "(empty)")
      lines << ""
    end
    lines.join("\n")
  end

  def apply(data, through_msg_num:)
    Game.transaction do
      attrs = { ai_data: data, extracted_at: Time.current, extracted_through_msg_num: through_msg_num }

      unless @game.locked?(:starts_at)
        attrs[:starts_at] = parse_start(data["date"], data["start_time"])
        attrs[:time_tbd] = data["date"].present? && data["start_time"].blank?
      end
      attrs[:status] = data["status"] unless @game.locked?(:status)
      attrs[:location] = data["location"].presence || Game::DEFAULT_LOCATION unless @game.locked?(:location)
      attrs[:summary] = data["summary"] unless @game.locked?(:summary)
      @game.update!(attrs)

      unless @game.locked?(:attendances)
        @game.attendances.delete_all
        data["attendees"].uniq { _1["name"] }.each do |a|
          @game.attendances.create!(name: a["name"], status: a["status"], note: a["note"].presence)
        end
      end
    end
  end

  # Untimed games sort as noon on their day.
  def parse_start(date, time)
    return nil if date.blank?

    Time.zone.parse("#{date} #{time.presence || "12:00"}")
  rescue ArgumentError
    nil
  end
end
