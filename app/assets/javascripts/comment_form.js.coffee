subject_changed = ->
  if $(this).val().match /^Tech/
    $('#support_details').show()
    $('#comment_comment').siblings('label').html('Please describe the problem
you are experiencing.')
  else
    $('#support_details').hide()
    $('#comment_comment').siblings('label').html('Comment')

$('#comment_subject').on('change', subject_changed).trigger('change')
