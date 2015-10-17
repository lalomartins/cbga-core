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
    unless Meteor.userId()
      throw new Metor.Error 'Not allowed', 'must be logged in'
    rules = CBGA.getGameRules options.rules
    sourceContainer = rules.findComponent options.source
    targetContainer = rules.findComponent options.target
    unless sourceContainer._game is targetContainer._game
      throw new Metor.Error 'Not allowed', 'must move to the same game'
    player = CBGA.Players.findOne _user: Meteor.userId(), _game: sourceContainer._game
    unless player?
      throw new Metor.Error 'Not allowed', 'must be in the game'
    selector = type: options.type
    if options.stack?
      type = rules.getComponentType options.type
      selector[type.stackProperty] = options.stack
    sourceContainer.find selector, limit: options.count, sort: position: 1
    .forEach (eachComponent) =>
      eachComponent.moveTo targetContainer
