class CBGA.Game extends CBGA._DbModelBase
    # these seem like common defaults
    @MIN_PLAYERS = 2
    @MAX_PLAYERS = 4

    constructor: ->
        super
        # pattern: hardcode @rules = 'foo' for your ruleset
        @rules = null
        @_owner= null
        @expansions = []
        @created = new Date()
        @log = []

    @_wrap: (doc) ->
        (CBGA.getGameRules doc).wrapGame doc

    owner: ->
        Meteor.users.findOne @_owner

    _determineFirstPlayer: (rules, players) ->
        Random.choice players

    # called before _setupPlayer (build deck, etc)
    _setup1: (rules, players, update) ->

    # called for each player in order (deal cards, etc)
    _setupPlayer: (rules, player, update) ->

    # called after _setupPlayer (build lineup, etc)
    _setup2: (rules, players, update) ->

    # you *usually* don't want to override this one, instead customize
    # it via the methods above
    start: ->
        if @started?
            throw new CBGA.GameError 'This game is already running'
        rules = CBGA.getGameRules @rules
        players = rules.findPlayers
            _game: @_id
        ,
            sort: joined: 1
        .fetch()
        if players.length < @constructor.MIN_PLAYERS
            throw new CBGA.GameError 'Not enough players to start the game'
        if players.length > @constructor.MAX_PLAYERS
            throw new CBGA.GameError 'Too many players to start the game'
        @firstPlayer = @_determineFirstPlayer(rules, players)._id
        # reorder players…
        before = []
        after = []
        for player in players
            switch
                when after.length
                    after.push player
                when player._id is @firstPlayer
                    after.push player
                else
                    before.push player
        players = after.concat before
        @started = new Date()
        update = $set: started: @started
        @_setup1 rules, players, update
        for player in players
            @_setupPlayer rules, player, update
        @_setup2 rules, players, update
        @emit 'changed', update

    components: (container) ->
        rules = CBGA.getGameRules @rules
        unless rules?
            throw new CBGA.GameError "Couldn't find rules for '#{gameDoc.rules}'"
        if container?
            rules.findComponents
                _container: ['game', @_id, container]
        else
            rules.findComponents
                '_container.0': 'game'
                '_container.1': @_id
