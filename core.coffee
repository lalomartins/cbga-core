CBGA = {}

class CBGA._DbModelBase extends EventEmitter
    constructor: ->
        super
        @_setupTransients()

    _setupTransients: ->
        EventEmitter.call @

    _load: (doc) ->
        _.extend @, doc
        @_setupTransients()

    _toDb: ->
        tmp = new EventEmitter
        doc = {}
        for own field, value of @
            unless field of tmp or value instanceof CBGA._DbModelBase or value is undefined or field.match /^__/
                doc[field] = value
        doc

    _bindCollection: (collection) ->
        @on 'changed', (update) ->
            collection.update @_id, update


class CBGA.GameError extends Error
    constructor: (@message) ->
        @name = 'GameError'
        if Error.captureStackTrace?
            Error.captureStackTrace @, @constructor
        else
            # IE only sets the stack property on throw. I'm surprised to praise IE,
            # but that's obviously the correct behaviour in this case.
            # V8 has captureStackTrace which correctly ignores this method.
            # Firefox has a \n-separated string.
            stack = (new Error).stack
            if typeof stack is 'string'
                stack = stack.split '\n'
                loop
                    first = stack.shift()
                    if first.match new RegExp "^#{@constructor.name}"
                        break
                caller = stack[0].match /.*@(.*?):(\d+)(?::(\d+))?$/
                if caller?
                    @fileName = caller[1]
                    @lineNumber = caller[2]
                    @columnNumber = caller[3]
                @stack = stack.join '\n'

CBGA.findGame = (selector) ->
    doc = CBGA.Games.findOne selector
    unless doc?
        throw new CBGA.GameError "Couldn't find game '#{selector}'"
    rules = CBGA.getGameRules doc.rules
    unless rules?
        throw new CBGA.GameError "Couldn't find rules for '#{doc.rules}'"
    rules.wrapGame doc

CBGA.options = {}

CBGA.setupCollections = ->
    CBGA.Games = new Mongo.Collection CBGA.options?.names?.games ? 'games'
    CBGA.Players = new Mongo.Collection CBGA.options?.names?.players ? 'players'
    CBGA.Components = new Mongo.Collection CBGA.options?.names?.components ? 'components'

    CBGA.Players.deny
        update: (userId, doc, fieldNames) ->
            _.any fieldNames, (name) -> name is '_game' or name is '_user'
    CBGA.Components.deny
        update: (userId, doc, fieldNames, modifier) ->
            return true if _.any fieldNames, (name) -> name is '_game' or name is 'type'
            result = CBGA.utils.simulateMongoUpdate doc, modifier
            return false unless result._container?
            return true unless typeof result._container is 'string' and \
                CBGA.Components.find(result._container).count() is 1
            false
    share.setupAllows()

    @

# Pattern: all your allows and deny functions should start with (CS/JS):
#   return unless CBGA.getGameRules(doc) is MyRulesObject
#   if(CBGA.getGameRules(doc) !== MyRulesObject) return;
# and possibly in the case of components also checking _class if relevant.
# Be VERY CAREFUL with allowing inserts! In most cases, they shouldn't be
# allowed at all, and creating objects should be done by methods.
allowsDone = []
deniesDone = []
setupClassAllows = (_class, collection) ->
    if _class?.allow? and allowsDone.indexOf(_class) is -1
        allowsDone.push _class
        collection.allow _class.allow
    if _class?.deny? and deniesDone.indexOf(_class) is -1
        deniesDone.push _class
        collection.deny _class.deny

share.setupAllows = ->
    return unless CBGA.Games?
    for name, rules of share.gameRules
        setupClassAllows rules.gameClass, CBGA.Games
        setupClassAllows rules.playerClass, CBGA.Players
        for key, _class of rules.componentClasses
            setupClassAllows _class, CBGA.Components
