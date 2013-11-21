{toArray} = require 'underscore'
{Emitter} = require 'emissary'
ViewFactory = require './view-factory'

module.exports =
class View
  ViewFactory.extend(this)
  Emitter.includeInto(this)

  constructor: (@model, @element, @template) ->
    unless @element?
      if @constructor.canBuildViewForModel(model)
        @element = @constructor.buildElement(model)
        @template = @constructor
        @constructor.cacheView(this)
      else
        throw new Error("This view is not compatible with the given model")

    @bindings = []
    @createBindings(@element)
    @model.on 'detached', => @destroy()

  createBindings: (element) ->
    for child in element.children
      @createBindings(child)

    for attribute in element.attributes
      if match = attribute.name.match(/^x-bind-(.*)/)
        bindingType = match[1]
        binding = @template.bind(bindingType, element, @model, attribute.value)
        @bindings.push([bindingType, binding])
        binding

  destroy: ->
    for [bindingType, binding] in @bindings
      @template.unbind(bindingType, binding)
    @emit 'destroyed'
