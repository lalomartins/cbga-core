class CBGA.Component extends CBGA._DbModelBase
  # A Component is defined as something that can be moved in the game.
  # In most games, that means cards, tokens, player markers, meeples,
  # and so on. Boards, character sheets *don't* need to be Components.
  constructor: (game, container) ->
    unless container? and game?
      throw new Error 'Component needs a game and a container'
    super
    @_game = game._id ? game
    @_container = container?._toDb?() ? container

  @_wrap: (doc) ->
    (CBGA.getGameRules doc).wrapComponent doc

  game: -> CBGA.Games.findOne @_game
  # XXX must subclass to override container class, there's probably a better way
  container: -> CBGA.Container._wrap @_container

  moveTo: (container, properties) ->
    properties ?= {}
    properties._container = container._toDb?() ? container
    if properties._container[1]._id?
      properties._container[1] = properties._container[1]._id
    # This is not ideal, since the `container` argument might just be an
    # array. It will be better after the refactoring.
    container.acceptNewComponent?(@, properties)
    for name, value of properties
      @[name] = value
    @emit 'changed', $set: properties


class CBGA.Container
  # A Container is a “place” where Components can be.
  # Containers are *NOT* real database objects; they're represented
  # by a [type, id, name, private] quad, where name is an arbitrary string
  # (e.g. 'hand') and type is 'game' or 'player'.

  # Note, if you create Containers in your _setupTransients, you MUST
  # pass in the owner object; if you pass @_id, there will be an infinite
  # loop trying to wrap it at the end.
  constructor: ([@type, @ownerId, @name, @private]) ->
    @private ?= false
    unless Match.test @type, Match.OneOf 'game', 'player'
      throw new Error "invalid container type #{@type}"

    if typeof @ownerId is 'object'
      @owner = @ownerId
      @ownerId = @owner._id
      if @type is 'game' and @owner instanceof CBGA.Player
        throw new Error "type is game but owner is player"
      if @type is 'player' and @owner instanceof CBGA.Game
        throw new Error "type is player but owner is game"
    else
      # Right… so first we need to get the owner from the db, then if
      # it's a player get the game, and only then we can get the rules,
      # which we need to wrap.
      # XXX: maybe a Rules.newContainer helper?
      collection = if @type is 'game'
          CBGA.Games
        else
          CBGA.Players
      @owner = collection.findOne @ownerId
    rulesName = if @type is 'game'
      @owner.rules
    else
      CBGA.Games.findOne(@owner._game).rules
    @rules = CBGA.getGameRules rulesName
    unless @owner instanceof CBGA._DbModelBase
      rulesName = if @type is 'game'
        @owner = @rules.wrapGame @owner
      else
        @owner = @rules.wrapPlayer @owner

  @_wrap: (data) ->
    if data?
      new @ data

  _toDb: ->
    [@type, @ownerId, @name, @private]

  find: (selector, options) ->
    selector ?= {}
    if typeof selector isnt 'string'
      selector._container = @_toDb()
    @rules.findComponents selector, options

  # For completeness, because I surprised myself expecting it to exist
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
    ids = _.pluck CBGA.Components.find(_container: @_toDb(),
      fields: _id: 1
    ).fetch(), '_id'
    _.shuffle ids
    @repack ids

  repack: (ids) ->
    unless ids?
      ids = _.pluck CBGA.Components.find(_container: @_toDb(),
        fields: _id: 1
      ).fetch(), '_id'
    position = 0
    for id in ids
      CBGA.Components.update id, $set: position: id
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
