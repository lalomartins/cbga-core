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
