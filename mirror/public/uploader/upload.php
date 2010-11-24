<?php
/**
 * Solmetra Uploader v1.0 upload handling script
 * 
 * @package uploader
 * @author Martynas Majeris <martynas@solmetra.com> 
 * @copyright UAB Solmetra   
 */
include 'SolmetraUploader.php';
$solmetraUploader = new SolmetraUploader();
$solmetraUploader->handleFlashUpload();
?>