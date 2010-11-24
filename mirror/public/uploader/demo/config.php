<?php
/**
 * Solmetra Uploader v1.0 configuration file
 * 
 * @package uploader
 * @author Martynas Majeris <martynas@solmetra.com> 
 * @copyright UAB Solmetra   
 */
 
$this->settings = array(
  'baseurl'                 => '../',                                   // a base URL for uploader.swf
  
  'width'                   => '300',                                   // default width of the control; in pixels or %
  
  'height'                  => '200',                                    // default height of the control; in pixels or %
  
  'required'                => false,                                   // if true form will not submit unless a file is selected 
                                                                        // for upload
  
  'hijackForm'              => true,                                    // if true Uploader will try to "hijack" enclosing form 
                                                                        // to catch submit event and delay it until file was 
                                                                        // successfully uploaded
                                                                        
  'secureUploads'           => false,                                   // if true Uploader will log every generated instance and 
                                                                        // user's IP address and will accept file uploads only 
                                                                        // from valid instances and the same IP
  
  'verifyUpload'            => true,                                    // if true, Uploader will wait for a successfull upload
                                                                        // confirmation or an error from a script it is uploading
                                                                        // to in the form:
                                                                        //   ERROR:<error_code>
                                                                        // or
                                                                        //   OK:<uploaded_or_temporary_file_name>
                                                                        //
                                                                        // Examples:
                                                                        //   ERROR:UPLOAD_ERR_INI_SIZE
                                                                        //   OK:report.pdf
                                                                        //
                                                                        // this setting is ignored if hijackForm == true
  
  'useOriginalName'         => false,                                   // normally for security reasons Uploader stores files 
                                                                        // on server with a temporary names assuming that your 
                                                                        // script that does post-processing renames/moves them 
                                                                        // (all the original data is available by calling 
                                                                        // getUploadedFiles() method). However if you set this 
                                                                        // setting to true, Uploader will store files on your 
                                                                        // server using their original file names.
                                                                        // Depending on what extensions you allow to upload and 
                                                                        // if upload directory is "visible" through http 
                                                                        // requests might possess a severe security risk since 
                                                                        // malicious user might upload a .php file
  
  'overwriteExisting'       => false,                                   // aplicable only if useoriginalname is set to true. 
                                                                        // if false Uploader will rename the filename in order 
                                                                        // not to overwrite an existing file
   
  'configUrl'               => 'uploader.xml',                          // a relative or absolute URL to Uploader frontend config 
                                                                        // file; please note that this will be relative to PHP 
                                                                        // script that displays Uploader; not the uploader.swf
  
  'embedConfig'             => false,                                   // if true config XML file will be preloaded on server
                                                                        // and served to Uploader through HTML object's params
                                                                        // preventing Uploader making separate request to web
                                                                        // server 
  
  'language'                => 'en',                                    // language for prompts
  
  'bgcolor'                 => '#ffffff',                               // background color for uploader.swf
  
  'useFileTag'              => true,                                    // if true Uploader will be replaced with a simple HTML 
                                                                        // <file> tag if browser has JavaScript turned off or has 
                                                                        // an incompatible flash version (below 8)
  
  'fileTagParams'           => array(),                                 // an array of property/value pairs to add to <file> tag; 
                                                                        // i.e.: array('class' => 'myInput')
  
  'allowedExtensions'       => array(),                                 // an array of allowed file extensions
  
  'disallowEdextensions'    => array('php', 'php3', 'php4', 'php5'),    // an array of disallowed file extensions
  
  'stripMultipleExtensions' => true,                                    // if true only last extension will be left for the file 
                                                                        // uploaded; i.e. "malicious.php.gif" will become 
                                                                        // "malicious.gif"; it is strongly recommended leaving it 
                                                                        // set to true
  
  'uploadDir'               => '%APPDIR%/uploads/',                     // a directory to put uploaded files into; it is strongly 
                                                                        // recommended setting this to a directory that is NOT 
                                                                        // accesible through http requests
  
  'tmpDir'                  => '%APPDIR%/tmp/',                         // a directory to put temporary files into; aplicable only 
                                                                        // if secureUploads=true; it is strongly recommended 
                                                                        // setting this to a directory that is NOT accesible through 
                                                                        // http requests
  
  'fileTTL'                 => 180,                                     // number of minutes to keep unclaimed files in uploadDir 
                                                                        // and tmpDir; used by garbage collector
  
  'gcProbability'           => 5                                        // percent value of the probability a garbage collector is 
                                                                        // executed when instantiating Uploader:
                                                                        // 0 - never, 100 - every time; 
                                                                        // set this to higher number on very rarely used pages  
);
?>