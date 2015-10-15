express = require 'express'
kclient = require 'k-client'
kclient.use(require('k-bundle'))
kmodel = require 'k-model'
racerhighway = require 'k-highway'
liveDbMongo = require 'k-livedb-mongo'
coffeeify = require 'coffeeify'
app = require '../app/index'
routes = require './routes'
errorMiddleware = require './error'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'
compression = require 'compression'
expressSession = require 'express-session'
RedisStore = require('connect-redis')(expressSession)
expressApp = module.exports = express()
#multer = require 'multer'

# error catching, otherwise the app may crash if an uncaught error is thrown
kmodel.Model.INITS.push (model) ->
  model.root.on 'error', (err) -> console.log err

# Get Redis configuration
if process.env.REDIS_HOST
  redis1 = require('redis').createClient process.env.REDIS_PORT, process.env.REDIS_HOST
  redis1.auth process.env.REDIS_PASSWORD
  redis2 = require('redis').createClient process.env.REDIS_PORT, process.env.REDIS_HOST
  redis2.auth process.env.REDIS_PASSWORD
else if process.env.REDISCLOUD_URL
  redisUrl = require('url').parse process.env.REDISCLOUD_URL
  redis1 = require('redis').createClient redisUrl.port, redisUrl.hostname
  redis1.auth redisUrl.auth.split(":")[1]
  redis2 = require('redis').createClient redisUrl.port, redisUrl.hostname
  redis2.auth redisUrl.auth.split(":")[1]
else
  redis1 = require('redis').createClient()
  redis2 = require('redis').createClient()

# only 0 works
redis1.select 0
redis2.select 0

# Get Mongo configuration 
mongoUrl = process.env.MONGO_URL || process.env.MONGOHQ_URL || 'mongodb://localhost:27017/k-ads-admin'
publicDir = __dirname + '/../../public'

# The store creates models and syncs data
liveDbMongo = liveDbMongo(mongoUrl + '?auto_reconnect', safe: true)
store = kclient.createStore
  db: liveDbMongo
  redis1: redis1
  redis2: redis2

# enable if needed

###
store.shareClient.backend.addProjection "auths_public", "auths", 'json0',
  {
    id: true,
    timestamps: true,
    status: true,
    local: true
  }
###

session = expressSession
  secret: process.env.SESSION_SECRET || 'no-one-is-going-to-crack-this-except-nsa'
  store: new RedisStore(host: process.env.REDIS_HOST || 'localhost', port: process.env.REDIS_PORT || 6379)
  resave: false
  saveUninitialized: false

racerhighwayHandlers = racerhighway store, session: session
module.exports.upgrade = racerhighwayHandlers.upgrade

store.on 'bundle', (browserify) ->
  # Add support for directly requiring coffeescript in browserify bundles
  browserify.transform coffeeify

expressApp
  # Gzip dynamically
  .use(compression({ threshold: 512 }))

  # Serve static files from the public directory
  .use(express.static publicDir)

  # Session middleware
  .use(cookieParser())
  .use(session)

  # websockets etc.
  .use(racerhighwayHandlers.middleware)

  # Add req.getModel() method
  .use(store.modelMiddleware())

  # Parse form data
  .use(bodyParser.urlencoded( extended: true ))

  # file uploads, enable if needed
  # .use(multer({ inMemory: true }))

  # Create an express middleware from the app's routes
  .use(app.router())

# access control
# enable when needed
# require('./access')(store.shareClient)

# server-side routes
routes expressApp

# finally, set the http error handler (404 etc)
expressApp.use(errorMiddleware)

app.writeScripts store, publicDir, 
  extensions: [".coffee"]
  disableScriptMap: false
, (err) ->
  console.log err
  return
