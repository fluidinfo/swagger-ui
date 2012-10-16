class OperationView extends Backbone.View
  events: {
  'click .submit'           : 'submitOperation'
  'click .response_hider'   : 'hideResponse'
  'click .toggleOperation'  : 'toggleOperationContent'
  }

  initialize: ->

  render: ->
    isMethodSubmissionSupported = jQuery.inArray(@model.httpMethod, @model.supportedSubmitMethods()) >= 0
    @model.isReadOnly = true unless isMethodSubmissionSupported

    $(@el).html(Handlebars.templates.operation(@model))

    form = $('.sandbox', $(@el))
    form.submit (event) =>
      event.preventDefault()
      @submitOperation()

    # Render each parameter
    @addParameter param for param in @model.parameters
    @

  addParameter: (param) ->
    # Render a parameter
    paramView = new ParameterView({model: param, tagName: 'tr', readOnly: @model.isReadOnly})
    $('.operation-params', $(@el)).append paramView.render().el


  submitOperation: ->
    # Check for errors
    form = $('.sandbox', $(@el))

    error_free = true
    form.find("input.required").each ->
      $(@).removeClass "error"
      if jQuery.trim($(@).val()) is ""
        $(@).addClass "error"
        $(@).wiggle
          callback: => $(@).focus()
        error_free = false

    # if error free submit it
    if error_free
      map = {}
      for o in form.serializeArray()
        if(o.value? && jQuery.trim(o.value).length > 0)
          map[o.name] = o.value

      bodyParam = null
      contentType = null
      for param in @model.parameters
        if param.paramType is 'body'
          bodyParam = map[param.name]
          contentType = param.contentType

      useAuth = $(':input[name="useauth"]').prop('checked')
      if useAuth
        username = $(':input[name="username"]').val()
        password = $(':input[name="password"]').val()

        authHeader = "basic " + base64Encode("#{username}:#{password}")

        headerParams =
          "Authorization": authHeader
      else if swaggerUi.options.oauthToken
        headerParams =
          "X-FluidDB-Access-Token": swaggerUi.options.oauthToken
          "Authorization": "oauth2"
      else
        headerParams = null

      invocationUrl =
        if @model.supportHeaderParams()
          headerParams = @model.getHeaderParams(map)
          @model.urlify(map, false)
        else
          @model.urlify(map, true)

      $(".request_url", $(@el)).html "<pre>" + invocationUrl + "</pre>"
      $(".response_throbber", $(@el)).show()

      obj =
        type: @model.httpMethod
        url: invocationUrl
        headers: headerParams
        data: bodyParam
        dataType: 'json'
        error: (xhr, textStatus, error) =>
          @showErrorStatus(xhr, textStatus, error)
        success: (data) =>
          @showResponse(data)
        complete: (data) =>
          @showCompleteStatus(data)

      obj.contentType = "application/json" if (obj.type.toLowerCase() == "post" or obj.type.toLowerCase() == "put")

      log "model", @model

      if contentType?
        obj.contentType = contentType

      log "sending", obj

      jQuery.ajax(obj)
      # $.getJSON(invocationUrl, (r) => @showResponse(r)).complete((r) => @showCompleteStatus(r)).error (r) => @showErrorStatus(r)

  # handler for hide response link
  hideResponse: (e) ->
    e?.preventDefault()
    $(".response", $(@el)).slideUp()
    $(".response_hider", $(@el)).fadeOut()


  # Show response from server
  showResponse: (response) ->
    prettyJson = JSON.stringify(response, null, "\t").replace(/\n/g, "<br>")
    $(".response_body", $(@el)).html prettyJson


  # Show error from server
  showErrorStatus: (data) ->
    @showStatus data

  # show the status codes
  showCompleteStatus: (data) ->
    @showStatus data

  # puts the response data in UI
  showStatus: (data) ->
    try
      response_body = "<pre>" + JSON.stringify(JSON.parse(data.responseText), null, 2).replace(/\n/g, "<br>") + "</pre>"
    catch error
      response_body = "<span style='color:red'>&nbsp;&nbsp;&nbsp;[unable to parse as json; raw response below]</span><br><pre>" + data.responseText + "</pre>"
    $(".response_code", $(@el)).html "<pre>" + data.status + "</pre>"
    $(".response_body", $(@el)).html response_body
    $(".response_headers", $(@el)).html "<pre>" + data.getAllResponseHeaders() + "</pre>"
    $(".response", $(@el)).slideDown()
    $(".response_hider", $(@el)).show()
    $(".response_throbber", $(@el)).hide()

  toggleOperationContent: ->
    elem = $('#' + @model.resourceName + "_" + @model.nickname + "_" + @model.httpMethod + "_content");
    if elem.is(':visible') then Docs.collapseOperation(elem) else Docs.expandOperation(elem)


CHARACTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='

window.base64Encode = (text) ->

    if /([^\u0000-\u00ff])/.test(text)
        throw new Error "Can't base64 encode non-ASCII characters."

    digits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    i = 0
    result = []

    while i < text.length
        cur = text.charCodeAt(i)
        byteNum = i % 3

        switch byteNum
            when 0 then result.push(digits.charAt(cur >> 2)) # first byte
            when 1 then result.push(digits.charAt((prev & 3) << 4 | (cur >> 4))) # second byte
            when 2 #third byte
                result.push(digits.charAt((prev & 0x0f) << 2 | (cur >> 6)))
                result.push(digits.charAt(cur & 0x3f))

        prev = cur
        i++

    if byteNum is 0
        result.push(digits.charAt((prev & 3) << 4))
        result.push("==")
    else if byteNum is 1
        result.push(digits.charAt((prev & 0x0f) << 2))
        result.push("=")

    # return a string
    result.join("")
