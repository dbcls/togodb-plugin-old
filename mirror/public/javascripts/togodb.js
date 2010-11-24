
var Togodb = {}
Togodb.ListViewer = Class.create();

/*--------------------------------------------------------------------------*/
// Togodb.ListViewer.Popup
/*--------------------------------------------------------------------------*/

Togodb.ListViewer.Popup = Class.create();
Togodb.ListViewer.Popup.prototype = {
  initialize: function(viewer) {
    this.viewer = viewer;
    this.active = false;
  },

  element_id_for: function(object) {
    return object.id || object;
  },

  create: function(dom_id) {
    if (!$(dom_id)) return;
      changeHTML("popup",dom_id.innerHTML);
      //    RedBox.showInline(dom_id);
  },

  update: function(dom_id) {
    if (!this.active) return;
    if (!$(dom_id)) return;
    // hide previous element
    //    var content = $(dom_id).cloneNode(true);
    //    var modal  = $('RB_window');
    //    content.style['display'] = 'block';
    //    if (modal.firstChild) modal.removeChild(modal.firstChild);
    //      modal.appendChild(content);
    //    RedBox.setWindowPosition();
    changeHTML("popup",dom_id.innerHTML);
    this.active = true;
  },

  close: function(dom_id) {
    //    RedBox.close();
    closepopup('popupdiv');
    this.active = false;
  },

  open: function(element) {
    if (this.active) {
      this.update(element);
    } else {
      this.create(element);
    }
  },

  toggle: function(element) {
    if (!element) return;
    if (this.active) {
      this.close(element);
      this.active = false;
    } else {
      this.open(element);
      this.active = true;
    }
  }

}


/*--------------------------------------------------------------------------*/
// Togodb.ListViewer
/*--------------------------------------------------------------------------*/

Togodb.ListViewer.prototype = {
  initialize: function(options) {
    options = options || {};
    this.options = options

    // styles
    this.style = {};
    this.style.item    = options.item_class_name    || 'item';
    this.style.current = options.current_class_name || 'current';
    this.style.preview = options.preview_class_name || 'preview';
    this.style.next_page = options.next_page_class_name     || 'next';
    this.style.prev_page = options.previous_page_class_name || 'previous';

    // instance variables
    this.root     = options.root; // items を探す時のTOPノード (パフォーマンス用)
    this.position = 0;            // カーソルがある位置 (0,1,2,..,-1)
    this.active   = false;        // カーソル表示中かどうか
    this.overflow = false;        // ページ移動状態かどうか
    this.changed  = false;        // カーソルが移動したかどうか (内部用)
    this.popuper  = new Togodb.ListViewer.Popup(this);

    // key binds
    this.keybinds = this.generate_keybinds_from(options);

    // cache
    this.cache = {};
  },

  // --------------------------------------------------------------------------
  // private methods
  // --------------------------------------------------------------------------
  generate_keybinds_from: function(options) {
    var hash = {};
    ['prev', 'next', 'toggle', 'close'].each(function(action) {
      code = options[action];
      switch (typeof(code)) {
      case 'undefined':
        break;
      case 'number':
        hash[code] = action;
        break;
      case 'object':
        if (code.constructor == Array) {
          code.each(function(c){hash[c] = action});
        } else {
          throw 'Keybind Error (' + action + '): expected number/Array but got ' + code.constructor;
        }
        break;
      default:
        throw 'Keybind Error (' + action + '): expected number/Array but got ' + typeof(code);
      }
    });
    return hash;
  },

  // --------------------------------------------------------------------------
  // public methods
  // --------------------------------------------------------------------------
  keyevent_handler: function(caller) {
    viewer = this;
    keybinds = this.keybinds;
    return function(event){
      element = event.srcElement || event.target
      if (element.form) return true;
      var action = keybinds[event.keyCode];
      if (action)
        viewer[action]();
      return true;
    }.bind(caller);
  },

  // --------------------------------------------------------------------------
  // accessor methods
  // --------------------------------------------------------------------------
  first_of: function(className, top) {
    return document.getElementsByClassName(className, top);
  },

  styled: function(name, top) {
    if (top) {
      return document.getElementsByClassName(this.style[name], top)[this.position];
    }
    else {
      return document.getElementsByClassName(this.style[name])[0];
    }
  },

  items: function() {
    if (!this.cache.items) {
      this.cache.items = document.getElementsByClassName(this.style.item, this.root) || [];
    }
    return this.cache.items;
  },

  link_to_next_page: function() {
    return this.styled('next_page');
  },

  link_to_prev_page: function() {
    return this.styled('prev_page');
  },

  at: function(index) {
    return this.items()[index];
  },

  current: function() {
    return this.at(this.position);
  },

  pointed: function() {
    return this.styled('preview', this.current());
  },

  // --------------------------------------------------------------------------
  // events
  // --------------------------------------------------------------------------
  next_page: function() {
    var link = this.link_to_next_page();
    if (link) {
      Element.removeClassName(this.current(), this.style.current);
      link.onclick();
      this.position = 0;
      this.overflow = true;
      this.changed  = true;
    }
  },

  prev_page: function() {
    var link = this.link_to_prev_page();
    if (link) {
      Element.removeClassName(this.current(), this.style.current);
      link.onclick();
      this.position = -1;
      this.overflow = true;
      this.changed  = true;
    }
  },

  move_to: function(index) {
    if (!this.active) {
      index = 0;
      this.active = true;
    }

    if (index < 0) return this.prev_page();
    if (index >= this.items().length) return this.next_page();

    Element.removeClassName(this.current(), this.style.current);
    this.position = index;
    this.overflow = false;
    this.changed  = true;
    Element.addClassName(this.current(), this.style.current);
  },

  construct: function() {
    this.cache = {};
  },

  overflowed_position: function() {
    var index = this.position;
    if (index == -1) index = this.items().length - 1;
    if (index == -1) index = 0;
    return index;
  },

  prev: function() {
    this.construct();
    this.move_to( this.overflow ? this.overflowed_position() : this.position - 1);
    this.update();
  },

  next: function() {
    this.construct();
    this.move_to( this.overflow ? this.overflowed_position() : this.position + 1);
    this.update();
  },

  update: function() {
    if (this.active && this.changed) {
      this.update_real();
      this.changed = false;
    }
  },

  update_real: function() {
    this.popuper.update(this.pointed());
  },

  popup: function(id) {
    this.construct();
    this.popuper.open(id);
    this.update();
  },

  close: function() {
    this.popuper.close();
  },

  toggle: function() {
    this.construct();
    this.popuper.toggle(this.pointed());
    this.changed = true;
    this.update();
  },

  // --------------------------------------------------------------------------
  // debug
  // --------------------------------------------------------------------------
  inspect: function() {
    alert('position:"' + this.position + '", items.length:"'+this.items().length + '", dom_id:"' + this.current().id + '"');
  }
}

