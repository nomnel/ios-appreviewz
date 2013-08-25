$ ->
  window.fn = {
    controller: ($body) ->
      $body.attr('class').split('_')[0]

    method: ($body) ->
      $body.attr('class').split('_')[1]

    scrollTo: (to, el) ->
      $('html, body').animate({
        scrollTop: $(el).closest(to).offset().top
      }, 'fast')

    switchVisibility: ($target) ->
      if $target.is(':visible')
        $target.hide()
      else
        $target.show()

    includedTo: (classes, $e) ->
      r = false
      $.each classes, (i, v) ->
        if $e.closest(".#{v}").hasClass(v)
          r = true
          return false # break
      r

    setSwitchEvent: (listener, container, target, func, alt) ->
      $(document).on 'click', listener, ->
        $(this).hide()
        c = $(this).closest(container)
        ls = c.find(target)
        $.each ls, ->
          eval("$(this).#{func}()")
        c.find(alt).show()
        fn.scrollTo container, this

    setClickEvent: (listener, func) ->
      f = (t, e) -> if $(t).attr('moved') == 'f' then func(t, e)
      $(document).on 'click',      listener, (e) -> func(this, e)
      $(document).on 'touchstart', listener, -> $(this).attr('moved', 'f')
      $(document).on 'touchmove',  listener, -> $(this).attr('moved', 't')
      $(document).on 'touchend',   listener, (e) -> f(this, e); return false;
  }
