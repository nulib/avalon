/**
 * This name spaced file exposes custom NU Avalon JS functionality
 */
var NU_AVALON_JS = {
  addLoader: function (el) {
    var loaderEl = document.createElement('div'),
      playerType = this.getPlayerType(el),
      isIFrame = window != window.top;

    if (!isIFrame) {
      // Regular way to add the loader in Avalon app
      this.mejsEl = el.firstElementChild;
    } else {
      // We're in an iFrame - most likely embedded and need to
      // mount the loader to a non-Rails generated element
      this.mejsEl = document.getElementById('content');
      // Center the spinner
      loaderEl.setAttribute('style', 'top: 0; bottom: 0');
    }

    if (this.mejsEl !== null) {
      loaderEl.className = (playerType === 'audio') ? 'loader-bar' : 'loader';
      this.mejsEl.classList.add('loader-opacity');
      this.mejsEl.appendChild(loaderEl);
      this.addPoller(15);
      this.insuranceCleanup(20000);
    }
  },

  /**
   * Keep checking to see if MediaElement has updated the time duration
   * field, which is a roundabout way of identifying a 'ready' state.
   * This is a temporary fix which will not be needed with MediaElement 4 upgrade.
   */
  addPoller: function (counter) {
    var totalTimeEl,
      totalTimeEls,
      durationText = '';

    if (counter > 0) {
      totalTimeEls = document.getElementsByClassName('mejs-duration');
      if (totalTimeEls.length > 0) {
        totalTimeEl = totalTimeEls[0];
        durationText = totalTimeEl.innerText || totalTimeEl.textContent;
        // Is it all Os or valid time?
        if (durationText === '00:00' || durationText === '') {
          this.rePoll(counter);
        } else {
          this.removeLoader();
        }
      } else {
        this.rePoll(counter);
      }
    }
  },

  // Find any alerts on page, and fade them out after a few seconds
  // Note this is separate from other scripts on the page
  checkAlerts: function () {
    var alertElements = document.getElementsByClassName('alert-success'),
      el;

    if (alertElements.length > 0) {
      el = alertElements[0];
      // Fade out
      setTimeout(function () {
        el.style.opacity = '0';
        NU_AVALON_JS.removeNode(el);
      }, 5000);
    }
  },

  getAvalonPlayer: function () {
    var els = document.getElementsByClassName('avalon-player');
    if (els.length > 0) {
      this.addLoader(els[0]);
    }
  },

  getPlayerType: function (el) {
    var playerType = (el.getElementsByTagName('audio').length > 0) ? 'audio' : 'video';
    return playerType;
  },

  // Insurance loader removal after 20 seconds
  insuranceCleanup: function (milliseconds) {
    setTimeout(function() {
      NU_AVALON_JS.removeLoader();
    }, milliseconds);
  },

  mejsEl: null,

  rePoll: function (counter) {
    setTimeout(function() {
      NU_AVALON_JS.addPoller(counter - 1);
    }, 1000);
  },

  // Remove a node, after slight delay
  removeNode: function (el) {
    setTimeout(function () {
      el.parentNode.removeChild(el);
    }, 500);
  },

  removeLoader: function () {
    var loaders = document.querySelectorAll('.loader, .loader-bar'),
      loaderOpacityEls = document.querySelectorAll('.loader-opacity'),
      loaderCount = (loaderOpacityEls.length > 0) ? loaderOpacityEls.length : 0;

    if (loaders.length > 0) {
      this.mejsEl.removeChild(loaders[0]);
    }
    // Need to separate this from above conditional for embedded players
    if (loaderCount > 0) {
      for (var i = 0; i < loaderCount; i++) {
        loaderOpacityEls[i].classList.remove('loader-opacity');
      }
    }
  }
};

NU_AVALON_JS.checkAlerts();
NU_AVALON_JS.getAvalonPlayer();
