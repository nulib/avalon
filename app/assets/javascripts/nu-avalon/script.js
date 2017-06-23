function addLoader(el) {
  var loaderEl = document.createElement('div'),
    playerType = getPlayerType(el);

  loaderEl.className = (playerType === 'audio') ? 'loader-bar' : 'loader';

  // Add a faded-out class to the player behind the loader
  el[0].classList.add('loader-opacity');

  el[0].appendChild(loaderEl);
  addPoller(15);
  insuranceCleanup(20000);
}

function addPoller(counter) {
  var totalTimeEl = null,
    durationText = '';

  if (counter > 0) {
    totalTimeEl = document.getElementsByClassName('mejs-duration');
    if (totalTimeEl.length > 0) {
      durationText = totalTimeEl[0].innerText || totalTimeEl[0].textContent;
      // Is it all Os or valid time?
      if (durationText === '00:00' || durationText === '') {
        rePoll(counter);
      } else {
        removeLoader();
      }
    } else {
      rePoll(counter);
    }
  }
}

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

function getAvalonPlayer() {
  var el = document.getElementsByClassName('avalon-player');
  if (el.length > 0) {
    addLoader(el);
  }
}

function getPlayerType(el) {
  var playerType = (el[0].getElementsByTagName('audio').length > 0) ? 'audio' : 'video';
  return playerType;
}

// Insurance loader removal after 20 seconds
function insuranceCleanup(milliseconds) {
  setTimeout(function() {
    removeLoader();
  }, milliseconds);
}

function rePoll(counter) {
  setTimeout(function() {
    addPoller(counter - 1);
  }, 1000);
}

// Remove a node, after slight delay
function removeNode(el) {
  setTimeout(function () {
    el.parentNode.removeChild(el);
  }, 500);
}

function removeLoader() {
  var loader = document.querySelectorAll('.loader, .loader-bar'),
    parentNode = null;
  if (loader.length > 0) {
    parentNode = loader[0].parentNode;
    parentNode.classList.remove('loader-opacity');
    parentNode.removeChild(loader[0]);
  }
}

checkAlerts();
getAvalonPlayer();
