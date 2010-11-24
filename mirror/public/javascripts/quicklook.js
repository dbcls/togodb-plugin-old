function htmldecode(str) {
    str=str.replace(/&quot;/ig,"\"");
    str=str.replace(/&apos;/ig,"'");
    str=str.replace(/&gt;/ig,">");
    str=str.replace(/&lt;/ig,"<");
    str=str.replace(/&amp;/ig,"&");
    return str;
}

function changeHTMLb(iframeid, html) {
    var doc12 = "";
    if (document.all) {
        // IE
        doc12 = frames[iframeid].document;
    } else {
        // Mozilla
        doc12 = document.getElementById(iframeid).contentDocument;
    }
    // インラインフレームのドキュメントでエレメント作成
    var container = doc12.createElement("div");
    doc12.body.innerHTML="";
    container.innerHTML = htmldecode(html);
    // インラインフレーム内に追加
    doc12.body.appendChild(container);

    stylePopup('popupdiv');
    ShowSize("popupdiv",100,100);
    ShowSize("popup",100,115);
}

function changeHTML(id, html) {
    var doc12 = "";
    if (document.all) {
        // IE
        doc12 = document.all(id);
    } else {
        // Mozilla
        doc12 =document.getElementById(id);
    }
    doc12.innerHTML = htmldecode(html);

    stylePopup('popupdiv');
    ShowSize("popupdiv",100,100);
    ShowSize("popup",100,115);
}

function stylePopup(id) {
    if (document.all) {
        var dom_id=document.all(id);
        //var irx = Mdx+ind_x+x;

    } else {
        var dom_id =document.getElementById(id);
    }
    //dom_id.style.position="fixed";
    dom_id.style.display="block";
    dom_id.style.zIndex=200;
}

function closepopup(id) {
    if(document.all){
        var dom_id=document.all(id);
        //var irx = Mdx+ind_x+x;

    }else{
        var dom_id =document.getElementById(id);
    }
    //dom_id.style.position="absolute";
    dom_id.style.display="none";
    dom_id.style.zIndex=-100;
}

function ShowSize(id,xdown,ydown) {
    var ua = navigator.userAgent;       // ユーザーエージェント
    var nWidth, nHeight;                // サイズ
    var nHit = ua.indexOf("MSIE");      // 合致した部分の先頭文字の添え字
    var bIE = (nHit >=  0);             // IE かどうか
    var bVer6 = (bIE && ua.substr(nHit+5, 1) == "6");  // バージョンが 6 かどうか
    var bStd = (document.compatMode && document.compatMode=="CSS1Compat");
    // 標準モードかどうか
    if (bIE) {
        var dom_id=document.all(id);
        if (bVer6 && bStd) {
            nWidth = document.documentElement.clientWidth;
            nHeight = document.documentElement.clientHeight;
        } else {
            nWidth = document.body.clientWidth;
            nHeight = document.body.clientHeight;
        }
    } else {
        var dom_id =document.getElementById(id);
        nWidth = window.innerWidth;
        nHeight = window.innerHeight;
    }
    dom_id.style.height=nHeight-ydown+"px";
    dom_id.style.width=nWidth-xdown+"px";
}

function toabsolute(id) {
    if (document.all) {
        var dom_id=document.all(id);
        //var irx = Mdx+ind_x+x;
    } else {
        var dom_id =document.getElementById(id);
    }
    dom_id.style.position="absolute";
}

function tofixed(id) {
    if (document.all) {
        var dom_id=document.all(id);
        //var irx = Mdx+ind_x+x;

    } else {
        var dom_id =document.getElementById(id);
    }
    dom_id.style.position="absolute";
}
