<?php
/**
 * Solmetra Uploader v1.0 main class
 * 
 * @package uploader
 * @author Martynas Majeris <martynas@solmetra.com> 
 * @copyright UAB Solmetra   
 */

// define class
class SolmetraUploader {
  // {{{
  var $instances  = array();
  var $settings   = array();
  var $br         = "\r\n";
  var $maxsize    = null;
  // }}}
  // {{{
  function SolmetraUploader ($baseurl = false, $uploadurl = false, $config = false) {
    // load settings
    $configFile = $config === false ? dirname(__FILE__).'/config.php' : $config;
    if (!@include $configFile) {
      die('Flash Uploader critical error: unable to load config file at: '.$configFile);
    }
    
    // set baseurl
    if ($baseurl !== false) {
      $this->setSetting('baseurl', $baseurl);
    }
    
    // calculate basedir automatically if it's not set
    // NOT IMPLEMENTED YET!!!
    // NOT IMPLEMENTED YET!!!
    // NOT IMPLEMENTED YET!!!
    // NOT IMPLEMENTED YET!!!
    
    // set upload url
    if ($baseurl !== false) {
      $this->setSetting('uploadurl', $uploadurl);
    }
    else {
      $this->setSetting('uploadurl', 'upload.php');
    }
    
    // lowecase all settings
    $newsettings = array();
    while (list($key, $val) = each($this->settings)) {
      $newsettings[strtolower($key)] = $val;
    }
    $this->settings = $newsettings;
    
    $this->setSetting('uploaddir', $this->__normalizeDir($this->getSetting('uploaddir')));
    $this->setSetting('tmpdir', $this->__normalizeDir($this->getSetting('tmpdir')));
    
    // check PHP max size
    $max = strtoupper(ini_get('upload_max_filesize'));
    if (substr($max, -1) == 'M') {
      $max = str_replace('M', '', $max) * 1048576;
    }
    elseif (substr($max, -1) == 'K') {
      $max = str_replace('K', '', $max) * 1024;
    }
    
    if ($max > 0) {
      $this->maxsize = $max;
    }
    
    // run garbage collector
    $this->__runGC();
  }
  // }}}
  // {{{
  function setSerial ($ser) {
    $this->setSetting('serial', $ser);
  }
  // }}}
  // {{{
  function setDemo ($size) {
    $this->setSetting('demo', $size);
  }
  // }}}
  // {{{
  function setSetting ($key, $val) {
    $this->settings[strtolower($key)] = $val;
  }
  // }}}
  // {{{
  function getSetting ($key, $alternative = false) {
    return isset($this->settings[strtolower($key)]) ? $this->settings[strtolower($key)] : $alternative;
  }
  // }}}
  // {{{
  function getInstance ($fieldName, 
                        $width = null, 
                        $height = null, 
                        $required = null, 
                        $hijackForm = null,
                        $configUrl = null,
                        $embedConfig = null, 
                        $language = null, 
                        $bgColor = null)
  {
    // set defaults
    $width          = $width === null           ? $this->getSetting('width')          : $width;
    $height         = $height === null          ? $this->getSetting('height')         : $height;
    $required       = $required === null        ? $this->getSetting('required')       : $required;
    $hijackForm     = $hijackForm === null      ? $this->getSetting('hijackForm')     : $hijackForm;
    $configUrl      = $configUrl === null       ? $this->getSetting('configUrl')      : $configUrl;
    $embedConfig    = $embedConfig === null     ? $this->getSetting('embedConfig')    : $embedConfig;
    $language       = $language === null        ? $this->getSetting('language')       : $language;
    $bgColor        = $bgColor === null         ? $this->getSetting('bgColor')        : $bgColor;
    
    // generate instance id
    do {
      $instance = md5(microtime());
    } while (in_array($instance, $this->instances));
    $this->instances[] = $instance;
    
    // create a token for secure uploads
    if ($this->getSetting('secureUploads')) {
      $this->__createToken($instance);
    }
    
    // innitialize return value
    $html = '';
    
    // start the placeholder
    $html = '<div id="solmetraUploaderPlaceholder_'.$instance.'">'.$this->br;
    
    // set Uploader config variables
    $vars = array(
      'baseurl'       => $this->getSetting('baseUrl'),
      'uploadurl'     => $this->getSetting('uploadUrl'),
      'language'      => $language,
      'config'        => $configUrl,
      'instance'      => $instance,
      'allowed'       => implode(',', $this->getSetting('allowedExtensions')),
      'disallowed'    => implode(',', $this->getSetting('disallowedExtensions')),
      'verifyupload'  => $this->getSetting('verifyupload') ? 'true' : 'false'
    );
    
    // set serial
    if ($this->getSetting('serial')) {
      $vars['serial'] = $this->getSetting('serial');
    }
    
    // set demo mode
    if ($this->getSetting('demo')) {
      $vars['demo'] = $this->getSetting('demo');
    }
    
    // embed config
    if ($embedConfig) {
      if ($xml = @file_get_contents($configUrl, FILE_TEXT)) {
        $vars['configXml'] = preg_replace('/(^[^<]*)|(<!--[^>]*-->)|([\s]{2,})/is', '', $xml);
        $vars['configXml'] = preg_replace('/(^[^<]*)|([\s]{2,})/is', '', $vars['configXml']);
        $vars['configXml'] = str_replace('%', '%25', $vars['configXml']);
      }
      else {
        return "<div class=\"solmetraError\">Unable to load file '$configUrl'</div>";
      }
      unset($vars['config']);
    }
    
    // add max size if aplicable
    if ($this->maxsize > 0) {
      $vars['maxsize'] = $this->maxsize;
    }
    
    // add hijack variable
    if ($hijackForm) {
      $vars['hijackForm'] = 'yes';
      $vars['externalErrorHandler'] = $this->getSetting('externalErrorHandler', 'SolmetraUploader.broadcastError');
      $vars['externalEventHandler'] = $this->getSetting('externalEventHandler', 'SolmetraUploader.broadcastEvent');
    }
    
    // generate url to flash movie
    $flashurl = $this->__getUrl($this->getSetting('baseUrl'), 'uploader.swf');
    
    // add fallback mechanism
    if ($this->getSetting('useFileTag') === true) {
      // use file input tag
      
      // generate file tag params
      $params = $this->getSetting('fileTagParams');
      $params_txt = '';
      if (is_array($params)) {
        while (list($key, $val) = each($params)) {
          if ($key != 'configXml') {
            $params_txt .= ' '.$this->__escape($key).'="'.$this->__escape($val).'"';
          }
        }
      }
      
      // add file tag
      $html .= '<input type="file" name="'.$fieldName.'"'.$params_txt.' />'.$this->br;
    }
    else {
      // use traditional fallback mechanism
      $param_str = '';
      reset($vars);
      while (list($key, $val) = each($vars)) {
        if ($param_str != '') {
          $param_str .= '&';
        }
        $param_str .= $key.'='.urlencode($val);
      }
      $html .= '<script type="text/javascript">'.$this->br.
               '<!--'.$this->br.
               'document.write(\'<object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=8,0,0,0" width="400" height="100" id="solmetraUploader_'.$instance.'" align="middle">\');'.$this->br.
               'document.write(\'<param name="allowScriptAccess" value="always" />\');'.$this->br.
               'document.write(\'<param name="allowFullScreen" value="false" />\');'.$this->br.
               'document.write(\'<param name="movie" value="'.$flashurl.'?'.$param_str.'" /><param name="quality" value="high" /><param name="bgcolor" value="#ffffff" />	<embed src="'.$flashurl.'?='.$param_str.'" quality="high" bgcolor="#ffffff" width="400" height="100" name="solmetraUploader_'.$instance.'" align="middle" allowScriptAccess="always" allowFullScreen="false" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer" />\');'.$this->br.
               'document.write(\'</object>\');'.$this->br.
               '//-->'.$this->br.
               '</script>'.$this->br.
               '<noscript>'.$this->br.
               '<object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=8,0,0,0" width="400" height="100" id="solmetraUploader_'.$instance.'" align="middle">'.$this->br.
               '<param name="allowScriptAccess" value="always" />'.$this->br.
               '<param name="allowFullScreen" value="false" />'.$this->br.
               '<param name="movie" value="'.$flashurl.'?='.$param_str.'" /><param name="quality" value="high" /><param name="bgcolor" value="#ffffff" />	<embed src="'.$flashurl.'?='.$param_str.'" quality="high" bgcolor="#ffffff" width="400" height="100" name="solmetraUploader_'.$instance.'" align="middle" allowScriptAccess="always" allowFullScreen="false" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer" />'.$this->br.
               '</object>'.$this->br.
               '</noscript>'.$this->br;
    }
    
    // close the placeholder
    $html .= '</div>'.$this->br;
    
    // add instance tag
    $html .= '<input type="hidden" name="solmetraUploaderInstance" value="'.$instance.'" />'.$this->br;
    
    // add data field
    $html .= '<input type="hidden" id="solmetraUploaderData_'.$instance.'" name="solmetraUploaderData['.$instance.']" value="'.$fieldName.'" />'.$this->br;
    
    // add hijack field
    if ($hijackForm) {
      $html .= '<input type="hidden" id="solmetraUploaderHijack_'.$instance.'" value="y" />'.$this->br;
    }
    else {
      $html .= '<input type="hidden" id="solmetraUploaderHijack_'.$instance.'" value="n" />'.$this->br;
    }
    
    // add required field
    if ($required) {
      $html .= '<input type="hidden" id="solmetraUploaderRequired_'.$instance.'" value="y" />'.$this->br;
    }
    else {
      $html .= '<input type="hidden" id="solmetraUploaderRequired_'.$instance.'" value="n" />'.$this->br;
    }
    
    // draw main object
    $html .= '<script type="text/javascript">'.$this->br.
             '<!--'.$this->br.
             '  var so = new SWFObject("'.$flashurl.'", "solmetraUploaderMovie_'.$instance.'", "'.$width.'", "'.$height.'", "8", "'.$bgColor.'");'.$this->br.
             '  so.useExpressInstall("expressinstall.swf");'.$this->br.
             '  so.addParam("allowScriptAccess", "always");'.$this->br.
             '  so.addParam("allowFullScreen", "false");'.$this->br;
    
    // add parameters
    reset($vars);
    while (list($key, $val) = each($vars)) {
      $html .= '  so.addVariable("'.$key.'", "'.$this->__escape($val, $key == 'configXml').'");'.$this->br;
    }
    
    // finish object
    $html .= '  so.write("solmetraUploaderPlaceholder_'.$instance.'");'.$this->br;
    
    // add fix for IE form ExternalInterface bug
    $html .= '  solmetraUploaderMovie_'.$instance.' = document.getElementById(\'solmetraUploaderMovie_'.$instance.'\');'.$this->br;
    
    // finish object
    $html .= '//-->'.$this->br;
    $html .= '</script>';
    
    return $html;
  }
  // }}}
  // {{{
  function getUploadedFiles () {
    // get uploaded files
    $files = $this->__get('solmetraUploaderData');
    
    // populate
    $dir = $this->getSetting('uploaddir');
    $return = array();
    if (is_array($files)) {
      while (list($instance, $file) = each($files)) {
        $data = explode('|', $file);
        if (sizeof($data) == 3) {
          if (file_exists($dir.$data[1]) || !@filesize($dir.$data[1])) {
            $return[$data[0]] = array(
              'name'      => $data[2],
              'type'      => 'application/octet-stream',
              'size'      => @filesize($dir.$data[1]),
              'tmp_name'  => $dir.$data[1],
              'error'     => UPLOAD_ERR_OK
            );
          }
          else {
            $return[$data[0]] = array(
              'name'      => $data[2],
              'type'      => 'application/octet-stream',
              'size'      => 0,
              'tmp_name'  => $dir.$data[1],
              'error'     => UPLOAD_ERR_NO_FILE
            );
          }
        }
      }
    }
    return $return;
  }
  // }}}
  // {{{
  function gatherUploadedFiles () {
    // get uploaded files
    $files = $this->getUploadedFiles();
    
    // populate $_FILES
    while (list($key, $val) = each($files)) {
      $_FILES[$key] = $val;
    }
  }
  // }}}
  // {{{
  function handleFlashUpload () {
    // check for errors
    if (!isset($_FILES['SolmetraUploader']) || !is_array($_FILES['SolmetraUploader'])) {
      $this->__reportToFlash('ERROR', 'UPLOAD_ERR');
      return false;
    }
    elseif ($_FILES['SolmetraUploader']['error'] > 0) {
      $errors = array(
        '1' => 'UPLOAD_ERR_INI_SIZE',
        '2' => 'UPLOAD_ERR_FORM_SIZE',
        '3' => 'UPLOAD_ERR_PARTIAL',
        '4' => 'UPLOAD_ERR_NO_FILE',
        '6' => 'UPLOAD_ERR_NO_TMP_DIR',
        '7' => 'UPLOAD_ERR_CANT_WRITE',
        '8' => 'UPLOAD_ERR_EXTENSION'
      );
      @$this->__reportToFlash('ERROR', $errors[$_FILES['SolmetraUploader']['error']]);
      return false;
    }
    
    // check valid instance
    if ($this->getSetting('secureuploads')) {
      $instance = $this->__get('instance');
      if ($instance === false || !$this->__claimToken($instance)) {
        $this->__reportToFlash('ERROR', 'UPLOAD_ERR_UNAUTHORIZED');
        return false;
      }
    }
    
    // generate filename to store the file
    $dir = $this->getSetting('uploaddir');
    if ($this->getSetting('useoriginalname')) {
      // use original name
      $filename = $_FILES['SolmetraUploader']['name'];
      while (file_exists($dir.$filename)) {
        if ($this->getSetting('overwriteexisting')) {
          // overwrite
          unlink($dir.$filename);
        }
        else {
          // append a number
          if (preg_match('/_([0-9]+)\.[^.]*$/', $filename, $arr)) {
            $arr[1]++;
            $filename = preg_replace('/_[0-9]+(\.[^.]*)$/', '_'.$arr[1].'$1', $filename);
          }
          else {
            $filename = preg_replace('/(\.[^.]*)$/', '_1$1', $filename);
          }
        }
      }
    }
    else {
      // generate the temporary name
      do {
        $filename = md5(microtime());
      } while (file_exists($dir.$filename));
    }
    
    // move uploaded file
    if (!@move_uploaded_file($_FILES['SolmetraUploader']['tmp_name'], $dir.$filename)) {
      $this->__reportToFlash('ERROR', 'UPLOAD_ERR_MOVE');
      return false;
    }
    
    // report successful upload
    $this->__reportToFlash('OK', $filename);
    return true;
  }
  // }}}
  // {{{
  function __reportToFlash ($event, $message) {
    echo strtoupper($event).':'.$message;
  }
  // }}}
  // {{{
  function __runGC () {
    // calculate probability
    $prob = $this->getSetting('gcprobability');
    if (($prob > 0) && mt_rand(1, 100) <= $prob) {
      $this->runGC();
    }
  }
  // }}}
  // {{{
  function runGC () {
    $dirs = array($this->getSetting('tmpDir'), $this->getSetting('uploadDir'));
    $ttl = $this->getSetting('filettl') * 60;
    while (list(, $dir) = each($dirs)) {
      if ($dirh = @dir($dir)) {
        while (false !== ($entry = $dirh->read())) {
          $file = $this->__getUrl($dir, $entry);
          if (is_file($file) && (filemtime($file) < (time() - $ttl))) {
            @unlink($file);
          }
        }
      }
    }
  }
  // }}}
  // {{{
  function __claimToken ($instance) {
    $file = $this->getSetting('tmpDir').$this->__generateTokenName($instance);
    if (file_exists($file)) {
      // we do not remove file here
      // let's leave it to garbage collector to clean up
      // maybe user would want to resubmit the form
      return true;
    }
    return false;
  }
  // }}}
  // {{{
  function __createToken ($instance) {
    $f = @fopen($this->getSetting('tmpDir').$this->__generateTokenName($instance), 'w');
    @fclose($f);
    return true;
  }
  // }}}
  // {{{
  function __generateTokenName ($instance) {
    return $instance.'_'.md5($this->__getIp());
  }
  // }}}
  // {{{
  function __getUrl ($path, $file) {
    if ($path == '') {
      return $file;
    }
    return str_replace('//', '/', $path.'/'.$file);
  }
  // }}}
  // {{{
  function __getIp () {
    return $_SERVER['REMOTE_ADDR'];
  }
  // }}}
  // {{{
  function __escape ($string, $allowspecial = false) {
    if (!$allowspecial) {
      $string = htmlspecialchars($string);
    }
    return str_replace(array("\\", "'", "\""), array("\\\\", "\\'", "\\'"), $string);
  }
  // }}}
  // {{{
  function __normalizeDir ($dir) {
    $dir = str_replace('%APPDIR%', dirname(__FILE__), $dir);
    $dir = str_replace(array('//', '\/'), '', $dir);
    return substr($dir, -1) == '/' ? $dir : $dir.'/';
  }
  // }}}
  // {{{
  function __get ($var) {
    $post = &$_POST;
    $get  = &$_GET;
    if (isset($post[$var]))
      return is_array($post[$var]) ? $post[$var] : $this->__strip($post[$var]);
    elseif (isset($get[$var]))
      return is_array($get[$var]) ? $get[$var] : $this->__strip($get[$var]);
    else
      return false;
  }
  // }}}
  // {{{
  function __strip ($str) {
    return ini_get('magic_quotes_gpc') == 1 ? stripslashes($str) : $str;
  }
  // }}}
  // {{{
  function getLastInstance () {
    $cnt = sizeof($this->instances);
    return $cnt ? $this->instances[$cnt - 1] : '';
  }
  // }}}
}
?>