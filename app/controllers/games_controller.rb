class GamesController < ApplicationController
  PER_PAGE = 25

  def current
    @game = Game.next_up
    @later = Game.upcoming.where.not(id: @game&.id).limit(3)
  end

  def index
    @page = [params[:page].to_i, 1].max
    games = Game.past.includes(:attendances).offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
    @more = games.size > PER_PAGE
    @games = games.first(PER_PAGE)
  end

  def show
    @game = Game.listed.find(params[:id])
  end
end
