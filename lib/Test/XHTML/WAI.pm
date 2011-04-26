package Test::XHTML::WAI;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.04';

#----------------------------------------------------------------------------

=head1 NAME

Test::XHTML::WAI - Basic WAI compliance checks.

=head1 SYNOPSIS

    my $txw = Test::XHTML::WAI->new();

    $txw->validate($content);       # run compliance checks
    my $results = $txw->results();  # retrieve results

    $txw->clear();                  # clear all current errors and results
    $txw->errors();                 # all current errors reported
    $txw->errstr();                 # basic error message

    $txw->logfile($file);           # logfile for verbose messages
    $txw->logclean(1);              # 1 = overwrite, 0 = append (default)

=head1 DESCRIPTION

This module attempts to check WAI compliance. Currently only basic checks are
implemented, but more comprehensive checks are planned.

=cut

# -------------------------------------
# Library Modules

use base qw(Class::Accessor::Fast);
use File::Basename;
use File::Path;
use HTML::TokeParser;

# -------------------------------------
# Variables

my @RESULTS = qw( PASS FAIL );

# -------------------------------------
# Public Methods

sub new {
    my $proto = shift; # get the class name
    my $class = ref($proto) || $proto;

    # private data
    my $self  = {};
    $self->{RESULTS}{$_} = 0    for(@RESULTS);

    bless ($self, $class);
    return $self;
}

sub DESTROY {
    my $self = shift;
}

__PACKAGE__->mk_accessors(qw( logfile logclean ));

sub validate    { _process_checks(@_);  }
sub results     { _process_results(@_); }

sub clear       { my $self = shift; $self->{ERRORS} = undef; $self->_reset_results(); }
sub errors      { my $self = shift; return $self->{ERRORS}; }
sub errstr      { my $self = shift; return $self->_print_errors(); }

# -------------------------------------
# Private Methods

sub _process_results {
    my $self = shift;
    my %results = map {$_ => $self->{RESULTS}{$_}} @RESULTS;
    $self->_log( sprintf "%8s%d\n", "$_:", $results{$_} ) for(@RESULTS);
    return \%results;
}

sub _reset_results {
    my $self = shift;
    $self->{RESULTS}{$_} = 0    for(@RESULTS);
}

sub _print_errors {
    my $self = shift;
    my $str = "\nErrors:\n" ;
    my $i = 1;
    for my $error (@{$self->{ERRORS}}) {
        $str .= "$i. $error->{message}\n";
        $i++;
    }
    return $str;
}

# -------------------------------------
# Subroutines

# TODO
# (AA) check for absolute rather than relative table cell values
# (A)  label associated with each input id

