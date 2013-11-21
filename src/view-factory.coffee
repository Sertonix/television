{find, clone} = require 'underscore'
Mixin = require 'mixto'
{Subscriber} = require 'emissary'
HTMLBuilder = require './html-builder'

module.exports =
class ViewFactory extends Mixin
  Subscriber.includeInto(this)

  constructor: ({@name, @content, @parent}={}) ->
    @registerDefaultBinders()

  extended: ->
    @registerDefaultBinders()

  registerDefaultBinders: ->
    @registerBinder('text', require('./bindings/text-binding'))
    @registerBinder('component', require('./bindings/component-binding'))
    @registerBinder('collection', require('./bindings/collection-binding'))

  getBinders: ->
    @binders ?= {}

  getChildFactories: ->
    @childFactories ?= []

  getViewCache: ->
    @viewCache ?= new WeakMap

  buildViewFactory: (params) ->
    new @constructor(params)

  register: (factories...) ->
    for factory in factories
      factory = new @constructor(factory) if factory.constructor is Object
      factory.parent = this
      @getChildFactories().push(factory)
      @[factory.name] = factory

  registerBinder: (type, binder) ->
    @getBinders()[type] = binder

  getBinder: (type) ->
    @getBinders()[type] ? @parent?.getBinder(type)

  viewForModel: (model) ->
    if view = @getCachedView(model)
      view
    else if @canBuildViewForModel(model)
      if element = @buildElement(model)
        @cacheView(new View(model, element, this))
      else
        throw new Error("Template did not specify content")
    else
      if childFactory = find(@getChildFactories(), (f) -> f.canBuildViewForModel(model))
        childFactory.viewForModel(model)
      else
        @parent?.viewForModel(model)

  canBuildViewForModel: (model) ->
    @name is "#{model.constructor.name}View"

  cacheView: (view) ->
    {model} = view
    viewCache = @getViewCache()
    viewCache.set(model, []) unless viewCache.has(model)
    views = viewCache.get(model)
    @subscribe view, 'destroyed', => views.splice(views.indexOf(view), 1)
    views.push(view)
    view

  getCachedView: (model) ->
    if views = @getViewCache().get(model)
      find views, (view) -> not view.element.parentNode?

  bind: (type, element, model, propertyName) ->
    if binder = @getBinder(type)
      binder.bind(this, element, model, propertyName)

  unbind: (type, binding) ->
    if binder = @getBinder(type)
      binder.unbind(binding)

  buildElement: (model) ->
    switch typeof @content
      when 'string'
        @parseHTML(@content)
      when 'function'
        builder = new HTMLBuilder
        result = @content.call(builder, model)
        if builderResult = builder.toHTML()
          result = builderResult
        if typeof result is 'string'
          @parseHTML(result)
        else
          result
      else
        @content.cloneNode(true)

  parseHTML: (string) ->
    div = window.document.createElement('div')
    div.innerHTML = string
    element = div.firstChild
    div.removeChild(element)
    element

  buildHTML: (args..., fn) ->
    builder = new HTMLBuilder
    result = fn.call(builder, args...)
    builder.toHTML()

View = require './view'
