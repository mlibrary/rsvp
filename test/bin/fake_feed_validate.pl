#!/usr/bin/perl

# read args
my $packagetype = shift;
my $namespace = shift;
my $dir = shift;
my $objid = shift;

if ($ENV{FAKE_FEED_VALIDATE_CRASH}) {
  exit(1);
}

if ($ENV{FAKE_FEED_VALIDATE_FAIL}) {
  my $barcode_file = $ENV{FAKE_FEED_VALIDATE_FAIL} || '00000000000000/00000001.tif';
  my ($barcode, $file) = split '/', $barcode_file;
  print "\e[1;33m15640: WARN - Validation failed	objid: $barcode	namespace: mdp	file: $file	field: image orientation	detail: This checks that the orientation in which the image should be displayed matches the \"natural\" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m\n";
  print "\e[1;31m15640: ERROR - Missing field value	objid: $barcode	namespace: mdp	file: $file	field: in XMP - tiff:Artist	remediable: 1\e[0m\n";
  print "\e[1;31m15640: ERROR - File validation failed	namespace: mdp	objid: $barcode	stage: HTFeed::VolumeValidator	file: $file\e[0m\n";
  print "failure!\n";
}
# Recent versions of feed are more verbose
elsif ($ENV{FAKE_NEW_FEED_VALIDATE_FAIL}) {
  my $barcode_file = $ENV{FAKE_NEW_FEED_VALIDATE_FAIL} || '00000000000000/00000001.tif';
  my ($barcode, $file) = split '/', $barcode_file;
  print "\e[1;33mMay 21 11:56:08 Computer.local ../feed/bin/validate_images.pl[87997]: WARN - Validation failed	objid: $barcode	namespace: mdp	file: $file	field: image orientation	detail: This checks that the orientation in which the image should be displayed matches the \"natural\" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m\n";
  print "\e[1;31mMay 21 11:56:08 Computer.local ../feed/bin/validate_images.pl[87997]: ERROR - Missing field value	objid: $barcode	namespace: mdp	file: $file	field: in XMP - tiff:Artist	remediable: 1\e[0m\n";
  print "\e[1;31mMay 21 11:56:08 Computer.local ../feed/bin/validate_images.pl[87997]: ERROR - File validation failed	namespace: mdp	objid: $barcode	stage: HTFeed::VolumeValidator	file: $file\e[0m\n";
  print "failure!\n";
}
else {
  print "success!\n";
}
