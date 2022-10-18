<?php
// get contents of a file into a string
$filename = "favorite.txt";
$handle = fopen($filename, "r");
$contents = fread($handle, filesize($filename));
fclose($handle);
?>
