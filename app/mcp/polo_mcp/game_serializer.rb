module PoloMcp
  # Plain-hash view of a Game for tool responses.
  module GameSerializer
    module_function

    def call(game, messages: false)
      data = {
        game_id: game.id,
        subject: game.subject,
        status: game.status,
        starts_at: PoloMcp.time(game.starts_at),
        date: game.starts_at&.to_date&.iso8601,
        time_tbd: game.time_tbd,
        location: game.location,
        summary: game.summary,
        playing: names(game.playing),
        maybe: names(game.maybe),
        out: names(game.out),
        overridden_by_admin: game.locked_fields,
        thread: {
          started_by: game.started_by,
          started_at: PoloMcp.time(game.thread_started_at),
          last_post_at: PoloMcp.time(game.last_post_at),
          url: game.groupsio_url,
        },
      }
      if messages
        data[:messages] = game.messages.map do |m|
          { msg_num: m.msg_num, from: m.author_name, sent_at: PoloMcp.time(m.sent_at), text: m.body }
        end
      end
      data
    end

    # "Bruno (hard stop at 2)" style, so notes travel with the name.
    def names(attendances)
      attendances.map { |a| a.note.present? ? "#{a.name} (#{a.note})" : a.name }
    end
  end
end
