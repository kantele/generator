app = require './index'

app.get '/', (page, model, params, next) ->
	items = model.query 'items', {}
	items.subscribe (err) ->
		model.ref '_page.items', items
		page.render 'home'

