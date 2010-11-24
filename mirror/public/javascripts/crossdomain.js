function crossdomain(){
	this.id = crossdomain._lastId++;
}

crossdomain._loaded = false;
crossdomain._lastId = 0;
crossdomain._instanceMap = new Object;
crossdomain.request = function(url,completeHandler){
	var fp = new crossdomain;
	fp.addEventListener("complete",completeHandler);
	fp.request(url);
}

crossdomain.requestPost = function(url,post,completeHandler){
	var fp = new crossdomain;
	fp.addEventListener("complete",completeHandler);
	fp.post = post;
	fp.request(url);
}

crossdomain.prototype = {
	addEventListener : function(type, handler){
		if(!this.listeners){
			this.listeners = new Object;
		}
		if(!this.listeners[type])
			this.listeners[type] = new Array;
		var ary = this.listeners[type];
		ary[ary.length] = handler;
	},

	dispatchEvent : function(flexEvent, obj){
		var ary = this.listeners[flexEvent.type];
		for(var i=0;i<ary.length;i++){
			ary[i](flexEvent, obj);
		}
	},

	request : function(url, contentType, post, headers, recurseLimit){
		crossdomain._instanceMap[this.id] = this;
		getFlashObjByName("crossdomain_external").request(
			this.id,url,this.contentType,this.post,this.headers,this.recurseLimit);
	}
}

function crossdomain_onload(){
	if(crossdomain.onload)
		crossdomain.onload();
}

function crossdomain_call(id,obj){
	var fp = crossdomain._instanceMap[id];
	if(fp){
		fp.dispatchEvent(obj.event, obj);
	}
}

function getFlashObjByName(n) {
    if (window.ActiveXObject) {
        return window[n];
    } else {
        return document[n];
    }
}

var isIE  = (navigator.appVersion.indexOf("MSIE") != -1) ? true : false;
var isWin = (navigator.appVersion.toLowerCase().indexOf("win") != -1) ? true : false;
var isOpera = (navigator.userAgent.indexOf("Opera") != -1) ? true : false;

function ControlVersion()
{
	var version;
	var axo;
	var e;
	try {
		axo = new ActiveXObject("ShockwaveFlash.ShockwaveFlash.7");
		version = axo.GetVariable("$version");
	} catch (e) {
	}

	if (!version)
	{
		try {
			axo = new ActiveXObject("ShockwaveFlash.ShockwaveFlash.6");
			version = "WIN 6,0,21,0";
			axo.AllowScriptAccess = "always";
			version = axo.GetVariable("$version");

		} catch (e) {
		}
	}

	if (!version)
	{
		try {
			axo = new ActiveXObject("ShockwaveFlash.ShockwaveFlash.3");
			version = axo.GetVariable("$version");
		} catch (e) {
		}
	}

	if (!version)
	{
		try {
			axo = new ActiveXObject("ShockwaveFlash.ShockwaveFlash.3");
			version = "WIN 3,0,18,0";
		} catch (e) {
		}
	}

	if (!version)
	{
		try {
			axo = new ActiveXObject("ShockwaveFlash.ShockwaveFlash");
			version = "WIN 2,0,0,11";
		} catch (e) {
			version = -1;
		}
	}

	return version;
}

function GetSwfVer(){
	var flashVer = -1;

	if (navigator.plugins != null && navigator.plugins.length > 0) {
		if (navigator.plugins["Shockwave Flash 2.0"] || navigator.plugins["Shockwave Flash"]) {
			var swVer2 = navigator.plugins["Shockwave Flash 2.0"] ? " 2.0" : "";
			var flashDescription = navigator.plugins["Shockwave Flash" + swVer2].description;
			var descArray = flashDescription.split(" ");
			var tempArrayMajor = descArray[2].split(".");
			var versionMajor = tempArrayMajor[0];
			var versionMinor = tempArrayMajor[1];
			if ( descArray[3] != "" ) {
				tempArrayMinor = descArray[3].split("r");
			} else {
				tempArrayMinor = descArray[4].split("r");
			}
			var versionRevision = tempArrayMinor[1] > 0 ? tempArrayMinor[1] : 0;
			var flashVer = versionMajor + "." + versionMinor + "." + versionRevision;
		}
	}

	else if (navigator.userAgent.toLowerCase().indexOf("webtv/2.6") != -1) flashVer = 4;
	else if (navigator.userAgent.toLowerCase().indexOf("webtv/2.5") != -1) flashVer = 3;
	else if (navigator.userAgent.toLowerCase().indexOf("webtv") != -1) flashVer = 2;
	else if ( isIE && isWin && !isOpera ) {
		flashVer = ControlVersion();
	}
	return flashVer;
}

function DetectFlashVer(reqMajorVer, reqMinorVer, reqRevision)
{
	versionStr = GetSwfVer();
	if (versionStr == -1 ) {
		return false;
	} else if (versionStr != 0) {
		if(isIE && isWin && !isOpera) {
			tempArray         = versionStr.split(" ");
			tempString        = tempArray[1];
			versionArray      = tempString.split(",");
		} else {
			versionArray      = versionStr.split(".");
		}
		var versionMajor      = versionArray[0];
		var versionMinor      = versionArray[1];
		var versionRevision   = versionArray[2];
		if (versionMajor > parseFloat(reqMajorVer)) {
			return true;
		} else if (versionMajor == parseFloat(reqMajorVer)) {
			if (versionMinor > parseFloat(reqMinorVer))
				return true;
			else if (versionMinor == parseFloat(reqMinorVer)) {
				if (versionRevision >= parseFloat(reqRevision))
					return true;
			}
		}
		return false;
	}
}

function getFlashTag(src, id){
    var flashTag = new String();
    if (window.ActiveXObject){
        flashTag += '<object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" ';
        flashTag += 'codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab" ';
        flashTag += 'width="1" ';
        flashTag += 'height="1" ';
		flashTag += 'id="'+id+'" ';
		flashTag += 'name="'+id+'">';
        flashTag += '<param name="movie" value="'+src+'"/>';
        flashTag += '<param name="quality" value="high"/>';
        flashTag += '<param name="wmode" value="transparent"/>';
        flashTag += '<param name="bgcolor" value="#FFFFFF"/>';
        flashTag += '</object>';
    }else{
        flashTag += '<embed src="'+src+'"';
        flashTag += 'name="'+id+'" ';
        flashTag += 'quality="high" ';
        flashTag += 'bgcolor="#FFFFFF" ';
        flashTag += 'width="1" ';
        flashTag += 'height="1" ';
        flashTag += 'wmode="transparent" ';
        flashTag += 'swliveconnect="TRUE" ';
        flashTag += 'type="application/x-shockwave-flash" ';
        flashTag += 'pluginspage="http://www.macromedia.com/go/getflashplayer">';
        flashTag += '</embed>';
    }
	return flashTag;
}


var requiredMajorVersion = 9;
var requiredMinorVersion = 0;
var requiredRevision = 28;

crossdomain.open = function(){
	var hasRequestedVersion = DetectFlashVer(requiredMajorVersion, requiredMinorVersion, requiredRevision);
	if (hasRequestedVersion) {
		document.write(getFlashTag("/swfs/crossdomain.swf", "crossdomain_external"));
	}else{
		crossdomain.onnoflash();
	}
}
