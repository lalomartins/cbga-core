digits64 = _.toArray '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-.'
simulationCollection = new Mongo.Collection null

CBGA.utils =
  str64: (number) ->
    digits = []
    oct = number.toString 8
    if oct.length % 2
      oct = '0' + oct
    while oct
      head = oct.substr 0, 2
      oct = oct.substr 2
      digits.push digits64[parseInt head, 8]
    digits.join ''

  parse64: (str) ->
    number = 0
    for digit in _.toArray str
      number *= 64
      dv = digits64.indexOf digit
      if dv is -1
        throw new TypeError 'Value is not a 64-base number'
      number += dv
    number

  shortId: (length = 7) ->
    if window?.crypto?.getRandomValues?
      array = new Uint32Array 1
      generator = ->
        window.crypto.getRandomValues array
        array[0]
    else
      generator = ->
        Math.floor Random.fraction() * 0xffffffff
    id = CBGA.utils.str64 new Date().valueOf() % 262143
    while id.length < length
      n = CBGA.utils.str64 generator()
      while n.length < 4
        n = '0' + n
      id += n
    id.substr 0, length

  shortIdCaseInsensitive: (length = 10) ->
    if window?.crypto?.getRandomValues?
      array = new Uint32Array 1
      generator = ->
        window.crypto.getRandomValues array
        array[0]
    else
      generator = ->
        Math.floor Random.fraction() * 0xffffffff
    id = (new Date().valueOf() % 1679615).toString 36
    while id.length < length
      n = generator().toString 36
      while n.length < 5
        n = '0' + n
      id += n
    id.substr 0, length

  simulateMongoUpdate: (doc, modifier) ->
    _id = doc._id
    if doc._toDb?
      doc = doc._toDb()
    else
      doc = _.clone doc
    doc._id = CBGA.utils.shortId()
    simulationCollection.insert doc
    simulationCollection.update doc._id, modifier
    result = simulationCollection.findOne doc._id
    result._id = _id
    simulationCollection.remove doc._id
    result

CBGA.Match =
  ClassOrSubclass: (cls) ->
    # Match.OneOf cls, Match.ObjectIncluding prototype: cls
    Match.Where (x) ->
      if x is cls or x?.prototype instanceof cls
        true
      else
        throw new Match.Error "Expected #{cls.name ? 'class'} or subclass"
