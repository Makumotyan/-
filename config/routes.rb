Rails.application.routes.draw do
  match ':controller(/:action(/:id))', via: [ :get, :post, :patch ]

  get 'asset/send_form' => 'asset#send_form', as: 'send_form'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
