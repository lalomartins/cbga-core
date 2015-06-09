class CBGA.Player extends CBGA._DbModelBase
    constructor: (game, user) ->
        super
        @_user = user._id ? user
        @_game = game._id ? game

    @_wrap: (doc) ->
        CBGA.getGameRules @game().rules
        .wrapPlayer doc

    game: ->
        CBGA.findGame @_game

    components: (container) ->
        rules = CBGA.getGameRules @game().rules
        if container?
            rules.findComponents
                _container: ['player', @_id, container]
        else
            rules.findComponents
                '_container.0': 'player'
                '_container.1': @_id