function set_sort_order(sort_column, sort_direction) {
  document.forms['sort_order'].column.value = sort_column;
  document.forms['sort_order'].direction.value = sort_direction;
}

function copy_sort_order(search_type) {
  document.forms[search_type].sort_column.value = document.forms['sort_order'].column.value;
  document.forms[search_type].sort_direction.value = document.forms['sort_order'].direction.value;
}

var num_new_taxonomies = 1;
var num_new_literatures = 1;
function addMetadataForm(id, form_elem_name) {
  var parts = '';
  var elem = $(id);
  if (id == 'database_classes') {
    parts = getMetadataDBClassForm();
  }
  else if (id == 'taxonomies') {
      name_elem_id = "new_taxonomy[" + num_new_taxonomies + "][taxonomy_name]";
      id_elem_id = "new_taxonomy[" + num_new_taxonomies + "][taxonomy_id]";

    parts =  '    Taxonomy Name: <input type="text" id="' + name_elem_id + '" name="' + name_elem_id + '" size="20" />';
    parts += '    Taxonomy ID: <input type="text" id="' + id_elem_id + '" name="' + id_elem_id + '" size="10" />';
    parts += " <a onclick=\"new Ajax.Request('/togodb/load_taxonomy', {asynchronous:true, evalScripts:true, onComplete:function(request){tx = eval( '(' + request.responseText + ')' ); $('new_taxonomy[" + num_new_taxonomies + "][taxonomy_name]').value = tx['taxonomy_name']}, parameters:Form.Element.serialize('new_taxonomy[" + num_new_taxonomies + "][taxonomy_id]')}); return false;\" href=\"#\">auto complete</a>";
    parts += '<br />';
    num_new_taxonomies++;
  }
  else if (id == 'literatures') {
      title_elem_id = "new_literature[" + num_new_literatures + "][title]";
      author_elem_id = "new_literature[" + num_new_literatures + "][author]";
      journal_elem_id = "new_literature[" + num_new_literatures + "][journal]";
      pubmed_id_elem_id = "new_literature[" + num_new_literatures + "][pubmed_id]";

    parts =  '<table border="0">';
    parts += '<tr>';
    parts += '<th class="literature_item">文献名</th>';
    parts += '<td align="left"><textarea id="' + title_elem_id + '" name="' + title_elem_id + '" rows="2" cols="60"></textarea></td>';
    parts += '</tr>';
    parts += '<tr>';
    parts += '<th class="literature_item">著者名</th>';
    parts += '<td align="left"><textarea id="' + author_elem_id + '" name="' + author_elem_id + '" rows="2" cols="60"></textarea></td>';
    parts += '</tr>';
    parts += '<tr>';
    parts += '<th class="literature_item">雑誌名／掲載年月／号</th>';
    parts += '<td align="left"><input type="text" id="' + journal_elem_id + '" name="' + journal_elem_id + '" size="50" /></td>';
    parts += '</tr>';
    parts += '<tr>';
    parts += '<th class="literature_item">Pubmed ID</th>';
    parts += '<td align="left"><input type="text" id="' + pubmed_id_elem_id + '" name="' + pubmed_id_elem_id + '" size="20" />';
    parts += " <a onclick=\"new Ajax.Request('/togodb/load_pubmed', {asynchronous:true, evalScripts:true, parameters:Form.Element.serialize('" + pubmed_id_elem_id + "')}); return false;\" href=\"#\">auto complete</a></td>";
    parts += '</tr>';
    parts += '</table>';
    num_new_literatures++;
  }
  else {
    parts += '<input type="text" name="' + form_elem_name + '" size="80" />';
    parts += '<br />';
  }
  elem.innerHTML += parts;
}

