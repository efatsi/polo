module Admin
  class GamesController < BaseController
    before_action :set_game, only: [:edit, :update, :extract]

    def index
      @games = Game.order(last_post_at: :desc).limit(50)
    end

    def edit; end

    # Any field the admin changes becomes locked so Claude won't overwrite it.
    # Unlocking a field hands it back to Claude and re-reads the thread.
    def update
      form = params.require(:game)
      changed = []

      starts_at = form[:starts_at].present? ? Time.zone.parse(form[:starts_at]) : nil
      time_tbd = form[:time_tbd] == "1"
      if starts_at != @game.starts_at || time_tbd != @game.time_tbd
        @game.assign_attributes(starts_at:, time_tbd:)
        changed << "starts_at"
      end

      %w[location status summary].each do |field|
        value = form[field].to_s.strip.presence
        next if value == @game[field].presence

        @game[field] = value
        changed << field
      end

      attendances = parse_attendances(form[:attendances_text].to_s)
      changed << "attendances" if attendances != current_attendances

      unlock = Array(params[:unlock]) & Game::LOCKABLE_FIELDS
      @game.locked_fields = ((@game.locked_fields | changed) - unlock).sort

      Game.transaction do
        @game.save!
        if changed.include?("attendances")
          @game.attendances.delete_all
          attendances.each { @game.attendances.create!(_1) }
        end
      end

      ExtractGameJob.perform_later(@game) if unlock.any?
      redirect_to edit_admin_game_path(@game), notice: update_notice(changed, unlock)
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end

    def extract
      ExtractGameJob.perform_later(@game)
      redirect_to edit_admin_game_path(@game), notice: "Claude is re-reading the thread. Refresh in a minute."
    end

    def sync
      SyncGroupsioJob.perform_later
      redirect_to admin_games_path, notice: "Sync started. Refresh in a minute."
    end

    private

    def set_game
      @game = Game.find(params[:id])
    end

    def current_attendances
      @game.attendances.map { { name: _1.name, status: _1.status, note: _1.note } }
    end

    # One person per line: "Name | in/maybe/out | optional note"
    def parse_attendances(text)
      text.lines.filter_map do |line|
        name, status, note = line.split("|", 3).map(&:strip)
        next if name.blank?

        status = Attendance::STATUSES.include?(status&.downcase) ? status.downcase : "in"
        { name:, status:, note: note.presence }
      end.sort_by { _1[:name] }
    end

    def update_notice(changed, unlock)
      parts = []
      parts << "Locked #{changed.to_sentence}" if changed.any?
      parts << "unlocked #{unlock.to_sentence} (Claude is re-reading the thread)" if unlock.any?
      parts.any? ? "#{parts.join("; ")}." : "No changes."
    end
  end
end
