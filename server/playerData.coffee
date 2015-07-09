Avatar.options =
    gravatarDefault: 'mm'
    customImageProperty: 'profile.avatarUrl'

Meteor.publish 'player-avatars', ->
    # This is publishing all users, which is silly, especially since
    # the client has no other data on them. It's good enough for the
    # alpha though, at least until we have friends and games.
    handle = Meteor.users.find
        'profile.avatarUrl': $exists: false
    .observe
        added: (userDoc) =>
            @added 'users', userDoc._id,
                defaultAvatar: Avatar.getUrl userDoc
    @onStop -> handle.stop()
    @ready()

Meteor.users.allow
    update: (userId, doc, fieldNames, modifier) ->
        return false unless doc._id is userId
        hasUsername = false
        for field in fieldNames
            switch
                when field is 'username'
                    hasUsername = true
                when field is 'profile'
                    #
                else
                    return false
        if hasUsername
            for op, fields of modifier
                if op is '$set'
                    newUsername = fields.username
                    return false unless newUsername?
                    newUsername = fields.username = newUsername.toLowerCase()
                    return false if Meteor.users.find(username: newUsername).count() isnt 0
                else
                    return false if op.username?
        return true

    fetch: ['username', 'profile']

# XXX publish only what we want (friends, players, one user)
Meteor.publish 'all-users', ->
    Meteor.users.find {},
        fields:
            username: 1
            profile: 1
