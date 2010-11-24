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
  <script type="text/javascript">
  SolmetraUploader.setErrorHandler('test');
  function test (id, str) { alert('ERROR: ' + str); }
  SolmetraUploader.setEventHandler('testEvent');
  function testEvent (id, str, data) { /*alert('EVENT: ' + str);*/ }
  </script>
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

<form action="demo1.php" method="post">

<h3>File #1</h3>
<?php
//$solmetraUploader->setDemo(10);
echo $solmetraUploader->getInstance('firstFile',      // name of the field 
                                    500,              // width
                                    40,               // height
                                    true              // yes - it's required
                                                      // the rest of the parameters are taken from config file
                                    );
?>

<h3>File #2</h3>
<?php
echo $solmetraUploader->getInstance('secondFile',     // name of the field 
                                    200,              // width
                                    220,              // height
                                    false,            // not required - allow form to be submitted  
                                    true,             // hijack form (recommended)
                                    'demo/custom.xml',     // let's use different front-end config file than specified in the config.php 
                                                      // (please note that this URL is relative to this demo file) 
                                    true              // embed config (this will load front-end configuration XML file and embed it in the HTML) 
                                    );
?>

<br />
<input type="submit" value="Submit Form" />
</form>

</body>
</html>