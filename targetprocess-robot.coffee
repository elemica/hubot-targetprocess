Util = require 'util'
_ = require 'underscore'

TargetProcess = require 'lib/targetprocess'

closedStateByType =
  UserStories:
    Id: 2
    Name: 'Done'
  Tasks:
    Id: 4
    Name: 'Done'
  Bugs:
    Id: 8
    Name: 'Closed'

module.exports = (robot) ->
  targetProcess = new TargetProcess(robot)

  lookupUserInfoByFields = (msg, fields, value, callback) ->
    if fields.length
      targetProcess.get msg, "Users", query: { where: "#{fields.pop()} eq \"#{value}\"" }, (result) ->
        if result.Items?.length
          console.log 'Doin it for', msg.message.user.id, result.Items[0].Id
          targetProcess.updateUserInfoForMsg msg, userId: result.Items[0].Id

          callback? true
        else
          lookupUserInfoByFields msg, fields, value, callback
    else
      callback? false

  lookupEntitiesByAssignedUserId = (msg, userId, entityTypes, callback, stories) ->
    stories ||= []

    if entityTypes.length
      entityType = entityTypes.shift()
      closedStateId = closedStateByType[entityType].Id

      conditions = "(AssignedUser.Id eq #{userId}) and (EntityState.Id ne #{closedStateId})"
      console.log("Running with #{conditions}")

      targetProcess.get msg, entityType, query: { where: conditions, include: "[Name]" }, (result) ->
        matchingStories = result.Items

        lookupEntitiesByAssignedUserId msg, userId, entityTypes, callback, stories.concat(matchingStories || [])
    else
      callback? stories

  robot.respond /I am ([^ ]+) in Target Process\.?$/i, (msg) ->
    loginOrEmail = msg.match[1]

    lookupUserInfoByFields msg, ['Login', 'Email'], loginOrEmail, (succeeded) ->
      if succeeded
        msg.send "Great, I have you as #{loginOrEmail}!"
      else
        msg.send "I couldn't find #{loginOrEmail} in Target Process :( Make sure this is your login or email!"

  entities =
    'stories': 'UserStories'
    'bugs': 'Bugs'
    'tasks': 'Tasks'

  entityNames = Object.keys(entities)
  entityRegex = "(#{entityNames.join('|')})"
  entityTypes = (entity for _, entity of entities)

  robot.respond ///show\s+(?:me\s+)?#{entityRegex}$///, (msg) ->
    console.log "Mission parameters established for #{entityRegex} lookup, launching..."

    userInfo = targetProcess.userInfoForMsg msg
    if userInfo?
      entitySelector = msg.match[1]
      entity = entities[entitySelector]

      lookupEntitiesByAssignedUserId msg, userInfo.userId, [entity], (stories) ->
        storyString = stories.map((_) -> " - #{_.Name} (id:#{_.Id}, https://elemica.tpondemand.com/entity/#{_.Id})").join("\n")

        if stories.length
          msg.send """
            Here are your #{entitySelector}:
            #{storyString}
          """
        else
          msg.send "You have no #{entitySelector}; aborting launch."

  robot.respond /show (?:me )?(?:stuff|everything)\.?$/, (msg) ->
    console.log "Mission parameters established for everything lookup, launching..."

    userInfo = targetProcess.userInfoForMsg msg
    if userInfo?
      entityTypes = (entity for _, entity of entities)

      lookupEntitiesByAssignedUserId msg, userInfo.userId, entityTypes, (stories) ->
        storyString = stories.map((_) -> " - #{_.Name} (id:#{_.Id}, https://elemica.tpondemand.com/entity/#{_.Id})").join("\n")

        entityLabel = entityNames.join(", ").replace(/, ([^,]+)$/, ', and $1')
        if stories.length
          msg.send """
            Here are your #{entityLabel}:
            #{storyString}
          """
        else
          msg.send "You have no #{entityLabel}; aborting launch."

  robot.respond /show (me )?backlog$/, (msg) ->
    console.log "Mission parameters established for backlog lookup, launching..."

    userInfo = targetProcess.userInfoForMsg msg
    msg.send "Mock mission completed. Real mission still pending investigation of fuel flow control mechanism."

