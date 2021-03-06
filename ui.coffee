ui = CBGA.ui = {}

class ui.Panel
  constructor: ({@name, @title, @owner, @visibility, @icon, @contains, @provides,
                 @private, slots} = {}) ->
    check @name, String
    @owner ?= 'game'
    @visibility ?= 'public'
    @contains ?= []
    check @contains, [String]
    @provides ?= []
    check @provides, [String]
    @slots = {}
    for slot in slots ? []
      if slot instanceof ui.Slot
        @slots[slot.id] = slot
        slot.panel = @
      else if typeof slot is 'string'
        @slots[slot] = new ui.Slot id: slot, panel: @
      else if typeof slot is 'object'
        @slots[slot.id] = new ui.Slot id: slot.id, title: slot.title, panel: @


# Slots are really later on in the backlog, but here's the API anyway
# Slots are for cases where exactly zero or one component of certain
# characteristics can be played. For example, in Girls War, the current
# trends have one slot for the positive trend, and one for the negative.
# The units *may* be implemented with a slot for the manager.
class ui.Slot
  constructor: ({@id, @title, @panel} = {}) ->
    check @id, String
    check @panel, ui.Panel


class ui.ComponentStack
  constructor: ({@uiType, container, @stack, @count}) ->
    @type = @uiType.name
    @_container = container
    check @uiType, ui.ComponentType
    check @count, Number
    check container, CBGA.Container
    # pretend we're a component
    if @stack?
      @[@uiType.stackProperty] = @stack

  # for compatibility with the Component API
  container: -> @_container


class ui.ComponentType
  constructor: ({@name, @width, @height, @isCounter, @stackProperty, @stackAfter,
                 @displayNameSingular, @displayNamePlural, @controllerClass,
                 @draggable, @contains, @template, @summaryTemplate} = {}) ->
    check @name, String
    check @width, Match.Optional Number
    check @height, Match.Optional Number
    @isCounter ?= false
    check @isCounter, Boolean
    if @isCounter
      check @stackProperty, Match.Optional String
      @stackAfter ?= 2
      check @stackAfter, Number
    else
      check @stackProperty, undefined
      check @stackAfter, undefined
    @displayNameSingular ?= @name
    check @displayNameSingular, String
    @displayNamePlural ?= @displayNameSingular
    check @displayNamePlural, String
    @controllerClass ?= ui.ComponentController
    check @controllerClass, CBGA.Match.ClassOrSubclass ui.Controller
    @draggable ?= false
    check @draggable, Boolean
    @contains ?= []
    check @contains, [String]
    check @template, Match.Optional String
    check @summaryTemplate, Match.Optional String

  render: (component) ->
    new Blaze.Template =>
      component ?= Template.currentData()
      template = if @template
        Template[@template]
      else
        rules = component.game().rules
        Template["#{rules.replace /\s/g, ''}ComponentView"] ? Template.componentDefaultView
      controller = new @controllerClass uiType: @, component: component
      Blaze.With (controller: controller, component: component), -> template

  summary: (count, stack) ->
    if stack?
      if count is 1
        "1 #{stack} #{@displayNameSingular}"
      else if count
        "#{count} #{stack} #{@displayNamePlural}"
    else
      if count is 1
        "1 #{@displayNameSingular}"
      else if count
        "#{count} #{@displayNamePlural}"

  getCounterTemplate: (count, rules) ->
    if count > @stackAfter
      if @summaryTemplate
        Template[@summaryTemplate]
      else
        Template["#{rules.replace /\s/g, ''}CounterSummary"] ? Template.counterSummaryDefault
    else
      if @template
        Template[@template]
      else
        Template["#{rules.replace /\s/g, ''}Counter"] ? Template.counterDefault

  renderCounter: (container) ->
    if @stackProperty?
      # oh boy
      new Blaze.Template =>
        container ?= Template.currentData()
        # Since this is a template render function, it's already reactive
        values = {}
        fields = {}
        fields[@stackProperty] = 1
        # Go directly to the collection to sidestep the transform
        # (could also use transform=null but this is faster)
        CBGA.Components.find type: @name, _container: container._id,
          fields: fields
        .forEach (doc) =>
          values[doc[@stackProperty]] = true
          return
        for value of values
          selector = type: @name
          selector[@stackProperty] = value
          cursor = container.find selector
          count = cursor.count()
          if cursor.count() > @stackAfter
            Blaze.With (new ui.ComponentStack uiType: @, container: container, stack: value, count: count), =>
              @getCounterTemplate count, container.game().rules
          else
            ((cursor) =>
              Blaze.With (uiType: @, stack: value, container: container), =>
                Blaze.Each (-> cursor), =>
                  @getCounterTemplate count, container.game().rules
            )(cursor)
    else
      new Blaze.Template =>
        container ?= Template.currentData()
        cursor = container.find type: @name
        count = cursor.count()
        if cursor.count() > @stackAfter
          Blaze.With (new ui.ComponentStack uiType: @, container: container, count: count), =>
            @getCounterTemplate count, container.game().rules
        else
          Blaze.With (=> type: @, container: container), =>
            Blaze.Each (-> cursor), =>
              @getCounterTemplate count, container.game().rules


