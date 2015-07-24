# this doesn't really belong here, but I don't know where else yet :-)
CBGA.setupCollections()

# temporary publishes for development
Meteor.publish 'cbga-dev-all', -> [
  CBGA.Games.find()
  CBGA.Players.find()
]

Meteor.publish 'cbga-components-for-game', (gameId) ->
  # XXX: Player assignment isn't reactive. Should be fine, since it's never
  # supposed to change anyway.
  player = CBGA.Players.findOne _game: gameId, _user: @userId
  CBGA.Components.find
    _game: gameId
    $or: [
      '_container.1': player._id
    ,
      '_container.3': false
    ]
