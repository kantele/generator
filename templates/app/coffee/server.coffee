conf = require "nconf"
derby = require "k-client"
fs = require 'fs'
conf.argv().file(file: __dirname + "/src/server/conf.json").env()

run = (app) ->
  app = require(app) if typeof app is "string"

  listenCallback = (err) ->
    console.log "%d listening.", process.pid
    return

  redirectApp = (req, res) ->
    host = req.headers.host.replace /:\d+$/, ''
    res.writeHead 301, Location: "https://#{host}#{req.url}"
    res.end()

  createServer = ->
    #options =
    #  key: fs.readFileSync('data/keys/ssl.key')
    #  cert: fs.readFileSync('data/keys/bundle.crt')
    #require("http").createServer(redirectApp).listen(80);
    #require("https").createServer(options, app).listen(443, listenCallback).on('upgrade', app.upgrade)
    require("http").createServer(app).listen(3000, listenCallback).on('upgrade', app.upgrade)

  derby.run createServer
  return

run __dirname + "/src/server"
