#!/usr/bin/perl -w
use strict;

use Test::Builder::Tester tests => 1;
use Test::More;
use Test::XHTML;
use IO::File;

my $logfile = './test11.log';
unlink($logfile);

SKIP: {
	skip "Can't see a network connection", 6   if(pingtest());
#{
    setlog( logfile => $logfile, logclean => 1 );

    my $tests = "t/samples/11-filetests.csv";
    my $result = read_file('./t/samples/result11.log');

    test_out(q{ok 1 - Got FILE './t/samples/test03.html'});
    test_out(q{not ok 2 - Content passes basic WAI compliance checks for './t/samples/test03.html'});
    test_out(q{ok 3 - .. Footer found});
    test_out(q{ok 4 - .. embedded text ('<h1>Details</h1>') found for './t/samples/test03.html'});
    test_fail(1);
    runtests($tests);
    test_err($result);
    test_test("WAI compliance testing");
}

unlink($logfile);


# crude, but it'll hopefully do ;)
sub pingtest {
  system("ping -q -c 1 www.w3c.org >/dev/null 2>&1");
  my $retcode = $? >> 8;
  # ping returns 1 if unable to connect
  return $retcode;
}

sub read_file {
    my $file = shift;
    my $text;

    my $fh = IO::File->new($file,'r')  or die "Cannot open file [$file]: $!\n";
    while(<$fh>) { $text .= $_; }
    $fh->close;

    return $text;
}