class ui.Controller extends EventEmitter
  handleDragLeave: (event) ->
    $('.drag-allowed').removeClass 'drag-allowed'

  # XXX not sure at all about this one
  getContainer: (owner) ->
    owner

  # This method sets alternate representations of the component, in case a
  # player drags it somewhere else, such as a text editor or Facebook post
  # composition area
  setDataTransfer: (dataTransfer, element) ->
    $e = $ element
    dataTransfer.setData 'text/html', $e.html()
    dataTransfer.setData 'text/plain', $e.text()

  # Override this to set other properties on move; but ideally don't, if
  # possible, that should be done in the container class instead
  doMoveComponent: (component, owner, oldContainer, count = 1) ->
    if component instanceof CBGA.Component
      if count is 1
        component.moveTo @getContainer owner
      else
        type = @rules.getComponentType component.type
        selector = type: component.type
        if type.stackProperty?
          selector[type.stackProperty] = component[type.stackProperty]
        component.container().find selector, limit: count
        .forEach (eachComponent) =>
          eachComponent.moveTo @getContainer owner

    else if component instanceof ui.ComponentStack
      type = @rules.getComponentType component.type
      selector = type: component.type
      if type.stackProperty?
        selector[type.stackProperty] = component[type.stackProperty]
      component.container().find selector, limit: count
      .forEach (eachComponent) =>
        eachComponent.moveTo @getContainer owner

    else if component.provider
      # This can't be done on the client because typically a provider is private
      # (deck of cards, for example)
      # XXX missing stackProperty
      target = @getContainer owner
      options =
        rules: @rules.name
        type: component.type
        source: component.container._id
        target: target._id
        count: count
      Meteor.call 'component.draw', options


class ui.PanelContainerController extends ui.Controller
  constructor: ({@rules, @panel, @container} = {}) ->
    @widget = 'panel'
    if typeof @rules is 'string'
      @rules = CBGA.getGameRules @rules
    check @rules, CBGA.GameRules
    if typeof @panel is 'string'
      @panel = _.find @rules.uiDefs.panels, (panel) -> panel.name is @panel
    check @panel, ui.Panel
    @name = @panel.name
    check @container, Match.Optional String
    @container ?= @panel.name

  hasCounters: ->
    _.any @panel.contains, (typeName) =>
      type = @rules.getComponentType typeName
      type.isCounter

  renderCounters: (owner) ->
    if @panel.contains.length
      new Blaze.Template =>
        owner ?= Template.currentData().owner
        _.map @panel.contains, (typeName) =>
          type = @rules.getComponentType typeName
          if type.isCounter
            type.renderCounter @getContainer owner

  renderFull: (owner) ->
    if @panel.contains.length
      new Blaze.Template =>
        owner ?= Template.currentData().owner
        # Why _.map instead of coffee's for?
        # Because then it has its own locals.
        _.map @panel.contains, (typeName) =>
          typeId = typeName.replace /\s/g, '-'
          type = @rules.getComponentType typeName
          unless type.isCounter
            cursor = @getContainer(owner).find type: typeName
            HTML.DIV class: ['game-panel-component-type', ' ',
                             "game-panel-component-type-#{typeId}"], [
              Blaze.Each (=> cursor), =>
                component = Template.currentData()
                type.render component
              if @panel.visibility is 'stack'
                # XXX use a template
                HTML.DIV class: ['item', ' ', 'component-summary', ' ',
                                 'game-panel-component-type-count'],
                  type.summary cursor.count()
              ]
    else
      new Blaze.Template =>
        owner ?= Template.currentData().owner
        cursor = @getContainer(owner).find()
        HTML.DIV class: ['game-panel-component-type'], [
          [Blaze.Each (=> cursor), =>
            component = Template.currentData()
            type = @rules.getComponentType component.type
            type.render component
          ]
          if @panel.visibility is 'stack'
            # XXX use a template
            HTML.DIV class: ['item', ' ', 'component-summary', ' ',
                             'game-panel-component-type-count'],
              type.summary cursor.count()
        ]

  summary: (owner) ->
    # XXX missing stackProperty
    owner ?= Template.currentData().owner
    CBGA.ContainerCounts.find
      ownerType: @panel.owner
      owner: owner._id
      name: @container
    .map (container) =>
      type = @rules.getComponentType(container.type)
      type: container.type
      typeInfo: type
      container: container
      text: type.summary(container.count)
      provider: type.draggable and container.count and container.type in @panel.provides

  getOwner: (elementOrView) ->
    # elementOrView can also be undefined for the current view
    if elementOrView instanceof Blaze.View
      view = elementOrView
    else
      view = Blaze.getView(elementOrView)
    while view
      data = Blaze.getData view
      if data.owner? and data.controller is @
        return data.owner
    null

  getContainer: (owner) ->
    owner ?= @getOwner()
    if @panel.owner is 'player'
      owner.game().getContainers([@panel.name], owner)[0]
    else
      owner.getContainers([@panel.name])[0]

  handleDragOver: (event) ->
    operation = ui.DragAndDropService.get event
    return unless operation
    owner = @getOwner(event.currentTarget)
    return if operation.sourceOwner._id is owner._id and operation.sourceController is @
    if (not @panel.contains.length) or \
       @panel.contains.indexOf(operation.component.type) > -1
      $(event.currentTarget).addClass 'drag-allowed'
      event.preventDefault()
      true

  handleDrop: (event) ->
    $(event.currentTarget).removeClass 'drag-allowed'
    operation = ui.DragAndDropService.get event
    return unless operation
    event.preventDefault()
    owner = @getOwner(event.currentTarget)
    @doMoveComponent operation.component, owner,
      operation.sourceController.getContainer operation.sourceOwner
    true


