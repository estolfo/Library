$(document).ready(function(){
	$('#flash-notice').fadeIn('slow', function() {
		$('#flash-notice').delay(1000).fadeOut('slow', function() {});
	});
});
