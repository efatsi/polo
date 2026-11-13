module GamesHelper
  LIKELY_THRESHOLD = 4

  # Public headline: "GAME ON" / "Likely" (4+ in) / "Pending" / "No Game".
  def public_status(game)
    return "No Game" if game.nil?
    return "GAME ON" if game.status == "confirmed"

    game.playing.size >= LIKELY_THRESHOLD ? "Likely" : "Pending"
  end

  STATUS_BADGES = {
    "confirmed" => ["Game on", "bg-emerald-900 text-emerald-200 ring-emerald-700"],
    "proposed" => ["Pending", "bg-amber-900 text-amber-200 ring-amber-700"],
    "cancelled" => ["Cancelled", "bg-rose-900 text-rose-200 ring-rose-700"],
    "not_a_game" => ["Not a game", "bg-gray-700 text-gray-300 ring-gray-600"]
  }.freeze

  # Admin-only badge for a thread's extracted status.
  def status_badge(game)
    label, classes = STATUS_BADGES.fetch(game.status)
    tag.span(label, class: "inline-flex items-center justify-center text-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ring-inset #{classes}")
  end

  def game_day(game)
    return "Day TBD" unless game.starts_at

    game.starts_at.strftime("%A, %B %-d")
  end

  def game_time(game)
    return "Time TBD" if game.starts_at.nil? || game.time_tbd

    game.starts_at.strftime("%-l:%M %p").sub(":00", "")
  end

  def location_link(location)
    return "Location TBD" if location.blank?

    link_to location, "https://www.google.com/maps/search/?api=1&query=#{CGI.escape("#{location}, Crozet, VA")}",
            class: "underline decoration-gray-500 underline-offset-4 hover:decoration-gray-200", target: "_blank", rel: "noopener"
  end
end
