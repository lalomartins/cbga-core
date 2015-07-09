# this doesn't really belong here, but I don't know where else yet :-)
CBGA.setupCollections()

# temporary publishes for development
Meteor.publish 'cbga-dev-all', -> [
    CBGA.Games.find()
    CBGA.Players.find()
    CBGA.Components.find()
]
