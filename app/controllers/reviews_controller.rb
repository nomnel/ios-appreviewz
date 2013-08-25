class ReviewsController < ApplicationController
  def index
    @reviews = Review.all.includes(:reviewer, apps: [:primary_category, :developer]).order('published_at DESC').page params[:page]
  end
end