# XXX there's an API mismatch since a PanelContainerController is bound to a
# panel and shared between containers, while a ComponentController is bound to
# a specific component. Have to evaluate if it's a problem.
class ui.ComponentController extends ui.Controller
  constructor: ({@uiType, @component} = {}) ->
    @rules = CBGA.getGameRules @component.game().rules

  # We'll probably need something like renderFull for recursive-ish components
  # (e.g. cards that go on cards)
  renderCounters: ->
    new Blaze.Template =>
      if @uiType.contains.length
        _.map @uiType.contains, (typeName) =>
          type = @rules.getComponentType typeName
          if type.isCounter
            type.renderCounter @component

  handleDragOver: (event) ->
    operation = ui.DragAndDropService.get event
    return unless operation
    $('.drag-allowed').removeClass 'drag-allowed'
    return if operation.sourceOwner._id is @component._id and operation.sourceController is @
    return if operation.component._id is @component._id
    if operation.component.type in @uiType.contains
      $(event.currentTarget).addClass 'drag-allowed'
      event.preventDefault()
      event.stopImmediatePropagation()
      true

  handleDrop: (event) ->
    return unless $(event.currentTarget).hasClass 'drag-allowed'
    $(event.currentTarget).removeClass 'drag-allowed'
    operation = ui.DragAndDropService.get event
    return unless operation
    event.preventDefault()
    event.stopImmediatePropagation()
    @doMoveComponent operation.component, @component,
      operation.sourceController.getContainer operation.sourceOwner
    true


class ui.DragAndDropOperation
  constructor: (@_id, event) ->
    @element = event.currentTarget
    view = Blaze.getView @element
    while view and view isnt Blaze.currentView
      data = Blaze.getData view
      if (data instanceof CBGA.Component or data instanceof ui.ComponentStack or
          data.provider) \
          and not @component?
        @component = data
      if data.controller? and (data.owner? or data.component?) and not @sourceController?
        @sourceController = data.controller
        @sourceOwner = data.owner ? data.component
      break if @component? and @sourceController?
      view = view.parentView
    check @component, Match.OneOf CBGA.Component, ui.ComponentStack,
      Match.ObjectIncluding provider: Boolean, type: String,
        typeInfo: ui.ComponentType
    check @sourceController, ui.Controller
    event.originalEvent.dataTransfer.setData 'application/vnd-cbga-dnd', @_id
    event.originalEvent.dataTransfer.setData "application/vnd-cbga:#{@_id}", 'dnd'
    @sourceController.setDataTransfer event.originalEvent.dataTransfer, @element


getId = (dataTransfer) ->
  id = dataTransfer.getData 'application/vnd-cbga-dnd'
  if id
    id
  else
    for type in dataTransfer.types
      m = type.match /application\/vnd-cbga:(.*)/
      if m
        return m[1]


class DragAndDropService
  constructor: ->
    @_operations = {}

  get: (eventOrId) ->
    if eventOrId.originalEvent?
      eventOrId = getId eventOrId.originalEvent.dataTransfer
    if eventOrId?.dataTransfer?
      eventOrId = getId eventOrId.dataTransfer
    @_operations[eventOrId]

  start: (event) ->
    id = CBGA.utils.shortIdCaseInsensitive()
    @_operations[id] = new ui.DragAndDropOperation id, event

  discard: (eventOrId) ->
    operation = @get eventOrId
    if operation?
      Meteor.setTimeout =>
        delete @_operations[operation._id]
      , 1000

  installHandlers: (template,
                    componentSelector = '.component[draggable], .provider[draggable]',
                    panelSelector = '.game-panel, .component.container') ->
    handlers = {}

    makeKey = (event, selector) ->
      ("#{event} #{sel}" for sel in selector.split ',').join ', '

    handlers[makeKey 'dragstart', componentSelector] = (event, ti) =>
      @start event
      event.stopImmediatePropagation()
      true

    handlers[makeKey 'dragend', componentSelector] = (event, ti) =>
      @discard event

    handlers[makeKey 'dragover', panelSelector] = (event) ->
      @controller.handleDragOver event

    handlers[makeKey 'dragleave', panelSelector] = (event) ->
      @controller.handleDragLeave event

    handlers[makeKey 'drop', panelSelector] = (event) ->
      @controller.handleDrop event

    template.events handlers

ui.DragAndDropService = new DragAndDropService()
