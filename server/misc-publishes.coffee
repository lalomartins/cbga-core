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

Meteor.publish 'cbga-container-counts-for-game', (gameId) ->
  # This uses UI defs to find out what to publish
  game = CBGA.findGame gameId
  rules = CBGA.getGameRules game.rules
  handles = []
  containersPublished = {}

  containerDocFromContainer = (container) ->
    _id: [game._id, container[0], container[1], container[2]].join '/'
    game: game._id
    type: container[0]
    owner: container[1]
    name: container[2]
    private: container[3]
    count: 0

  containerDocFromController = (controller, owner) ->
    owner ?= game
    container = controller.getContainer owner
    containerDocFromContainer container._toDb()

  for panel in rules.uiDefs.panels
    controller = rules.getController 'panel', panel.id
    if panel.owner is 'player'
      handles.push CBGA.Players.find(_game: game._id).observeChanges
        added: (id, document) =>
          containerDoc = containerDocFromController controller, id
          @added 'cbga-container-counts', containerDoc._id, containerDoc
    else
      containerDoc = containerDocFromController controller
      @added 'cbga-container-counts', containerDoc._id, containerDoc

  updateCount = (document) =>
    containerDoc = containerDocFromContainer document._container
    if containerDoc._id of containersPublished
      containerDoc.count = CBGA.Components.find
        _game: game._id
        _container: document._container
      .count()
      @changed 'cbga-container-counts', containerDoc._id, containerDoc
  handles.push CBGA.Components.find(_game: game._id).observe
    added: updateCount
    changed: updateCount
    removed: updateCount

  @onStop =>
    for handle in handles
      handle.stop()

  @ready()
  undefined
