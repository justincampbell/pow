http = require 'http'
sys  = require 'sys'

{createPool}         = require 'nack/pool'
{BufferedReadStream} = require 'nack/buffered'

idle = 1000 * 60 * 15

exports.Server = class Server
  constructor: (@configuration) ->
    @applications = {}
    @server = http.createServer (req, res) =>
      @onRequest req, res

  listen: (port) ->
    @server.listen port

  close: ->
    for config, app of @applications
      app.quit()

    @server.close()

  createApplicationPool: (config) ->
    pool = createPool config, size: 3, idle: idle

    # TODO: Pump this to a file
    sys.pump pool.stdout, process.stdout
    sys.pump pool.stderr, process.stdout

    pool

  applicationForConfig: (config) ->
    if config
      @applications[config] ?= @createApplicationPool config

  onRequest: (req, res) ->
    reqBuf = new BufferedReadStream req
    host = req.headers.host.replace /:.*/, ""
    @configuration.findPathForHost host, (path) =>
      if app = @applicationForConfig path
        app.proxyRequest reqBuf, res
      else
        @respondWithError res, "unknown host #{req.headers.host}"
      reqBuf.flush()

  respondWithError: (res, err) ->
    res.writeHead 500, "Content-Type": "text/html"
    res.write "<h1>500 Internal Server Error</h1><p>#{err}</p>"
    res.end()
