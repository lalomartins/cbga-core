CBGA.setupCollections()

# temporary publishes for development
Meteor.publish 'cbga-dev-all', -> [
    CBGA.Games.find()
    CBGA.Players.find()
    CBGA.Components.find()
]
