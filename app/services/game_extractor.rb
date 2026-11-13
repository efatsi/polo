# Reads a game's email thread with Claude and fills in when/where the game is,
# whether it's on, and who's coming. Fields an admin has locked are left alone.
class GameExtractor
  class Error < StandardError; end

  # Haiku matched Opus on status/date/location across 20 real threads at ~4% of the cost.
  MODEL = "claude-haiku-5-5".freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You read email threads from the Crozet, Virginia bike polo group's mailing list and
    extract the details of the pickup game being organized, for display on the group's website.

    How the group works:
    - Someone starts a thread a few days ahead proposing a day and time ("Sunday polo?").
      Others reply with whether they're in, out, or what times work for them.
    - The default location is #{Game::DEFAULT_LOCATION}. "Festival Field" is the field at
      #{Game::DEFAULT_LOCATION} and means the same place. The backup is #{Game::BACKUP_LOCATION}
      (sometimes "BCR" or "the reservoir"), used when the park is unavailable — wet or
      closed fields, an event at the park, or someone proposes moving there.
    - location: exactly "#{Game::DEFAULT_LOCATION}" or "#{Game::BACKUP_LOCATION}", with nothing
      added. Use #{Game::DEFAULT_LOCATION} unless the thread points to the reservoir. Only if
      the thread clearly moves the game somewhere else entirely, give that place's name.
    - All times are US Eastern (America/New_York).

    Rules:
    - Resolve relative days ("Sunday", "tomorrow", "this weekend") against the date of the
      message that says them. Each message is labeled with its sent date and weekday.
    - weekday / date / start_time: the game being organized. weekday is the day name
      ("Sunday"), or "unknown" if no day can be worked out; date must fall on that weekday. If the thread settled on a time, use it.
      If not settled, use the time with the most support so far, or the time proposed by
      the thread starter. Use null for start_time if no time has been mentioned, and null for
      date if no day can be worked out.
    - status: "confirmed" if the thread agrees the game is on: an explicit "see you at noon" or
      "it's on", or four or more people "in" for the same day and time with nobody calling it off
      (people sorting out who brings what counts as on). "cancelled" if it was called off;
      "proposed" otherwise. Use "not_a_game" for threads that aren't organizing a specific
      game (announcements, gear, general discussion).
    - attendees: one entry per person, using the name shown on their messages (or as
      mentioned, for people named by others). Include people someone else says are coming
      ("Hazel and I will be there" makes Hazel "in" too). "in" = plans to play, including
      hedged yeses like "I think I can make it" or "might be a bit late"; "maybe" = genuinely
      undecided or conditional ("depends on the weather", "50/50"); "out" = not playing.
      Someone who offered several days counts as "in" once the game lands on one of them.
      The person proposing a game counts as "in" unless they say otherwise. note: a short constraint or detail in their words, like "hard stop at 2"
      or "can bring extra mallets"; empty string if none. Later messages override earlier ones.
    - summary: one or two plain sentences for the website, e.g. "Noon at Crozet Park; Bruno
      and Tyler have a hard stop at 2."
  PROMPT

  SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[status weekday date start_time location summary attendees],
    properties: {
      status: { type: "string", enum: %w[proposed confirmed cancelled not_a_game] },
      weekday: { type: "string", enum: [*Date::DAYNAMES, "unknown"], description: "Day of the week the game is on" },
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
    # Haiku has no server-side refusal fallback; a refusal raises below and the
    # thread is retried on the next sync.
    response = @client.messages.create(
      model: MODEL,
      max_tokens: 16_000,
      system_: SYSTEM_PROMPT,
      messages: [{ role: "user", content: transcript(messages) }],
      output_config: { effort: :medium, format_: { type: :json_schema, schema: SCHEMA } }
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
        attrs[:starts_at] = parse_start(self.class.resolve_date(data["date"], data["weekday"]), data["start_time"])
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

  # Models occasionally get the date off by a day or two while naming the weekday
  # correctly ("Sunday" -> a Saturday's date). Snap the date to the nearest day
  # (within 3) that falls on the stated weekday.
  def self.resolve_date(date, weekday)
    return date if date.blank? || !Date::DAYNAMES.include?(weekday)

    d = Date.iso8601(date)
    return date if d.strftime("%A") == weekday

    (-3..3).map { d + _1 }.find { _1.strftime("%A") == weekday }&.iso8601 || date
  rescue Date::Error
    date
  end

  # Untimed games sort as noon on their day.
  def parse_start(date, time)
    return nil if date.blank?

    Time.zone.parse("#{date} #{time.presence || "12:00"}")
  rescue ArgumentError
    nil
  end
end
