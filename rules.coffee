share.gameRules = {}

# There are two ways to define your own rules:
# 1: Instantiate GameRules, passing a name, and assign to gameClass,
# playerClass, and componentClass. This is easier.
# 2: Subclass it, overriding the class properties. This is more flexible,
# and necessary if you need to override methods.

class CBGA.GameRules
    constructor: (@name) ->
      @_controllers =
        panel: {}
        slot: {}

    gameClass: null

    newGame: ->
        if @gameClass?
            game = Object.create @gameClass.prototype
            @gameClass.apply game, arguments
            game._bindCollection CBGA.Games
            game
        else
            throw new Error 'You must override either gameClass, or newGame + wrapGame.'

    wrapGame: (gameDoc) ->
        if @gameClass?
            game = Object.create @gameClass.prototype
            game._load gameDoc
            game._bindCollection CBGA.Games
            game
        else
            throw new Error 'You must override either gameClass, or newGame + wrapGame.'

    findGames: (selector, options) ->
        selector ?= {}
        selector.rules ?= @name
        options ?= {}
        options.transform = _.bind @wrapGame, @
        CBGA.Games.find selector, options

    playerClass: null

    newPlayer: ->
        if @playerClass?
            player = Object.create @playerClass.prototype
            @playerClass.apply player, arguments
            player._bindCollection CBGA.Players
            player
        else
            throw new Error 'You must override either playerClass, or newPlayer + wrapPlayer.'

    wrapPlayer: (playerDoc) ->
        if @playerClass?
            player = Object.create @playerClass.prototype
            player._load playerDoc
            player._bindCollection CBGA.Players
            check player.game().rules, @name
            player
        else
            throw new Error 'You must override either playerClass, or newPlayer + wrapPlayer.'

    findPlayers: (selector, options) ->
        options ?= {}
        options.transform = _.bind @wrapPlayer, @
        CBGA.Players.find selector, options

    componentClass: null

    newComponent: ->
        if @componentClass?
            component = Object.create @componentClass.prototype
            @componentClass.apply component, arguments
            component._bindCollection CBGA.Components
            component
        else
            throw new Error 'You must override either componentClass, or newComponent + wrapComponent.'

    wrapComponent: (componentDoc) ->
        if @componentClass?
            component = Object.create @componentClass.prototype
            component._load componentDoc
            component._bindCollection CBGA.Components
            check component.game().rules, @name
            component
        else
            throw new Error 'You must override either componentClass, or newComponent + wrapComponent.'

    findComponents: (selector, options) ->
        options ?= {}
        options.transform = _.bind @wrapComponent, @
        CBGA.Components.find selector, options

    # For the UI, you must either have a `uiDefs` or a `uiTemplate` property.
    # For `uiDefs`, the format is:
    # {panels: [ui.Panel], componentTypes: [ui.ComponentType]}

    attachController: (arg) ->
      check arg, Match.OneOf String, CBGA.ui.Controller, CBGA.ui.Panel, CBGA.ui.Slot
      switch
        when arg instanceof CBGA.ui.Controller
          @_controllers[arg.widget][arg.id] = arg
        when arg instanceof CBGA.ui.Panel
          @_controllers.panel[arg.id] = new CBGA.ui.PanelContainerContoller
            rules: @
            panel: arg
        when arg instanceof CBGA.ui.Slot
          throw new Error 'not yet implemented'
        # else it's a string
        when arg.indexOf('/') > -1
          # panel_id/slot_id
          throw new Error 'not yet implemented'
        else
          @_controllers.panel[arg] = new CBGA.ui.PanelContainerContoller
            rules: @
            panel: arg

    attachControllersToAllPanels: (slotsToo) ->
      for panel in @uiDefs.panels
        @attachController panel
        if slotsToo
          for slot in panel.slots
           if (typeof slotsToo isnt 'function') or slotsToo slot
             @attachController slot

    getController: (widget, id) ->
      @_controllers[widget][id]

    getComponentType: (type) ->
      _.find @uiDefs.componentTypes, (ct) -> ct.name is type

CBGA.registerGameRules = (rules) ->
  if share.gameRules[rules.name]?
    throw new Error "There are already rules with the name '#{rules.name}'."
  share.gameRules[rules.name] = rules
  share.setupAllows()
  @

CBGA.getGameRules = (nameOrDoc) ->
  check nameOrDoc, Match.OneOf String, Match.ObjectIncluding(_game: String), Match.ObjectIncluding(rules: String)
  if nameOrDoc._game?
    gameDoc = CBGA.Games.findOne nameOrDoc._game
    unless gameDoc?
      throw new CBGA.GameError "Couldn't find game '#{doc.game}'"
    nameOrDoc = gameDoc.rules
  else
    nameOrDoc = nameOrDoc.rules if nameOrDoc.rules?
  rules = share.gameRules[nameOrDoc]
  unless rules?
    throw new CBGA.GameError "Couldn't find rules for '#{nameOrDoc}'"
  rules
