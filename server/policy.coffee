BrowserPolicy.content.allowSameOriginForAll()

# that's probably unsafe if you're doing anything sensitive but hey
BrowserPolicy.content.allowConnectOrigin 'https://*.meteor.com'
BrowserPolicy.content.allowConnectOrigin 'wss://*.meteor.com'

BrowserPolicy.content.allowImageOrigin 'http://www.google-analytics.com'
BrowserPolicy.content.allowScriptOrigin 'http://www.google-analytics.com'
BrowserPolicy.content.allowStyleOrigin 'http://fonts.googleapis.com'
BrowserPolicy.content.allowStyleOrigin 'https://themes.googleusercontent.com'
BrowserPolicy.content.allowFontOrigin 'http://themes.googleusercontent.com'
BrowserPolicy.content.allowFontOrigin 'http://fonts.gstatic.com'
BrowserPolicy.content.allowFontOrigin 'https://fonts.gstatic.com'

# avatar sources; must add others later on
BrowserPolicy.content.allowImageOrigin 'https://secure.gravatar.com'
