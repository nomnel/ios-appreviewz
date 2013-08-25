$ ->
  return unless fn.controller($('body')) == 'apps'

  $('#apps-tab a').addClass('selected')
  fn.setClickEvent '.app', (receiver, ev) ->
    return if fn.includedTo ['app-store', 'more-reviews'], $(ev.target)
    fn.switchVisibility $(receiver).closest('.app').find('.app-details')
    fn.scrollTo '.app', receiver

  method = fn.method $('body')
  if method == 'show'
    $(document).on 'click touchstart', '.more', ->
      $(this).hide()
      $(this).closest('.app-details').find('.ellipsis').removeClass('ellipsis')

  else if method == 'index'
    fn.setSwitchEvent '.more-reviews', '.app-reviews', '.review', 'show', '.hide-reviews'
    fn.setSwitchEvent '.hide-reviews', '.app-reviews', '.review:not(:first-child)', 'hide', '.more-reviews'