sub _process_checks {
    my $self = shift;
    my $html = shift;
    my (%form,%input,%label);

    #use Data::Dumper;
    #print STDERR "#html=".Dumper($html);

    if($html) {
        my $p = HTML::TokeParser->new(\$html);

        #print STDERR "#p=".Dumper($p);
        
        while( my $tag = $p->get_tag('form', '/form', 'input', 'img', 'a', 'table', 'map', 'object', 'label') ) {
            if($tag->[0] eq 'form') {
                %form = ( id => ($tag->[1]{id} || $tag->[1]{name}) );
            } elsif($tag->[0] eq '/form') {
                if(!$form{submit}) {
                    push @{ $self->{ERRORS} }, {
                        error => "missing submit in form", 
                        message => 'no submit tag in form (' . ( $form{id} || '' ) . ')'
                    };
                }
            } elsif($tag->[0] eq 'input') {
                $form{submit} = 1   if($tag->[1]{type} eq 'submit');
                if($tag->[1]{type} eq 'text' && $tag->[1]{id} && $tag->[1]{name} && $tag->[1]{id} ne $tag->[1]{name}) {
                    push @{ $self->{ERRORS} }, {
                        error => "id/name do not match in input tag", 
                        message => "id/name mis-match in input tag ($tag->[1]{id}/$tag->[1]{name})"
                    };
                }

                if($tag->[1]{id}) {
                    if($input{ $tag->[1]{id} }) {
                        push @{ $self->{ERRORS} }, {
                            error => "dupliate id in input tag", 
                            message => "all input tags require a unique id ($tag->[1]{id})"
                        };
                    } else {
                        $input{ $tag->[1]{id} } = $tag->[1]{type} eq 'text';
                    }
                } else {
                    push @{ $self->{ERRORS} }, {
                        error => "missing id in input tag", 
                        message => "all input tags require an id ($tag->[1]{name})"
                    };
                }

            } elsif($tag->[0] eq 'label') {
                if($tag->[1]{for}) {
                    if($label{ $tag->[1]{for} }) {
                        push @{ $self->{ERRORS} }, {
                            error => "dupliate for in label tag", 
                            message => "all label tags should reference a unique id ($tag->[1]{for})"
                        };
                    } else {
                        $label{ $tag->[1]{for} } = 1;
                    }
                } else {
                    push @{ $self->{ERRORS} }, {
                        error => "missing 'for' attribute in label tag", 
                        message => "all label tags must reference an input id"
                    };
                }

            } elsif($tag->[0] eq 'img') {
                if(!defined $tag->[1]{alt}) {
                    push @{ $self->{ERRORS} }, {
                        error => "missing alt from $tag->[0]", 
                        message => "no alt attribute in img tag ($tag->[1]{src})"
                    };
                }
            } elsif($tag->[0] eq 'a') {
                if(defined $tag->[1]{href} && !defined $tag->[1]{title}) {
                    push @{ $self->{ERRORS} }, {
                        error => "missing title from $tag->[0]", 
                        message => "no title attribute in a tag ($tag->[1]{href})"
                    };
                }
            } elsif($tag->[0] =~ /table|map|object/) {
                if(!defined $tag->[1]{title}) {
                    push @{ $self->{ERRORS} }, {
                        error => "missing title from $tag->[0]", 
                        message => "no title attribute in $tag->[0] tag"
                    };
                }
            }
        }

        for my $input (keys %input) {
            next    if($label{$input});

            push @{ $self->{ERRORS} }, {
                error => "missing label for input tag", 
                message => 'all input tags require a unique label tag ($input)'
            };
        }

        for my $input (keys %label) {
            next    if($input{$input});

            push @{ $self->{ERRORS} }, {
                error => "missing input for label tag", 
                message => 'all label tags should reference a unique input tag ($input)'
            };
        }
    } else {
        push @{ $self->{ERRORS} }, {
            error => "missing content", 
            message => 'no XHTML content found'
        };
    }

    if($self->{ERRORS}) {
        $self->_log( "FAIL\n" );
        $self->{RESULTS}{FAIL}++;
    } else {
        $self->_log( "PASS\n" );
        $self->{RESULTS}{PASS}++;
    }
}

sub _log {
    my $self = shift;
    my $log = $self->logfile or return;
    mkpath(dirname($log))   unless(-f $log);

    my $mode = $self->logclean ? 'w+' : 'a+';
    $self->logclean(0);

    my $fh = IO::File->new($log,$mode) or die "Cannot write to log file [$log]: $!\n";
    print $fh @_;
    $fh->close;
}

1;

__END__

=head1 METHODS

=head2 Constructor

Enables test object to retain content, results and errors as appropriate.

=over 4

=item new()

Creates and returns a Test::XHTML::WAI object.

=back

=head2 Public Methods

=over 4

=item validate(CONTENT)

Checks given content for basic compliance.

=item results()

Record results to log file (if given) and returns a hashref.

=item errors()

Returns all the current errors reported as XML::LibXML::Error objects.

=item errstr()

Returns all the current errors reported as a single string.

=item clear()

Clear all current errors and results.

=item logfile(FILE)

Set output log file for verbose messages.

=item logclean(STATE)

Set STATE to 1 (create/overwrite) or 0 (append - the default)

=back

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties, that is not explained within the POD
documentation, please send bug reports and patches to barbie@cpan.org.

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 SEE ALSO

L<HTML::TokeParser>

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  for Miss Barbell Productions <http://www.missbarbell.co.uk>.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2008-2011 Barbie for Miss Barbell Productions.

  This module is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut

