class ExtractGameJob < ApplicationJob
  queue_as :default

  def perform(game)
    GameExtractor.call(game)
  end
end
