#!/usr/bin/perl -w
use strict;
use warnings;

# + 1 for Test::NoWarnings
use Test::More tests => 2 + 1;
use Test::XHTML::WAI;
use Test::NoWarnings;
use IO::File;

# Error path #1: Inputs with no names, types, anchors without identifiers or titles
# https://github.com/barbie/test-xhtml/issues/2
my $txw = Test::XHTML::WAI->new();
my $content = read_file('./t/samples/test04.html');
$txw->validate($content);
my $result = $txw->results();
my $model = { 'FAIL' => 1, 'PASS' => 0 };
is_deeply( $result, $model, "WAI compliance check for WCAG violations - FAIL");
my $errors = $txw->errors();
$model = [
    {
        'col' => 3,
        'error' => 'W003',
        'message' => 'all <input> tags require a <label> or a title attribute (undefType)',
        'ref' => 'WCAG v2 1.1.1 (A)',
        'row' => 12
    },
    {
        'col' => 3,
        'error' => 'W003',
        'message' => 'all <input> tags require a <label> or a title attribute (<input style="display:none" />)',
        'ref' => 'WCAG v2 1.1.1 (A)',
        'row' => 13
    },
    {
        'col' => 2,
        'error' => 'W001',
        'message' => 'no submit button in form (testForm)',
        'ref' => 'WCAG v2 3.2.2 (A)',
        'row' => 14
    },
    {
        'col' => 4,
        'error' => 'W007',
        'message' => 'no title attribute in a tag (https://www.youtube.com/watch?v=dQw4w9WgXcQ, \'<a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ">\')',
        'ref' => 'WCAG v2 1.1.1 (A)',
        'row' => 17
    },
    {
        'col' => 3,
        'error' => 'W014',
        'message' => 'all <input> tags require a unique <label> tag or a title attribute (undefType)',
        'ref' => 'WCAG v2 1.1.1 (A)',
        'row' => 11
    }
];
is_deeply( $errors, $model, "...and we got the expected errors" );

# copied from 20xmlstrings.t
sub read_file {
    my $file = shift;
    my $text;

    my $fh = IO::File->new($file,'r')  or die "Cannot open file [$file]: $!\n";
    while(<$fh>) { $text .= $_; }
    $fh->close;

    return $text;
}
