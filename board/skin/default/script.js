/* $Id: script.js 364 2010-05-19 14:59:06Z aragorn@bawi.org $ */
/* 2010-03-11 NOT IN USE - aragorn */
try { console.log('init console... done'); } catch(e) { console = { log: function() {} } }

function editComment(id) {
    // intercept normal comment submitting form with saveComment
    document.addcomment.body.disabled = true;
    document.addcomment.onsubmit = new Function("saveComment('"+ id + "'); return false;");
    var comment = document.getElementById(id);
    var text = comment.innerHTML;
    var input = document.createElement('input');
    input.setAttribute('value', text);
    input.setAttribute('class', 'text');
    input.setAttribute('size', '59');
    input.setAttribute('type', 'text');
    input.setAttribute('name', 'commentbody');
    input.setAttribute('id', id);
    input.setAttribute('maxlength', '100');
    input.setAttribute('style', 'width: 420px');
    input.onblur = new Function("saveComment('"+ id + "');");
    var z = comment.parentNode;
    z.replaceChild(input, comment);
    input.focus();
}

/* 2010-03-11 NOT IN USE - aragorn */
function saveComment(id) {
    var f = document.getElementById(id);
    var d = document.createElement('div');
    d.setAttribute('class', 'comment');
    d.setAttribute('id', id);
    var p = document.createElement('img');
    p.setAttribute('src', 'skin/default/images/progress-ring.gif');
    p.setAttribute('width', '16');
    p.setAttribute('height', '16');
    p.setAttribute('align', 'left');
    p.setAttribute('hspace', '2');
    p.setAttribute('alt', 'saving...');
    p.setAttribute('border', '0');
    d.appendChild(p);
    var msg = document.createTextNode('saving...');
    d.appendChild(msg);
    var z = f.parentNode;
    z.replaceChild(d, f);
    var url = 'update.cgi';
    var param = "id=" + encodeURIComponent(id) + "&text=" + encodeURIComponent(f.value);
    var c = new XHConn();
    if (!c) alert("XMLHTTP not available. Try a newer/better browser.");
    c.connect(url, "POST", param, updateComment);
}

/* 2010-03-11 NOT IN USE - aragorn */
function updateComment(c) {
    var xml = c.responseXML;
    var error = xml.getElementsByTagName('error').item(0).firstChild.data;
    var msg = xml.getElementsByTagName('msg').item(0).firstChild.data;
    var id = xml.getElementsByTagName('id').item(0).firstChild.data;
    var f = document.getElementById(id);
    var d = document.createElement('div');
    d.setAttribute('class', 'comment');
    d.setAttribute('id', id);
    if (error == 0)
        d.ondblclick = new Function("editComment('" + id + "');");
    d.appendChild(document.createTextNode(msg));
    var z = f.parentNode;
    z.replaceChild(d, f);
    document.addcomment.body.disabled = false;
    document.addcomment.onsubmit = '';
}

document.observe("dom:loaded", function() {
  $$('a.auto img').each( function(item) {
    item.observe('error', broken_image_link);
  });
  $$('img.internal').each( function(item) {
    item.observe('error', broken_image_link);
  });
});

function broken_image_link(e) {
  //this.hide();
  this.insert({
    before: '<span class="error">'+this.readAttribute('src')
          +'<img src="skin/default/icon-error_small.png" alt="[!]" />'
          +'</span>'
  });
  this.hide();
}

document.observe("dom:loaded", function() {
  $$('ul.comment li.no a').each( function(item) {
    item.observe('click', copy_comment_no);
  });
  $$('ul.comment li.body a.comment_no').each( function(item) {
    item.observe('click', focus_comment_no);
  });
});

function copy_comment_no(e) {
  e.stop(); /* prevent default action */

  var cmt_no = this.innerHTML;
  var input = this.up('form').down('ul.comment-form').down('input.text');
  var value = $(input).getValue();
  if (value && value.endsWith(' '))
       { $(input).setValue(value +  "#" + cmt_no + " "); }
  else if (value)
       { $(input).setValue(value + " #" + cmt_no + " "); }
  else { $(input).setValue(value +  "#" + cmt_no + " "); }
  input.focus();
  this.up('form').select('ul.comment').invoke('removeClassName', 'focus');
  this.up('ul').addClassName('focus');
}

function focus_comment_no(e) {
  e.stop(); /* prevent default action */

  var cmt_no = this.innerHTML.substring(1);
  var cmt = $('c'+cmt_no);
  if (cmt) {
    cmt.up('form').select('ul.comment').invoke('removeClassName', 'focus');
    cmt.addClassName('focus'); //.scrollTo();
  }
}

document.observe("dom:loaded", function() {
  if ( $('attach-more') ) $('attach-more').observe('click', add_attach_form);
});

