# TABLE BINDING plugin for Knockout http://knockoutjs.com/
# (c) Michael Best
# License: MIT (http://www.opensource.org/licenses/mit-license.php)
# Version 0.2.3
((ko, undefined_) ->

  makeRangeIfNotArray = (primary, secondary) ->
    primary = secondary.length  if primary is `undefined` and secondary
    (if (typeof primary is "number" and not isNaN(primary)) then ko.utils.range(0, primary - 1) else primary)

  isArray = (a) ->
    a and typeof a is "object" and typeof a.length is "number"

  findNameMethodSignatureContaining = (obj, match) ->
    for a of obj
      return a  if obj.hasOwnProperty(a) and obj[a].toString().indexOf(match) >= 0

  findPropertyName = (obj, equals) ->
    for a of obj
      return a  if obj.hasOwnProperty(a) and obj[a] is equals

  findSubObjectWithProperty = (obj, prop) ->
    for a of obj
      return obj[a]  if obj.hasOwnProperty(a) and obj[a] and obj[a][prop]

  div = document.createElement("div")

  elemTextProp = (if "textContent" of div then "textContent" else "innerText")

  div = null

  ko.bindingFlags = {}  unless ko.bindingFlags

  ko.bindingHandlers.table =
    flags: ko.bindingFlags.contentBind | ko.bindingFlags.contentSet

    init: ->
      controlsDescendantBindings: true

    update: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
      unwrapItemAndSubscribe = (rowIndex, colIndex) ->

        rowItem = rows[rowIndex]
        colItem = cols[colIndex]

        itemValue = if dataItem then ((if dataItemIsFunction then dataItem(rowItem, colItem, data) else data[rowItem][colItem[dataItem]])) else data[rowItem][colItem]

        if ko.isObservable(itemValue)
          itemSubs.push itemValue.subscribe((newValue) ->
            tableBody.rows[rowIndex].cells[colIndex][elemTextProp] = (if not newValue? then "" else newValue)  if tableBody
          )
          itemValue = (if itemValue.peek then itemValue.peek() else ko.ignoreDependencies(itemValue))

        if not itemValue? then "" else ko.utils.escape(itemValue)

      rawValue = ko.utils.unwrapObservable(valueAccessor())
      value = if isArray(rawValue) then data: rawValue else rawValue

      data = ko.utils.unwrapObservable(value.data)
      dataItem = ko.utils.unwrapObservable(value.dataItem)

      header = ko.utils.unwrapObservable(value.header)

      evenClass = ko.utils.unwrapObservable(value.evenClass)

      dataIsArray = isArray(data)
      dataIsObject = typeof data is "object"
      dataItemIsFunction = typeof dataItem is "function"

      headerIsArray = isArray(header)
      headerIsFunction = typeof header is "function"

      cols = makeRangeIfNotArray(ko.utils.unwrapObservable(value.columns), headerIsArray and header)
      rows = makeRangeIfNotArray(ko.utils.unwrapObservable(value.rows), dataIsArray and data)

      numCols = cols and cols.length
      numRows = rows and rows.length

      itemSubs = []

      tableBody = undefined
      rowIndex = undefined
      colIndex = undefined

      throw Error("table binding requires a data array or dataItem function")  if not dataIsObject and not dataItemIsFunction

      if numCols is `undefined` and dataIsArray and isArray(data[0])
        numCols = rowIndex = 0
        while rowIndex < data.length
          numCols = data[0].length  if data[0].length > numCols
          rowIndex++
        cols = makeRangeIfNotArray(numCols)

      throw Error("table binding requires row information (either \"rows\" or a \"data\" array)")  unless numRows >= 0

      throw Error("table binding requires column information (either \"columns\" or \"header\")")  unless numCols >= 0

      evenClass = ko.utils.escape(evenClass) if evenClass

      html = "<table>"

      if header
        html += "<thead><tr>"
        colIndex = 0
        while colIndex < numCols
          headerValue = (if headerIsArray then header[colIndex] else ((if headerIsFunction then header(cols[colIndex]) else cols[colIndex][header])))
          html += "<th>" + ko.utils.escape(headerValue) + "</th>"
          colIndex++
        html += "</tr></thead>"

      html += "<tbody>"

      rowIndex = 0

      while rowIndex < numRows
        html += (if (evenClass and rowIndex % 2) then "<tr class=\"" + evenClass + "\">" else "<tr>")
        colIndex = 0
        while colIndex < numCols
          html += "<td>" + unwrapItemAndSubscribe(rowIndex, colIndex) + "</td>"
          colIndex++
        html += "</tr>"
        rowIndex++

      html += "</tbody></table>"

      ko.removeNode element.firstChild while element.firstChild

      tempDiv = document.createElement("div")
      tempDiv.innerHTML = html
      tempTable = tempDiv.firstChild

      element.appendChild tempTable.firstChild  while tempTable.firstChild

      if itemSubs
        tableBody = element.tBodies[0]
        ko.utils.domNodeDisposal.addDisposeCallback tableBody, ->
          ko.utils.arrayForEach itemSubs, (itemSub) ->
            itemSub.dispose()

  ko.utils.escape = (string) ->
    ("" + string).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#x27;").replace /\//g, "&#x2F;"

  #
  # * ko.ignoreDependencies is used to access observables without creating a dependency
  #
  unless ko.ignoreDependencies
    depDet = findSubObjectWithProperty(ko, "end")
    depDetBeginName = findNameMethodSignatureContaining(depDet, ".push({")
    ko.ignoreDependencies = (callback, object, args) ->
      try
        depDet[depDetBeginName] ->

        return callback.apply(object, args or [])
      finally
        depDet.end()
) ko
