$(document).ready(function(){
    $('[data-toggle="popover"]').hover(function() {
      $('[data-toggle="popover"]').popover('show');
    }, 
    function() {
      $('[data-toggle="popover"]').popover('hide');
    });
});



