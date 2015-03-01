app = require './index'

app.get '/', (page, model, params, next) ->
	page.render 'home'

app.get '/about', (page, model, params, next) ->
	page.render 'about'

