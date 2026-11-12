# The public site: is there a game, and if so where and when. No names or messages.
class GamesController < ApplicationController
  def current
    @game = Game.next_up
    @game = nil if @game&.status == "cancelled"
  end
end