function getMetadataDBClassForm() {
  var items = Array('',
		    '塩基配列データベース',
		    '塩基配列データベース-国際塩基配列データベース連携',
		    '塩基配列データベース-コーディング/ノンコーディング領域DNA',
		    '塩基配列データベース-遺伝子構造、イントロン/エクソン、スプライス部位',
		    '塩基配列データベース-転写調節部位、転写因子',
		    'RNA配列データベース',
		    'タンパク質配列データベース',
		    'タンパク質配列データベース-配列データベース全般',
		    'タンパク質配列データベース-タンパク質属性',
		    'タンパク質配列データベース-タンパク質局在、標的タンパク質',
		    'タンパク質配列データベース-タンパク質配列モチーフ、タンパク質活性部位',
		    'タンパク質配列データベース-タンパク質ドメインデータベース、タンパク質分類',
		    'タンパク質配列データベース-タンパク質ファミリー別データベース',
		    '構造データベース',
		    '構造データベース-低分子',
		    '構造データベース-炭水化物(Carbohydrates)',
		    '構造データベース-核酸構造',
		    '構造データベース-タンパク質構造',
		    'ゲノムデータベース（無脊椎動物）',
		    'ゲノムデータベース（無脊椎動物）-ゲノムアノテーション用語、オントロジー',
		    'ゲノムデータベース（無脊椎動物）-生物分類/同定',
		    'ゲノムデータベース（無脊椎動物）-ゲノムデータベース全般',
		    'ゲノムデータベース（無脊椎動物）-ウィルスゲノムデータベース',
		    'ゲノムデータベース（無脊椎動物）-原核生物ゲノムデータベース',
		    'ゲノムデータベース（無脊椎動物）-単細胞真核生物ゲノムデータベース',
		    'ゲノムデータベース（無脊椎動物）-真菌ゲノムデータベース',
		    'ゲノムデータベース（無脊椎動物）-無脊椎動物ゲノムデータベース',
		    '代謝系/シグナル伝達系パスウェイ',
		    '代謝系/シグナル伝達系パスウェイ-酵素、酵素関連用語',
		    '代謝系/シグナル伝達系パスウェイ-代謝系パスウェイ',
		    '代謝系/シグナル伝達系パスウェイ-タンパク質相互作用',
		    '代謝系/シグナル伝達系パスウェイ-シグナル伝達系パスウェイ',
		    'ヒト/その他の脊椎動物ゲノム',
		    'ヒト/その他の脊椎動物ゲノム-モデル生物、比較ゲノム',
		    'ヒト/その他の脊椎動物ゲノム-ヒトゲノムデータベース/マップ/ビューワ',
		    'ヒト/その他の脊椎動物ゲノム-ヒトORF',
		    'ヒト遺伝子/疾患',
		    'ヒト遺伝子/疾患-ヒト遺伝子データベース全般',
		    'ヒト遺伝子/疾患-多型データベース全般',
		    'ヒト遺伝子/疾患-ガン遺伝子データベース',
		    'ヒト遺伝子/疾患-特定の遺伝子/生体システム/疾患に関するデータベース',
		    'マイクロアレイデータ、その他の発現データのデータベース',
		    'プロテオーム試料',
		    'その他の分子生物学データベース',
		    'その他の分子生物学データベース-薬品、ドラッグデザイン',
		    'その他の分子生物学データベース-分子プローブ、プライマー',
		    '器官データベース',
		    '器官データベース-ミトコンドリア遺伝子/タンパク質',
		    '植物データベース',
		    '植物データベース-植物データベース全般',
		    '植物データベース-シロイヌナズナ',
		    '植物データベース-イネ',
		    '植物データベース-その他の植物',
		    '免疫学データベース',
		    'その他（自由記述）');

  var select_html =  '<select name="new_dbclasses[]">';
  for (var i = 0; i < items.length; i++) {
	select_html += '<option value="' + i + '">' + items[i] + '</option>';
  }
  select_html += '</select><br />';
  select_html += '<input type="text" name="new_dbclass_names[]" size="80" /><br />';

  return select_html;
}
