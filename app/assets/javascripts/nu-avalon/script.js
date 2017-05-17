// Find any alerts on page
function checkAlerts() {
  var alertElements = document.getElementsByClassName('alert'),
    el;

  if (alertElements.length > 0) {
    el = alertElements[0];
    // Fade out
    setTimeout(function () {
      el.style.opacity = '0';
      removeNode(el);
    }, 5000);
  }
}

function removeNode(el) {
  setTimeout(function () {
    el.parentNode.removeChild(el);
  }, 500);
}

checkAlerts();