function add_attach_form(e) {
    e.stop(); /* prevent default action */

    var attach_count = $('attach-count').value;
    if (attach_count > 9) return false;
    attach_count++;

    var tr_new = new_attach_form('attach'+attach_count);

    var tr_option = $('attach-option');
    var button = $('attach-more');
    if (attach_count < 1) {
        button.update('Attach a file');
        tr_option.hide();
    } else if (attach_count > 9) {
        button.update('');
    } else {
        button.update('Attach another file');
        tr_option.show();
    }
    tr_option.insert({ before: tr_new });
    
    $('attach-count').writeAttribute('value', attach_count);

    return false;
}

function new_attach_form(name)
{
    var td1 = new Element("td", {'class': "label"});
    td1.insert({bottom: new Element("label", {'for':name}).update(name.capitalize())});

    var td2 = new Element("td");
    td2.insert({bottom: new Element("input", {type:"file", 'class':"file", name:name})});
    td2.insert({bottom: new Element("a",{'class':"button"}).update("x").observe('click',remove_attach_form)});

    return new Element("tr").insert({bottom: td1}).insert({bottom: td2});
}

function remove_attach_form(e) {
    e.stop(); /* prevent default action */

    this.up("tr").remove();
    return false;
}


document.observe("dom:loaded", function() {
  /* _pollset.tmpl */
  var forms = Element.getElementsBySelector(document,"form.poll");
  for (var i = 0; i < forms.length; ++i) forms[i].observe('submit', submit_poll);

  var buttons = Element.getElementsBySelector(document,"a.delete-poll");
  for (var i = 0; i < buttons.length; ++i) buttons[i].observe('click', delete_poll);

  /* _write_form.tmpl, _add_poll.tmpl */
  if ( $('poll-more') ) $('poll-more').observe('click', add_poll_question);
});

function submit_poll(e) {
    e.stop(); /* prevent default action */

    var url = 'poll.cgi';
    var div_id = 'article-'+ this.aid.value +'-poll';
    var oid;
    for (var i = 0; i < this.oid.length; i++) {
        if (this.oid[i].checked) { oid = this.oid[i].value; break; }
    }
    if (! oid) { alert("You should choose one!"); return false; }

    var param = "bid=" + escape(this.bid.value) + 
                ";aid=" + escape(this.aid.value) + 
                ";pid=" + escape(this.pid.value) + 
                ";oid=" + escape(oid) +
                ";mode=ajax";
    var c = new XHConn();
    if (!c) alert("XMLHTTP not available. Try a newer/better browser.");
    c.connect(url, "GET", param, poll_response);
    return false;

    function poll_response(c) {
        $(div_id).update(c.responseText);

        var forms = $(div_id).getElementsBySelector("form.poll");
        for (var i = 0; i < forms.length; ++i) forms[i].observe('submit', submit_poll);

        var buttons = Element.getElementsBySelector(document,"a.delete-poll");
        for (var i = 0; i < buttons.length; ++i) buttons[i].observe('submit', delete_poll);
    }
}

function delete_poll(e) {
    e.stop(); /* prevent default action */
    if (window.confirm('Delete this poll?')) { ; /* continue */ } else { return false; }

    var form = this.up("form");
    var url = 'poll.cgi';
    var div_id = 'article-'+ form.aid.value +'-poll';
    var param = "bid=" + escape(form.bid.value) + 
                ";aid=" + escape(form.aid.value) + 
                ";pid=" + escape(form.pid.value) + 
                ";del=" + escape(1) +
                ";mode=ajax";
    var c = new XHConn();
    if (!c) alert("XMLHTTP not available. Try a newer/better browser.");
    c.connect(url, "GET", param, poll_response);

    function poll_response(c) {
        $(div_id).update(c.responseText);

        var forms = $(div_id).getElementsBySelector("form.poll");
        for (var i = 0; i < forms.length; ++i) forms[i].observe('submit', submit_poll);

        var buttons = Element.getElementsBySelector(document,"a.delete-poll");
        for (var i = 0; i < buttons.length; ++i) buttons[i].observe('click', delete_poll);
    }
}


function add_poll_question() {
    var poll_count = $('poll-count').value;
    if (poll_count > 9) return false;
    poll_count++;

    var tr_new = new_poll_question('poll'+poll_count);

    var tr_option = $('poll-option');
    var button = $('poll-more');
    if (poll_count < 1) {
        button.update('Add a poll question');
        tr_option.hide();
    } else if (poll_count > 9) {
        button.update('');
    } else {
        button.update('Add another poll question');
        tr_option.show();
    }
    tr_option.insert({ before: tr_new });
    
    $('poll-count').writeAttribute('value', poll_count);

    return false;
}

