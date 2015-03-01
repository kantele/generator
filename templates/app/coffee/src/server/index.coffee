express = require 'express'
derby = require 'k-client'
derby.use(require('k-bundle'))
racer = require 'k-model'
#racerBrowserChannel = require 'racer-browserchannel'
racerhighway = require 'k-highway'
liveDbMongo = require 'livedb-mongo'
coffeeify = require 'coffeeify'
app = require '../app/index'
nconf = require("nconf")
#racerAccess = require('racer-access')
passport = require 'd-passport'
routes = require './routes'

Model = racer.Model

Model.INITS.push (model) ->
  model.root.on 'error', (err) ->
    console.log 'model error (1)', arguments
    console.log err.stack


httpauth = require("ilkkah-http-auth")
basic = httpauth.basic(
  realm: "bl"
  file: __dirname + "/../../data/htpasswd/users.htpasswd" # gevorg:gpass, Sarah:testpass ...
)

#morgan  = require('morgan')
errorMiddleware = require './error'
nconf.file __dirname + '/conf.json'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'
compression = require 'compression'
expressSession = require 'express-session'
RedisStore = require('connect-redis')(expressSession)
expressApp = module.exports = express()
multer = require 'multer'

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

redis1.select process.env.REDIS_DB || 0
redis2.select process.env.REDIS_DB || 0
# Get Mongo configuration 
mongoUrl = process.env.MONGO_URL || process.env.MONGOHQ_URL || 'mongodb://localhost:27017/blanket'
publicDir = __dirname + '/../../public'

# The store creates models and syncs data
liveDbMongo = liveDbMongo(mongoUrl + '?auto_reconnect', safe: true)
store = derby.createStore
  db: liveDbMongo
  redis1: redis1
  redis2: redis2

store.shareClient.backend.addProjection "posts_short", "posts", 'json0',
  {
    id: true,
    title: true,
    subtitle: true,
    author: true,
    tags: true,
    status: true,
    created_at: true,
    url: true,
    commentCount: true,
    likes: true
  }

store.shareClient.backend.addProjection "auths_public", "auths", 'json0',
  {
    id: true,
    timestamps: true,
    status: true,
    local: true
  }

session = expressSession
  secret: process.env.SESSION_SECRET || ';JEd#bi\'P:f)p~RsW2RrbOa|5x{A&Bqf'
  store: new RedisStore(host: process.env.REDIS_HOST || 'localhost', port: process.env.REDIS_PORT || 6379)
  resave: false
  saveUninitialized: false

racerhighwayHandlers = racerhighway store, session: session
module.exports.upgrade = racerhighwayHandlers.upgrade

store.on 'bundle', (browserify) ->
  # Add support for directly requiring coffeescript in browserify bundles
  browserify.transform coffeeify

strategies =
  facebook:
    strategy: require("passport-facebook").Strategy
    conf:
      clientID: nconf.get('strategies:facebook:appId')
      clientSecret: nconf.get('strategies:facebook:appSecret')
  twitter:
    strategy: require("passport-twitter").Strategy
    conf:
      consumerKey: nconf.get('strategies:twitter:consumerKey')
      consumerSecret: nconf.get('strategies:twitter:consumerSecret')

passport.configure nconf.get('d-passport')

setSessionData = (req, res, next) ->
  model = req.getModel()
  userId = req.session.userId
  q = model.at "auths.#{req.session.userId}"
  model.fetch q, (err) ->
    user = q.get()
    #console.log 'user', user, model.root.get("_session.loggedIn")
    if user
      req.session.admin = !!user.admin
      req.session.loggedIn = model.root.get("_session.loggedIn")
    next()

wwwRedirect = (req, res, next) ->
  if req.headers.host.slice(0, 4) is "www."
    newHost = req.headers.host.slice(4)
    return res.redirect(301, req.protocol + "://" + newHost + req.originalUrl)
  next()

expressApp
  #.use(morgan('combined', {
  #  skip: (req, res) -> req.url.indexOf('/channel') is 0
  #  }))
  .use(httpauth.connect(basic))
  #.use(express.logger())
  .use(wwwRedirect)
  #.use(express.favicon())
  # Gzip dynamically
  .use(compression({ threshold: 512 }))
  # Respond to requests for application script bundles
  #.use(app.scripts store, {extensions: ['.coffee']})
  # Serve static files from the public directory
  .use(express.static publicDir)
  #.use(express.static __dirname + '/../../components')

  # Session middleware
  .use(cookieParser())
  .use(session)

  # Add browserchannel client-side scripts to model bundles created by store,
  # and return middleware for responding to remote client messages
  # .use(racerBrowserChannel store)
  .use(racerhighwayHandlers.middleware)
  # Add req.getModel() method
  .use(store.modelMiddleware())

  # Parse form data
  .use(bodyParser.urlencoded( extended: true ))
  #.use(express.methodOverride())

  # derbyAuth.middleware is inserted after modelMiddleware and before the app router to pass server accessible data to a model
  # Pass in {store} (sets up accessControl & queries), {strategies} (see above), and options
  .use(passport.middleware(expressApp, strategies))
  .use(setSessionData)

  # Create an express middleware from the app's routes
  .use(app.router())
  .use(errorMiddleware)
  # file uploads
  .use(multer({ inMemory: true }))

require('./access')(store.shareClient)
require("./hooks")(store, passport)

# SERVER-SIDE ROUTES #
routes expressApp


app.writeScripts store, publicDir, 
  extensions: [".coffee"]
  disableScriptMap: false
, (err) ->
  console.log err
  return
