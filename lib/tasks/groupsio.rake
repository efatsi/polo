namespace :groupsio do
  desc "Sync recent groups.io topics now (TOPICS=20, EXTRACT=false to skip Claude)"
  task sync: :environment do
    stats = Groupsio::Sync.call(
      max_topics: ENV.fetch("TOPICS", 20).to_i,
      extract: ENV["EXTRACT"] != "false"
    )
    puts stats.inspect
  end

  desc "Re-run Claude on every game thread that isn't admin-locked (or GAME_ID=n for one)"
  task reextract: :environment do
    scope = ENV["GAME_ID"] ? Game.where(id: ENV["GAME_ID"]) : Game.all
    scope.find_each do |game|
      next if game.messages.none?

      GameExtractor.call(game)
      puts "#{game.id} #{game.subject}: #{game.reload.status} #{game.starts_at}"
    end
  end
end
