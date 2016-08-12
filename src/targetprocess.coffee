# Description:
#   Connectivity library for hubot and targetprocess. 
#   See targetprocess-web-hooks.coffee or targetprocess-robot.coffee for usage.
# 
# Dependencies:
#   Nope
#
# Configuration:
#   TARGETPROCESS_TOKEN - Targetprocess API Token
#   TARGETPROCESS_HOST - Targetprocess ondemand url: https://example.tpondemand.com
#
#Commands:
#   None
#
# Author: 
#   @shadowfiend
#   @riveramj

Util = require 'util'
_ = require 'underscore'

class TargetProcess
  constructor: (@robot) ->
    @defaultToken = process.env['TARGETPROCESS_TOKEN']
    @baseUrl = process.env['TARGETPROCESS_HOST']
    
  userInfoForMsg: (msg, config) ->
    info = @robot.brain.get('target-process')?.userInfoByUserId?[msg.message.user.id] || {}

    unless info.userId?
      unless config?.noErrors? == true
        msg.send """
          Incomplete docking procedure. Try sending me a 'I am <login> in Target Process'
          so I know who to look for in Target Process!
          """

      null
    else
      info

  updateUserInfoForMsg: (msg, updatedFields) ->
    targetProcess = @robot.brain.get('target-process') || {}
    targetProcess.userInfoByUserId ||= {}
    info = (targetProcess.userInfoByUserId[msg.message.user.id] ||= {})

    info[field] = value for field, value of updatedFields

    @robot.brain.set 'target-process', targetProcess

  buildRequest: (resource, headers, query, token, version) ->
    query ||= {}

    if token?
      query.token = token

    headers ||= {}
    headers['Accept'] ||= 'application/json'

    version ||= "v1"

    base =
      _.reduce(
        Object.keys(headers),
        (base, header) -> base.header(header, headers[header]),
        @robot.http("#{@baseUrl}/api/#{version}/#{resource}")
      )

    base
      .query(query)

  post: (resource, body, config, callback) ->
    unless callback?
      callback = config

    {query, headers} = config || {}
    headers ||= {}
    headers['Content-Type'] = 'application/json; charset=utf-8'

    bodyString = JSON.stringify(body)
    @buildRequest(resource, headers, query, @defaultToken)
      .post(bodyString) (err, res, body) ->
        callback?(err, res, body)

  get: (msg, resource, config, callback) ->
    unless callback?
      callback = config

    {query, headers, version} = config || {}

    token =
      unless config.noToken
        @defaultToken

    @buildRequest(resource, headers, query, token, version)
      .get() (err, res, body) ->
        if err?
          msg.send "It's all gone wrong, aborting mission! Got error: #{err}."
        else if res.statusCode isnt 200
          msg.send "It's all gone wrong, aborting mission! Got #{res.statusCode} response:\n  #{body}"
        else
          try
            result = JSON.parse(body)
            callback?(result)
          catch error
            msg.send """
              It's all gone wrong, aborting mission! That JSON parsing thing didn't work so
              well with:
                #{body}
              got:
                #{Util.inspect(error)}
            """

module.exports = TargetProcess

