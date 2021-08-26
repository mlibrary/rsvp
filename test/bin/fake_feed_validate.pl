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
  my @parts = split '/', $barcode_file;
  my $file = pop @parts;
  my $barcode = join '/', @parts;
  print <<END
\e[1;33m15640: WARN - Validation failed\tobjid: $barcode\tnamespace: mdp\tfile: $file\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the \"natural\" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15640: ERROR - Missing field value\tobjid: $barcode\tnamespace: mdp\tfile: $file\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15640: ERROR - File validation failed\tnamespace: mdp\tobjid: $barcode\tstage: HTFeed::VolumeValidator\tfile: $file\e[0m
failure!
END
}
# Recent versions of feed are more verbose
elsif ($ENV{FAKE_NEW_FEED_VALIDATE_FAIL}) {
  my $barcode_file = $ENV{FAKE_NEW_FEED_VALIDATE_FAIL} || '00000000000000/00000001.tif';
  my @parts = split '/', $barcode_file;
  my $file = pop @parts;
  my $barcode = join '/', @parts;
  print <<END
\e[1;33mMay 21 11:56:08 Computer.local ../feed/bin/validate_images.pl[87997]: WARN - Validation failed\tobjid: $barcode\tnamespace: mdp\tfile: $file\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the \"natural\" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31mMay 21 11:56:08 Computer.local ../feed/bin/validate_images.pl[87997]: ERROR - Missing field value\tobjid: $barcode\tnamespace: mdp\tfile: $file\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31mMay 21 11:56:08 Computer.local ../feed/bin/validate_images.pl[87997]: ERROR - File validation failed\tnamespace: mdp\tobjid: $barcode\tstage: HTFeed::VolumeValidator\tfile: $file\e[0m
failure!
END
}
elsif ($ENV{FAKE_FEED_VALIDATE_LONG}) {
  print <<END
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000001.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000001.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000001.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000001.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000001.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000002.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000002.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000002.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000002.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000002.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000003.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000003.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000003.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000003.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000003.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000004.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000004.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000004.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000004.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000004.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000005.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000005.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000005.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000005.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000005.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000006.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000006.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000006.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000006.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000006.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000007.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000007.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000007.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000007.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000007.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000008.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000008.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000008.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000008.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000008.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000009.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000009.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000009.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000009.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000009.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000010.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000010.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000010.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000010.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000010.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000011.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000011.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000011.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000011.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000011.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000012.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000012.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000012.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000012.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000012.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000013.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000013.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000013.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000013.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000013.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000014.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000014.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000014.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000014.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000014.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000015.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000015.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000015.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000015.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000015.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000016.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000016.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000016.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000016.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000016.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000017.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000017.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000017.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000017.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000017.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000018.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000018.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000018.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000018.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000018.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000019.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000019.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000019.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000019.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000019.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000020.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000020.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000020.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000020.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000020.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000021.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000021.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000021.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000021.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000021.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000022.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000022.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000022.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000022.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000022.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000023.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000023.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000023.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000023.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000023.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000024.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000024.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000024.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000024.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000024.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000025.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000025.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000025.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000025.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000025.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000026.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000026.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000026.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000026.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000026.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000027.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000027.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000027.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000027.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000027.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000028.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000028.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000028.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000028.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000028.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000029.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000029.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000029.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000029.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000029.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000030.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000030.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000030.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000030.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000030.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000031.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000031.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000031.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000031.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000031.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000032.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000032.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000032.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000032.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000032.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000033.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000033.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000033.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000033.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000033.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000034.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000034.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000034.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000034.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000034.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000035.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000035.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000035.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000035.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000035.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000036.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000036.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000036.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000036.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000036.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000037.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000037.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000037.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000037.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000037.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000038.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000038.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000038.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000038.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000038.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000039.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000039.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000039.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000039.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000039.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000040.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000040.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000040.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000040.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000040.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000041.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000041.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000041.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000041.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000041.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000042.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000042.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000042.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000042.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000042.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000043.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000043.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000043.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000043.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000043.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000044.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000044.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000044.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000044.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000044.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000045.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000045.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000045.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000045.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000045.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000046.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000046.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000046.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000046.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000046.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000047.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000047.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000047.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000047.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000047.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000048.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000048.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000048.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000048.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000048.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000049.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000049.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000049.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000049.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000049.jp2\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000050.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\e[0m
\e[1;31m15093: ERROR - Invalid value for field\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000050.jp2\tfield: in XMP - tiff:Orientation\tremediable: 1\tactual: (null)\texpected: 1\e[0m
\e[1;33m15093: WARN - Validation failed\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000050.jp2\tfield: image orientation\tdetail: This checks that the orientation in which the image should be displayed matches the "natural" order of pixels in the image. If not, this can be remediated by setting the value to 1 (normal) and rotating the image as needed.\e[0m
\e[1;31m15093: ERROR - Missing field value\tobjid: 69015000006870\tnamespace: mdp\tfile: 00000050.jp2\tfield: in XMP - tiff:Artist\tremediable: 1\e[0m
\e[1;31m15093: ERROR - File validation failed\tnamespace: mdp\tobjid: 69015000006870\tstage: HTFeed::VolumeValidator\tfile: 00000050.jp2\e[0m
failure!
END
}
else {
  print "success!\n";
}
