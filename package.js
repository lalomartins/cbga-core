Package.describe({
  name: 'cbga:core',
  version: '0.0.1',
  summary: 'Card and Board Game App API and core functionality',
  git: 'https://github.com/lalomartins/cbga-core.git',
  documentation: 'README.md',
});

Package.onUse(function(api) {
  api.versionsFrom('1.1.0.2');
  api.use([
    'blaze',
    'browser-policy',
    'check',
    'coffeescript',
    'mongo',
    'random',
    'templating',
    'underscore',
    'bengott:avatar',
    'raix:eventemitter',
    'lalomartins:template-helpers',
  ]);
  api.addFiles([
    'core.coffee',
    'utils.coffee',
    'player.coffee',
    'component.coffee',
    'game.coffee',
    'rules.coffee',
    'ui.coffee',
  ]);
  api.addFiles([
    'client/globalSubs.coffee',
    'client/templateHelpers.coffee',
  ], 'client');
  api.addFiles([
    'server/game.coffee',
    'server/misc-publishes.coffee',
    'server/playerData.coffee',
    'server/policy.coffee',
  ], 'server');
  api.addFiles([
  ], 'web.cordova');
  api.export('CBGA');
});
