require 'spec_helper'

describe AppsController do
  fixtures :apps

  describe "GET index" do
    it "assigns all reviews as @reviews" do
      get :index
      assigns(:apps).should eq(App.includes(:reviews).order('reviews.published_at DESC').page(1).to_a)
    end
  end

  describe "GET show" do
    it 'assigns the requested app as @app' do
      get :show, id: 1
      assigns(:app).should eq(apps :one)
    end
  end
end