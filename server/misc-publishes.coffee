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
      '_container.3': true
    ,
      '_container.3': false
    ]

Meteor.publish 'cbga-container-counts-for-game', (gameId) ->
  # This uses UI defs to find out what to publish
  # XXX missing stackProperty
  game = CBGA.findGame gameId
  rules = CBGA.getGameRules game.rules
  handles = []
  containersPublished = {}

  containerDocFromContainer = (container, type) ->
    _id: [game._id, container[0], container[1], container[2], type].join '/'
    game: game._id
    ownerType: container[0]
    owner: container[1]
    name: container[2]
    private: container[3]
    type: type
    count: 0

  containerDocFromController = (controller, type, owner) ->
    owner ?= game
    container = controller.getContainer owner
    containerDocFromContainer container._toDb(), type

  for panel in rules.uiDefs.panels
    controller = rules.getController 'panel', panel.id
    if panel.owner is 'player'
      handles.push CBGA.Players.find(_game: game._id).observeChanges
        added: (id, document) =>
          for type in panel.contains
            containerDoc = containerDocFromController controller, type, id
            containersPublished[containerDoc._id] = true
            @added 'cbga-container-counts', containerDoc._id, containerDoc
    else
      for type in panel.contains
        containerDoc = containerDocFromController controller, type
        containersPublished[containerDoc._id] = true
        @added 'cbga-container-counts', containerDoc._id, containerDoc

  updateCount = (document, oldDocument) =>
    containerDoc = containerDocFromContainer document._container, document.type
    if containerDoc._id of containersPublished
      containerDoc.count = CBGA.Components.find
        _game: game._id
        _container: document._container
      .count()
      @changed 'cbga-container-counts', containerDoc._id, containerDoc
      if oldDocument?
        updateCount oldDocument
  handles.push CBGA.Components.find(_game: game._id,
    fields: _container: 1, position: 1, type: 1
  ).observe
    added: updateCount
    changed: updateCount
    removed: updateCount

  @onStop =>
    for handle in handles
      handle.stop()

  @ready()
  undefined
