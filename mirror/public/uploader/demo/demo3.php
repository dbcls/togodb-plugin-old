<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <title>Solmetra Flash Uploader Demo</title>
  <style>
  body    { background-color: #ffffff; font-family: Verdana; font-size: 10pt; }
  .info   { border: 1px solid #aaaaaa; padding: 5px; }
  h3      { margin: 20px 0px 5px 0px; }
  </style>
  <script type="text/javascript" src="../SolmetraUploader.js"></script>
</head>
<body>
<h1>Solmetra Flash Uploader Demo</h1>
<?php
// === Include main Uploader class
include '../SolmetraUploader.php';

// === Instantiate the class
$solmetraUploader = new SolmetraUploader(
  '../',           // a base path to Flash Uploader's directory (relative to the page)
  'upload.php',       // path to a file that handles file uploads (relative to uploader.swf) [optional]
  '../config.php'  // path to a server-side config file (relative to the page) [optional]
);

// === Gather uploaded files
// Flash Uploader populates PHP's own $_FILE global variable 
// with the information about uploaded files 
$solmetraUploader->gatherUploadedFiles();
if (isset($_FILES) && sizeof($_FILES)) {
  echo '<h2>Uploaded files</h2>';
  echo '<pre class="info">';
  print_r($_FILES);
  echo '</pre>';
}
?>

<h2>Test Form</h2>

<p>This demo shows off Flash Uploader's JavaScript API. Namely seting up event/error listeners for various events as well as controling (starting and canceling) of the upload using API calls from JavaScript.</p>

<form action="demo3.php" method="post">

<h3>File #1</h3>
<?php
echo $solmetraUploader->getInstance('firstFile',      // name of the field 
                                    500,              // width
                                    40,               // height
                                    true,              // yes - it's required
                                                      // the rest of the parameters are taken from config file
                                    true,             // hijack form (recommended)
                                    'demo/custom3.xml'     // let's use different front-end config file than specified in the config.php 
                                    );
?>

<script type="text/javascript">
SolmetraUploader.setErrorHandler('myError');
function myError (instance_id, error_id) {
  alert(error_id);
}
SolmetraUploader.setEventHandler('myEvent');
function myEvent (instance_id, event_id, data) {
  if (instance_id == '<?=$solmetraUploader->getLastInstance();?>') {
    switch(event_id) {
      case 'ready':
        logDebug('Uploader instance ready');
        break;
      case 'selected':
        logDebug('File was selected: ' + data.name);
        document.getElementById('upload_bt').disabled = false;
        break;
      case 'uploading':
        logDebug('Upload progress: ' + data.uploaded + ' of ' + data.size);
        document.getElementById('progress').value = Math.round(data.uploaded / data.size * 100) + '%';
        break;
      case 'complete':
        logDebug('File upload complete!');
        document.getElementById('upload_bt').disabled = true;
        document.getElementById('cancel_bt').disabled = true;
        break;
      case 'canceled':
        logDebug('Upload was canceled by user!');
        break;
      default:
        logDebug('An unknown event was reported: ' + event_id);
        break;
    }
  }
}
function logDebug (str) {
  document.getElementById('debug').value += str + "\r\n";
}

function startUpload (id) {
  document.getElementById('upload_bt').disabled = true;
  document.getElementById('cancel_bt').disabled = false;
  SolmetraUploader.flashTriggerUpload(id);
}

function cancelUpload (id) {
  document.getElementById('upload_bt').disabled = false;
  document.getElementById('cancel_bt').disabled = true;
  SolmetraUploader.flashTriggerCancel(id);
}
</script>

<br />
<input id="upload_bt" type="button" value="Upload" onclick="startUpload('<?=$solmetraUploader->getLastInstance();?>');" disabled="disabled" />
<input id="cancel_bt" type="button" value="Cancel" onclick="cancelUpload('<?=$solmetraUploader->getLastInstance();?>');" disabled="disabled" />
&nbsp;&nbsp;&nbsp;&nbsp;
Progress <input type="text" size="5" value="" id="progress" />
</form>

<textarea id="debug" style="width: 400px; height: 240px;"></textarea>

</form>

</body>
</html>