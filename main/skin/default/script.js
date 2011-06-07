/* $Id: script.js 354 2010-05-07 03:08:34Z aragorn@bawi.org $ */
try { console.log('init console... done'); } catch(e) { console = { log: function() {} } }

function update_checking_note () {
  if ( $('bawi-mobile-device') &&
       $('bawi-mobile-device').readAttribute('content').toLowerCase() == 'yes' )
  {
    var check = new Ajax.Updater('note-container',
                                 "../../note_check.cgi",
                                 { method: 'get' });
    return; /* do not check for new notes periodically with mobile device */
  }
  var check = new Ajax.PeriodicalUpdater('note-container',
    "../../note_check.cgi",
    { method: 'get',
      frequency: 10,
      decay: 1.2,
      na: 0
    });

  if ( ! $$('body.note.reload').first() ) return;

  var exec = new PeriodicalExecuter(function(pe) {
    if ($('note-mbox-count')) { pe.stop(); return; /* stop here. */ }

    var inbox = new Ajax.Updater('note-messages-container',
                                 "../../note.cgi?wait=1;crop=1;",
                                 { method: 'get' });
  }, 10);

  var timer = new PeriodicalExecuter( function (e) {
    $$('body.note.reload span.timer.sec').each( function(item) {
     var sec = item.innerHTML; sec ++; item.innerHTML = sec;
    });
  },1);
  
} /* function update_checking_note () */

function toggle_display (e)
{
    e.stop();
    this.up(".toggle-container").select(".toggle").invoke('toggleClassName','hidden');
}

function open_user_popup(e) {
    e.stop();
    var options = 'toolbar=0,location=0,status=0,menubar=0,scrollbars=1,resizable=1,width=600,height=500';
    var w = window.open(this.readAttribute('href'),this.readAttribute('target'),options);
    if (window.focus) { $(w).activate(); w.focus(); }
}

function toggle_accesskey_hint(e) {
    e.stop();
    //$('content').select('a[accesskey]').invoke('toggleClassName', 'accesskey');
    $('globalWrapper').select('a[accesskey]').invoke('toggleClassName', 'accesskey');
}

function toggle_more_less(e) {
    e.stop();
    var button = new String(this.innerHTML);
    if ( button.match(/more/) ) {
      button = button.replace(/more/,'less');
      this.innerHTML = button;
      this.up('.more-less-container').select('.opt').invoke('removeClassName','hidden');
    }
    else {
      button = button.replace(/less/,'more');
      this.innerHTML = button;
      this.up('.more-less-container').select('.opt').invoke('addClassName','hidden');
    }
    //this.up('.more-less-container').select('.opt').invoke('toggleClassName','hidden');
}


document.observe("dom:loaded", function() {
  update_checking_note();

  $$('.user-popup').each( function(item) { item.observe('click', open_user_popup); });
  $$('a.user-profile').each( function(item) { item.observe('click', open_user_popup); });
  $$('a.user-message').each( function(item) { item.observe('click', open_user_popup); });
  $$('a.help-accesskey').each( function(item) { item.observe('click', toggle_accesskey_hint); });
  $$('a.more-less').each( function(item) { item.observe('click', toggle_more_less); });

  if ($("login_id")) $("login_id").focus();

  $$('.toggle.switch a').each( function(item) { item.observe('click', toggle_display); });

  $$('#bottom-log a').each( function(item) {
   item.observe('click', toggle_debug_log);
   item.up('div').select('span').invoke('hide');
  });

});

document.observe("dom:loaded", function() {

  var name = "xxfloatedMenu"; if ($(name) == null) return;
  var pos = $(name).positionedOffset();

  Event.observe(window, "scroll", function() {
    $(name).absolutize();
    new Effect.Move($(name), {
      x: pos.left,
      y: pos.top + document.viewport.getScrollOffsets().top,
      mode: 'absolute'
    });
  });

});

function set_focus (id) {
  var element = document.getElementById( id );
  if ( element ) { element.focus(); return; }
  return;
}

function toggle_debug_log (e) {
    e.stop();
    this.up("div").select("span").invoke('toggle');
}
