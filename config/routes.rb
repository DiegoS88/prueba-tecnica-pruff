Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  resources :invoices, only: %i[index show]
  resources :movements, only: %i[index show]
  resources :imports, only: %i[new create index]
  resources :reconciliation, only: %i[index]

  post "reconciliation/:id/approve", to: "reconciliation#approve", as: :approve_application
  post "reconciliation/:id/reject", to: "reconciliation#reject", as: :reject_application
end
