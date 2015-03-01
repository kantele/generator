app = module.exports = require('k-client').createApp '{kantele-app}', __filename
app.serverUse(module, 'k-stylus');
app.loadViews __dirname + '/../../views/app'
app.loadStyles __dirname + '/../../styles/app'

app.component require 'k-connection-alert'
app.component require 'k-before-unload'

# error catching, otherwise the app may crash if an uncaught error is thrown
app.on 'model', (model) ->
	model.on 'error', (err) -> console.log err

require './home'
