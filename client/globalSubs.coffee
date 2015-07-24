Meteor.subscribe 'player-avatars'
Meteor.subscribe 'all-users'
CBGA.setupCollections()
CBGA.ContainerCounts = new Meteor.Collection 'cbga-container-counts'
Meteor.subscribe 'cbga-dev-all'