function new_poll_question(name)
{
    var td1 = new Element("td", { 'class': "label" });
    td1.insert({ bottom: '<label for="'+name+'">'+name.capitalize()+'</label>' });
    var td2 = new Element("td");
    td2.insert({ bottom: new Element('input', { type: "text", 'class': "poll", name: name }) });
    td2.insert({ bottom: ' '});
    td2.insert({ bottom: new Element('a',{'class':"button"}).update("x").observe('click',remove_poll_question) });

    var div = new Element("div", { 'class': "poll button" });
    div.insert({ bottom: new Element('a',
       { 'class': "button poll add-option" }).update("Add a poll option").observe('click',add_poll_option) });
    div.insert({ bottom: " &nbsp; " });
    div.insert({ bottom: new Element('a',
       { 'class': "button poll remove-option" }).update("Remove last option").observe('click',remove_poll_option) });

    td2.insert({ bottom: div });

    return new Element("tr").insert({bottom: td1}).insert({bottom: td2});
}

function remove_poll_question(e) {
    this.up("tr").remove();
    return false;
}

function add_poll_option(e) {
    var input = this.up("td").down("input.poll");
    var poll = input.readAttribute("name").substr(4);
    var option = 1 + this.up("td").getElementsBySelector("input.poll.option").length;

    var id = "poll"+poll+"_"+option;
    var opt = new Element("div", { 'class': "poll option" } );
    opt.insert({ bottom: '<label for="'+id+'">Option '+option+'</label>' });
    opt.insert({ bottom: '<input type="text" class="poll option" name="'+id+'" />' });

    this.up("td").insert({ bottom: opt });
    return false;
}

function remove_poll_option(e) {
  try {
    var last_option = this.up("td").getElementsBySelector("div.poll.option").last();
    if (last_option) last_option.remove();
  } catch (e) { return false; }

  return false;
}

document.observe("dom:loaded", function() {
  $$('a.recommender').each( function(item) { item.observe('click', open_board_popup); });
  //$$('a.recom').each( function(item) { item.observe('click', recommend_article); });
});

function open_board_popup(e) {
    e.stop();
    var options = 'toolbar=0,location=0,status=0,menubar=0,scrollbars=1,resizable=1,width=800,height=500';
    var w = window.open(this.readAttribute('href'),this.readAttribute('target'),options);
    if (window.focus) { $(w).activate(); w.focus(); }
}


/* 2010-03-11 NOT IN USE - aragorn */

function tag_article(action, bid, aid, s) {
    var url = action + "2.cgi";
    var param = "bid=" + escape(bid) + ";aid=" + escape(aid) + ";s=" + s;
    var c = new XHConn();
    if (!c) alert("XMLHTTP not available. Try a newer/better browser.");
    c.connect(url, "GET", param, handleHttpResponse);

    function handleHttpResponse(c) {
        var xml = c.responseXML;
        var error = xml.getElementsByTagName('error').item(0).firstChild.data;
        var msg = xml.getElementsByTagName('msg').item(0).firstChild.data;
        var type = xml.getElementsByTagName('type').item(0).firstChild.data;
        var aid = xml.getElementsByTagName('aid').item(0).firstChild.data;
        var id = type + '-' + aid;
        if (error == 0 && type != 'notice') {
            var article = document.getElementById(id);
            var list = document.getElementById(id + "-list");
            var acount = eval(article.innerHTML) + 1;
            var lcount = eval(list.innerHTML) + 1;
            article.innerHTML = acount;
            list.innerHTML = lcount;
        }
        alert(msg);
    }
}

function tagArticle2(action, bid, aid, s) {
    var url = action + "2.cgi";
    var param = "bid=" + escape(bid) + "&aid=" + escape(aid) + "&s=" + s;
    var c = new XHConn();
    if (!c) alert("XMLHTTP not available. Try a newer/better browser.");
    c.connect(url, "GET", param, handleHttpResponse2);
}

function XHConn() {
  var xmlhttp, bComplete = false;
  try { xmlhttp = new ActiveXObject("Msxml2.XMLHTTP"); }
  catch (e) { try { xmlhttp = new ActiveXObject("Microsoft.XMLHTTP"); }
  catch (e) { try { xmlhttp = new XMLHttpRequest(); }
  catch (e) { xmlhttp = false; }}}
  if (!xmlhttp) return null;
  this.connect = function(sURL, sMethod, sVars, fnDone)
  {
    if (!xmlhttp) return false;
    bComplete = false;
    sMethod = sMethod.toUpperCase();

    try {
      if (sMethod == "GET")
      {
        xmlhttp.open(sMethod, sURL+"?"+sVars, true);
        sVars = "";
      }
      else
      {
        xmlhttp.open(sMethod, sURL, true);
        xmlhttp.setRequestHeader("Method", "POST "+sURL+" HTTP/1.1");
        xmlhttp.setRequestHeader("Content-Type",
          "application/x-www-form-urlencoded; charset=UTF-8");
      }
      xmlhttp.onreadystatechange = function(){
        if (xmlhttp.readyState == 4 && !bComplete)
        {
          bComplete = true;
          fnDone(xmlhttp);
        }};
      xmlhttp.send(sVars);
    }
    catch(z) { return false; }
    return true;
  };
  return this;
}
