IosAppReviews::Application.routes.draw do
  root 'reviews#index'
  resources :reviews, only: :index do
    get 'page/:page', action: :index, on: :collection
  end
  resources :apps, only: [:index, :show] do
    get 'page/:page', action: :show, on: :member
    get 'page/:page', action: :index, on: :collection
  end
end
