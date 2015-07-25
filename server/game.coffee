Meteor.methods
  'game.removePlayer': (playerId) ->
    player = CBGA.Players.findOne playerId
    throw new Meteor.Error('Not Found', 'no such player') unless player?
    game = CBGA.Games.findOne player._game
    throw new Meteor.Error('Not Found', 'no such game') unless game?
    if game._owner isnt Meteor.userId()
      throw new Meteor.Error 'Not allowed',
        'only the game owner can remove players'
    if game.started?
      throw new Meteor.Error 'Not implemented',
        'removing players from running game is not yet implemented'
    CBGA.Players.remove playerId

  'game.start': (gameId) ->
    game = CBGA.Games.findOne gameId
    throw new Meteor.Error('Not Found', 'no such game') unless game?
    if game._owner isnt Meteor.userId()
      throw new Meteor.Error 'Not allowed',
        'only the game owner can start it'
    if game.started?
      throw new Meteor.Error 'Invalid input',
        'game is already running'
    game = CBGA.Game._wrap game
    game.start()

  'component.draw': (options) ->
    # XXX should probably check that the current user is in the game
    unless Meteor.userId()
      throw new Metor.Error 'Not allowed', 'must be logged in'
    rules = CBGA.getGameRules options.rules
    selector = type: options.type
    if options.stack?
      type = rules.getComponentType options.type
      selector[type.stackProperty] = options.stack
    # XXX would be nice to pass the container class from the panel
    sourceContainer = new CBGA.Container [options.source.type,
      options.source.owner, options.source.name, options.source.private]
    targetContainer = new CBGA.Container [options.target.type,
      options.target.owner, options.target.name, options.target.private]
    removed = []
    sourceContainer.find selector, limit: options.count, sort: position: 1
    .forEach (eachComponent) =>
      eachComponent.moveTo targetContainer
      removed.push eachComponent
    sourceContainer.componentsRemoved?(removed)
