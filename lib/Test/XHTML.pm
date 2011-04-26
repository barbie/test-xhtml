package Test::XHTML;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.04';

#----------------------------------------------------------------------------

=head1 NAME

Test::XHTML - Test your web page DTD validation.

=head1 SYNOPSIS

    use Test::XHTML;

    my $tests = "t/102-internal-level7.csv";
    Test::XHTML::runtests($tests);

=head1 DESCRIPTION

Test the DTD Validation of a list of URLs.

=cut

# -------------------------------------
# Library Modules

use IO::File;
use Data::Dumper;
use Test::Builder;
use Test::XHTML::Valid;
use Test::XHTML::WAI;
use WWW::Mechanize;

# -------------------------------------
# Singletons

my $mech    = WWW::Mechanize->new();
my $txv     = Test::XHTML::Valid->new();
my $txw     = Test::XHTML::WAI->new();
my $Test    = Test::Builder->new();

sub import {
    my $self    = shift;
    my $caller  = caller;
    no strict 'refs';
    *{$caller.'::runtests'} = \&runtests;
    *{$caller.'::setlog'}   = \&setlog;

    my @args = @_;

    $Test->exported_to($caller);
    $Test->plan(@args)  if(@args);
}

# -------------------------------------
# Public Methods

sub runtests {
    my $tests = shift;
    my ($link,$type,$content,%config,@all);

    my $fh = IO::File->new($tests,'r') or die "Cannot open file [$tests]: $!\n";
    while(<$fh>) {
        s/\s*$//;
        s/^[#,].*$//;
        next    if(/^\s*$/);

        my ($cmd,$text,$label) = split(',',$_,3);
        #$cmd =~ s/\s*$//;
        #print STDERR "# $cmd,$text,$label\n";

        if($cmd eq 'config') {
            my ($key,$value) = split('=',$text,2);
            $config{lc $key} = $value;
        } elsif($cmd eq 'all body') {
            push @all, {type => 'like', text => $text, label => $label};
        } elsif($cmd eq 'all body not') {
            push @all, {type => 'unlike', text => $text, label => $label};
        } elsif($cmd eq 'except') {
            push @{ $all[-1]->{except} }, $text;

        } elsif($cmd eq 'file') {
            $type = $cmd;
            $link = $text;
            if($config{xhtml}) {
                $txv->clear();
                $txv->process_file($link);
                my $result = $txv->process_results();
                $Test->is_num($result->{PASS},1,"XHTML validity check for '$link'");

                if($result->{PASS} != 1) {
                    $Test->diag($txv->errstr());
                    $Test->diag(Dumper($txv->errors()))  if($config{'dump'});
                    $Test->diag(Dumper($result))            if($config{'dump'});
                }
            } else {
                $txv->retrieve_file($link);
            }

            $content = $txv->content();
            $label ||= "Got FILE '$link'";
            $Test->ok($content,$label);

            if($config{wai}) {
                $txw->clear();
                $txw->validate($content);
                my $result = $txw->results();
                $Test->is_num($result->{PASS},1,"Content passes basic WAI compliance checks for '$link'");
                if($result->{PASS} != 1) {
                    $Test->diag($txw->errstr());
                    $Test->diag(Dumper($txw->errors()))     if($config{'dump'});
                    $Test->diag(Dumper($result))            if($config{'dump'});
                }
            }

            for my $all (@all) {
                my $ignore = 0;
                for my $except (@{ $all->{except} }) {
                    next    unless($link =~ /$except/);
                    $ignore = 1;
                }

                if($all->{type} eq 'like') {
                    $label = $all->{label} || ".. embedded text ('$all->{text}') found for '$link'";
                    next    if($ignore);
                    $Test->like($content,qr!$all->{text}!, $label);
                    $Test->diag($content)  if($content !~ m!$all->{text}! && $config{'dump'});
                } else {
                    $label = $all->{label} || ".. embedded text ('$all->{text}') not found for '$link'";
                    next    if($ignore);
                    $Test->unlike($content,qr!$all->{text}!, $label);
                    $Test->diag($content)  if($content =~ m!$all->{text}! && $config{'dump'});
                }
           }

        } elsif($cmd eq 'url') {
            $type = $cmd;
            $link = $text;
            if($config{xhtml}) {
                $txv->clear();
                $txv->process_link($link);
                my $result = $txv->process_results();
                $Test->is_num($result->{PASS},1,"XHTML validity check for '$link'");

                if($result->{PASS} != 1) {
                    $Test->diag($txv->errstr());
                    $Test->diag(Dumper($txv->errors()))  if($config{'dump'});
                    $Test->diag(Dumper($result))            if($config{'dump'});
                }
            } else {
                $txv->retrieve_url($link);
            }

            $content = $txv->content();
            $label ||= "Got URL '$link'";
            $Test->ok($content,$label);

            if($config{wai}) {
                $txw->clear();
                $txw->validate($content);
                my $result = $txw->results();
                $Test->is_num($result->{PASS},1,"Content passes basic WAI compliance checks for '$link'");
                if($result->{PASS} != 1) {
                    $Test->diag($txw->errstr());
                    $Test->diag(Dumper($txw->errors()))     if($config{'dump'});
                    $Test->diag(Dumper($result))            if($config{'dump'});
                }
            }

            for my $all (@all) {
                my $ignore = 0;
                for my $except (@{ $all->{except} }) {
                    next    unless($link =~ /$except/);
                    $ignore = 1;
                }

                if($all->{type} eq 'like') {
                    $label = $all->{label} || ".. embedded text ('$all->{text}') found for '$link'";
                    next    if($ignore);
                    $Test->like($content,qr!$all->{text}!, $label);
                    $Test->diag($content)  if($content !~ m!$all->{text}! && $config{'dump'});
                } else {
                    $label = $all->{label} || ".. embedded text ('$all->{text}') not found for '$link'";
                    next    if($ignore);
                    $Test->unlike($content,qr!$all->{text}!, $label);
                    $Test->diag($content)  if($content =~ m!$all->{text}! && $config{'dump'});
                }
           }

        } elsif($cmd eq 'body') {
            $label ||= ".. embedded text ('$text') found for '$link'";
            $Test->like($content,qr!$text!s, $label);
            $Test->diag($content)  if($content !~ m!$text!s && $config{'dump'});

        } elsif($cmd eq 'body not') {
            $label ||= ".. embedded text ('$text') not found for '$link'";
            $Test->unlike($content,qr!$text!s, $label);
            $Test->diag($content)  if($content =~ m!$text!s && $config{'dump'});

        } elsif($cmd eq 'input' && $type eq 'url') {
            my ($key,$value) = split('=',$text,2);
            if($key eq 'submit') {
                $mech->submit();
                if($mech->success()) {
                    $content = $mech->content();
                } else {
                    $content = '';
                }
            } else {
                $mech->field($key,$value);
            }
        }
    }
    $fh->close;
}

sub setlog {
    my %hash = @_;

    $txv->logfile($hash{logfile})    if($hash{logfile});
    $txv->logclean($hash{logclean})  if(defined $hash{logclean});

    $txw->logfile($hash{logfile})    if($hash{logfile});
    $txw->logclean($hash{logclean})  if(defined $hash{logclean});
}

1;

__END__

=head1 FUNCTIONS

=head2 runtests(FILE)

Runs the tests contained within FILE. The entries in FILE define how the tests
are performed, and on what.

A simple file might look like:

    #,# Configuration,
    config,xhtml=1,
    
    url,http://mysite/index.html,Test My Page

Where each field on the comma separated line represent 'cmd', 'text' and 
'label'. Valid 'cmd' values are:

  #             - comment line, ignores the line
  config        - set configuration value
  all body      - test that 'text' exists in body content of all urls.
  all body not  - test that 'text' does not exist in body content of all urls.
  url           - test single url
  body          - test that 'text' exists in body content of the previous url.
  body not      - test that 'text' does not exist in body content of the 
                  previous url.
  input         - form fill, use as 'fieldname=xxx', with 'submit' as the last
                  input to submit the form.

The 'label' is used with the tests, and if left blank will be automatically 
generated.

=head2 setlog(HASH)

If required will record a test run to a log file. If you do not wish to record
multiple runs, set 'logclean => 1' and log file will be recreated each time.
Otherwise all results are appended to the named log file.

  Test::XHTML::setlog( logfile => './test.log', logclean => 1 );

=head1 NOTES

=head2 Test::XHTML::Valid & xhtml-valid

The underlying package that provides the validation framework, is only used
sparingly by Test::XHTML. Many more methods to test websites (both remote and 
local) are supported, and can be accessed via the xhtml-valid script that 
accompanies this distribution.

See script documentation and L<Test::XHTML::Valid> for further details.

=head2 Internet Access

Unfortunately XML::LibXML requires internet access to obtain all the necessary
W3C and DTD specifications as denoted in the web pages you are attempting to
validate. Without internet access, this distribution will skip its functional
tests.

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties, that is not explained within the POD
documentation, please send bug reports and patches to barbie@cpan.org.

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 SEE ALSO

L<XML::LibXML>,
L<Test::XHTML::Valid>

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  for Miss Barbell Productions <http://www.missbarbell.co.uk>.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2008-2011 Barbie for Miss Barbell Productions.

  This module is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut

