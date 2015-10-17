class CBGA.Component extends CBGA._DbModelBase
  # A Component is defined as something that can be moved in the game, *or*
  # something that can contain other Components.
  # In most games, that means cards, tokens, player markers, meeples,
  # and so on; but they can also be something more abstract, such as a
  # player's hand or tableau.
  # Boards, character sheets *don't* need to be Components (unless
  # you put components on them).
  constructor: (game, player, container) ->
    check game, CBGA.Game
    check player, Match.Optional Match.OneOf CBGA.Player, String
    check container, Match.Optional Match.OneOf CBGA.Component, String
    if typeof container is 'string'
      container = (CBGA.getGameRules game.rules).findComponent container
    super
    @_game = game._id ? game
    @_player = player?._id ? player
    if container?
      @_container = container._id
      @_private = container._private

  @_wrap: (doc) ->
    (CBGA.getGameRules doc).wrapComponent doc

  game: -> CBGA.findGame @_game
  player: -> (CBGA.getGameRules @game().rules).findPlayer @_player
  container: -> (CBGA.getGameRules @game().rules).findComponent @_container

  moveTo: (container, properties) ->
    properties ?= {}
    unless container._id?
      container_ = (CBGA.getGameRules @).findComponent container
      if container_?
        container = container_
      else
        throw new Error "invalid container #{container}"
    oldContainer = @container()
    properties._container = container._id
    properties._private ?= container._private
    container.acceptNewComponent?(@, properties)
    for name, value of properties
      @[name] = value
    if container._player?
      properties._player ?= container._player
      @_player = properties._player
      @emit 'changed', $set: properties
    else if properties._player
      @emit 'changed', $set: properties
    else
      @emit 'changed', $set: properties, $unset: _player: true
    oldContainer?.componentRemoved?(@)


class CBGA.Container extends CBGA.Component
  constructor: (game, player, container, @_private) ->
    super game, player, container
    @_private ?= false

  find: (selector, options) ->
    selector ?= {}
    if typeof selector isnt 'string'
      selector._container = @_id
    (CBGA.getGameRules @game().rules).findComponents selector, options

  findOne: (selector, options) ->
    options ?= {}
    options.limit = 1
    @find(selector, options).fetch()[0]

class CBGA.OrderedContainer extends CBGA.Container
  find: (selector, options) ->
    options ?= {}
    options.sort ?= position: 1
    super selector, options

  first: (selector, options) ->
    @findOne selector, options

  last: (selector, options) ->
    options ?= {}
    options.sort ?= position: -1
    @findOne selector, options

  shuffle: ->
    ids = _.pluck CBGA.Components.find(_container: @_id,
      fields: _id: 1
    ).fetch(), '_id'
    _.shuffle ids
    @repack ids

  repack: (ids) ->
    unless ids?
      ids = _.pluck CBGA.Components.find(_container: @_id,
        fields: _id: 1, _class: 1
      ).fetch(), '_id'
    position = 0
    for id in ids
      CBGA.Components.update id, $set: position: position
      position += 1
    position

  acceptNewComponent: (component, properties) ->
    # XXX: This *could* race-condition if a game is concurrent enough
    # (If yours is, subclass and do something more clever)
    last = @last()
    properties.position = if last?
      last.position + 1
    else
      0

  componentRemoved: (component) ->
    @repack()
