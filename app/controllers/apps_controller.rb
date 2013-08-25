class AppsController < ApplicationController
  def index
    @apps = App.all.includes(:primary_category, :developer, reviews: [:reviewer]).order('reviews.published_at DESC').page params[:page]
  end

  def show
    @app = App.find(params[:id])
    @reviews = @app.reviews.order('published_at DESC').includes(:reviewer).page params[:page]
  end
end
