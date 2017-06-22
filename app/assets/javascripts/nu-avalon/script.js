// Find any alerts on page
function checkAlerts() {
  var alertElements = document.getElementsByClassName('alert-success'),
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

// Remove a node, after slight delay
function removeNode(el) {
  setTimeout(function () {
    el.parentNode.removeChild(el);
  }, 500);
}

function removeLoader() {
  console.log('removeLoader');
  var loader = document.getElementsByClassName('loader');
  if (loader.length > 0) {
    loader[0].parentNode.removeChild(loader[0]);
  }
}

function getAvalonPlayer() {
  var el = document.getElementsByClassName('avalon-player');
  if (el.length > 0) {
    addLoader(el);
  }
}

function addLoader(el) {
  var loaderEl = document.createElement('div');
  loaderEl.className = 'loader';
  el[0].appendChild(loaderEl);
  addPoller(15);
}

function addPoller(counter) {
  if (counter > 0) {
    var totalTimeEl = document.getElementsByClassName('mejs-duration');
    if (totalTimeEl.length > 0) {
      // Is it all Os or valid time?
      if (totalTimeEl.innerText === '00:00') {
        rePoll(counter);
      } else {
        removeLoader();
      }
    } else {
      rePoll(counter);
    }
  }
}

function rePoll(counter) {
  setTimeout(function() {
    addPoller(counter - 1);
  }, 1000);
}


checkAlerts();
getAvalonPlayer();
