$ ->
  return unless fn.controller($('body')) == 'reviews'

  $('#reviews-tab a').addClass('selected')

  $(document).on 'click', '.show-all-apps', ->
    $(this).hide()
    apps = $(this).closest('.apps').children('.app')
    $.each apps, ->
      $artwork = $(this).find('.artwork img')
      $artwork.attr('src', $artwork.data('src'))
      $(this).show()
    $(this).parent().children('.hide-apps').show()

  $(document).on 'click', '.hide-apps', ->
    fn.scrollTo '.review', this
    $(this).hide()
    apps = $(this).closest('.apps').children('.app')
    $.each apps, (i) ->
      $(this).hide() if i != 0
    $(this).parent().children('.show-all-apps').show()

  fn.setClickEvent '.app', (receiver, ev) ->
    return if fn.includedTo ['app-store', 'more-reviews'], $(ev.target)
    fn.switchVisibility $(receiver).closest('.app').find('.app-details')
    fn.switchVisibility $(receiver).closest('.app').find('.more-reviews')
    fn.scrollTo '.app', receiver
