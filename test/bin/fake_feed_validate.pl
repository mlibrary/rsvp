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
  print "something went wrong\n";
  print "failed!\n";
}
else {
  print "success!\n";
}
