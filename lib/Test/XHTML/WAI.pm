package Test::XHTML::WAI;

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.06';

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

# until Gisle updates HTML::TokeParser with the patch [1], and I can require
# a minimum version of it, this will have to suffice.
# [1] https://gitorious.org/perl-html-parser/mainline/merge_requests/2
my $FIXED = $HTML::TokeParser::VERSION > 3.57 ? 1 : 0;

my %declarations = (
    'xhtml1-strict.dtd'         => 2,
    'xhtml1-transitional.dtd'   => 2,
    'xhtml1-frameset.dtd'       => 2,
    'html401-strict.dtd'        => 1,
    'html401-loose.dtd'         => 1,
    'html401-frameset.dtd'      => 1,
);

# -------------------------------------
# Public Methods

sub new {
    my $proto = shift; # get the class name
    my $class = ref($proto) || $proto;

    # private data
    my $self  = {level => 1, case => 0};
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

sub level       { 
    my ($self,$level) = @_;
    $self->{level} = $level if(defined $level && $level =~ /^[123]$/);
    return $self->{level}; 
}

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

    #push @{ $self->{ERRORS} }, {
    #    error => "debug", 
    #    message => "VERSION=$HTML::TokeParser::VERSION, FIXED=$FIXED"
    #};

    #use Data::Dumper;
    #print STDERR "#html=".Dumper($html);

    if($html) {
        my $p = $FIXED 
                    ? HTML::TokeParser->new( \$html,
                            start => "'S',tagname,attr,attrseq,text,line,column",
                            end   => "'E',tagname,text,line,column"
                      )
                    : HTML::TokeParser->new( \$html );

        #print STDERR "#p=".Dumper($p);
        
        # determine declaration and the case requirements
        my $token = $p->get_token();
        if($token && $token->[0] eq 'D') {
            my $declaration = $token->[1];
            $declaration =~ s/\s+/ /sg;
            for my $type (keys %declarations) {
                if($declaration =~ /$type/) { 
                    $self->{case} = $declarations{$type};
                    last;
                }
            }
        } else {
            $p->unget_token($token);
        }

        while( my $tag = $p->get_tag(   
                    # list taken from http://www.w3schools.com/tags/default.asp
                    'a', 'abbr', 'acronym', 'address', 'applet', 'area', 
                    'b', 'base', 'basefont', 'bdo', 'big', 'blockquote', 'body', 'br', 'button', 
                    'caption', 'center', 'cite', 'code', 'col', 'colgroup', 
                    'dd', 'del', 'dfn', 'dir', 'div', 'dl', 'dt', 
                    'em', 
                    'fieldset', 'font', 'form', 'frame', 'framset', 
                    'head', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr', 'html', 
                    'i', 'iframe', 'img', 'input', 'ins', 
                    'kbd', 
                    'label', 'legend', 'li', 'link', 
                    'map', 'menu', 'meta', 
                    'noframes', 'noscript', 
                    'object', 'ol', 'optgroup', 'option', 
                    'p', 'param', 'pre', 
                    'q', 
                    's', 'samp', 'script', 'select', 'small', 'span', 'strike', 'strong', 'style', 'sub', 
                    'table', 'tbody', 'td', 'textarea', 'tfoot', 'th', 'thead', 'title', 'tr', 'tt',
                    'u', 'ul', 
                    'var',
                                    
                    '/form'

                ) ) {

            if($tag->[0] eq uc $tag->[0]) {
                if($self->{case} == 1) {
                    push @{ $self->{ERRORS} }, {
                        error => "tag <$tag->[0]> should be lowercase", 
                        message => "W3C recommends use of lowercase in HTML 4 (<$tag->[0]>)" . ($FIXED ? " [row $tag->[2], column $tag->[3]]" : '')
                    };
                } elsif($self->{case} == 2) {
                    push @{ $self->{ERRORS} }, {
                        error => "tag <$tag->[0]> must be lowercase", 
                        message => "declaration requires lowercase tags (<$tag->[0]>)" . ($FIXED ? " [row $tag->[2], column $tag->[3]]" : '')
                    };
                }
                $tag->[0] = lc $tag->[0];
            }

            if($tag->[0] eq 'form') {
                %form = ( id => ($tag->[1]{id} || $tag->[1]{name}) );
            } elsif($tag->[0] eq '/form') {
                if(!$form{submit}) {
                    push @{ $self->{ERRORS} }, {
                        error => "missing submit in <form>", 
                        message => 'no submit button in form (' . ( $form{id} || '' ) . ')' . ($FIXED ? " [row $tag->[2], column $tag->[3]]" : '')
                    };
                }
            } elsif($tag->[0] eq 'input') {
                $form{submit} = 1   if($tag->[1]{type} && $tag->[1]{type} eq 'submit');

                # not sure about this, need to verify
                #if($tag->[1]{type} eq 'text' && $tag->[1]{id} && $tag->[1]{name} && $tag->[1]{id} ne $tag->[1]{name}) {
                #    push @{ $self->{ERRORS} }, {
                #        error => "id/name do not match in <$tag->[0]> tag", 
                #        message => "id/name mis-match in <$tag->[0]> tag ($tag->[1]{id}/$tag->[1]{name})"
                #    };
                #}

                if($tag->[1]{id}) {
                    if($input{ $tag->[1]{id} }) {
                        push @{ $self->{ERRORS} }, {
                            error => "dupliate id in <$tag->[0]> tag", 
                            message => "all <$tag->[0]> tags require a unique id ($tag->[1]{id})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                        };
                    } else {
                        $input{ $tag->[1]{id} }{type}   = $tag->[1]{type};
                        $input{ $tag->[1]{id} }{row}    = $tag->[4];
                        $input{ $tag->[1]{id} }{column} = $tag->[5];
                    }
                } elsif(!$tag->[1]{type} || $tag->[1]{type} !~ /^(hidden|submit|reset|button)$/) {
                    push @{ $self->{ERRORS} }, {
                        error => "missing id in <$tag->[0]> tag", 
                        message => "all <$tag->[0]> tags require an id ($tag->[1]{name})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                    };
                }

            } elsif($tag->[0] eq 'textarea') {
                # not sure about this, need to verify
                #if($tag->[1]{id} && $tag->[1]{name} && $tag->[1]{id} ne $tag->[1]{name}) {
                #    push @{ $self->{ERRORS} }, {
                #        error => "id/name do not match in textarea tag", 
                #        message => "id/name mis-match in textarea tag ($tag->[1]{id}/$tag->[1]{name})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                #    };
                #}

                if($tag->[1]{id}) {
                    if($input{ $tag->[1]{id} }) {
                        push @{ $self->{ERRORS} }, {
                            error => "dupliate id in <$tag->[0]> tag", 
                            message => "all <$tag->[0]> tags require a unique id ($tag->[1]{id})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                        };
                    } else {
                        $input{ $tag->[1]{id} }{type}   = 'textarea';
                        $input{ $tag->[1]{id} }{row}    = $tag->[4];
                        $input{ $tag->[1]{id} }{column} = $tag->[5];
                    }
                } else {
                    push @{ $self->{ERRORS} }, {
                        error => "missing id in <textarea> tag", 
                        message => "all <textarea> tags require an id ($tag->[1]{name})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                    };
                }

            } elsif($tag->[0] eq 'select') {
                # not sure about this, need to verify
                #if($tag->[1]{id} && $tag->[1]{name} && $tag->[1]{id} ne $tag->[1]{name}) {
                #    push @{ $self->{ERRORS} }, {
                #        error => "id/name do not match in <select> tag", 
                #        message => "id/name mis-match in <select> tag ($tag->[1]{id}/$tag->[1]{name})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                #    };
                #}

                if($tag->[1]{id}) {
                    if($input{ $tag->[1]{id} }) {
                        push @{ $self->{ERRORS} }, {
                            error => "dupliate id in <$tag->[0]> tag", 
                            message => "all <$tag->[0]> tags require a unique id ($tag->[1]{id})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                        };
                    } else {
                        $input{ $tag->[1]{id} }{type}   = 'select';
                        $input{ $tag->[1]{id} }{row}    = $tag->[4];
                        $input{ $tag->[1]{id} }{column} = $tag->[5];
                    }
                } else {
                    push @{ $self->{ERRORS} }, {
                        error => "missing id in <$tag->[0]> tag", 
                        message => "all <$tag->[0]> tags require an id ($tag->[1]{name})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                    };
                }

            } elsif($tag->[0] eq 'label') {
                if($tag->[1]{for}) {
                    if($label{ $tag->[1]{for} }) {
                        push @{ $self->{ERRORS} }, {
                            error => "dupliate for in <$tag->[0]> tag", 
                            message => "all <$tag->[0]> tags should reference a unique id ($tag->[1]{for})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                        };
                    } else {
                        $label{ $tag->[1]{for} }{type}   = 'label';
                        $label{ $tag->[1]{for} }{row}    = $tag->[4];
                        $label{ $tag->[1]{for} }{column} = $tag->[5];
                    }
                } else {
                    push @{ $self->{ERRORS} }, {
                        error => "missing 'for' attribute in <$tag->[0]> tag", 
                        message => "all <$tag->[0]> tags must reference an <input> tag id" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
                    };
                }

            } elsif($tag->[0] eq 'img') {
                $self->_check_image($tag);
            } elsif($tag->[0] eq 'a') {
                $self->_check_link($tag);
            } elsif($tag->[0] =~ /^(i|b)$/) {
                $self->_check_format($tag);

            } elsif($tag->[0] =~ /^(map|object)$/) {
                $self->_check_title($tag);

            } elsif($tag->[0] eq 'table') {
                $self->_check_title_summary($tag);
                $self->_check_width($tag);
                $self->_check_height($tag);
            } elsif($tag->[0] =~ /^(th|td)$/) {
                $self->_check_width($tag);
                $self->_check_height($tag);
            }
        }

        for my $input (keys %input) {
            next    if($input{$input}{type} && $input{$input}{type} =~ /hidden|submit|reset|button/);
            next    if($label{$input});

            push @{ $self->{ERRORS} }, {
                error => "missing label for <input> tag", 
                message => "all <input> tags require a unique <label> tag ($input)" . ($FIXED ? " [row $input{$input}{row}, column $input{$input}{column}]" : '')
            };
        }

        for my $input (keys %label) {
            next    if($input{$input});

            push @{ $self->{ERRORS} }, {
                error => "missing input for <label> tag", 
                message => "all <label> tags should reference a unique <input> tag ($input)" . ($FIXED ? " [row $label{$input}{row}, column $label{$input}{column}]" : '')
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

# -------------------------------------
# Private Methods : Check Routines

sub _check_image {
    my ($self,$tag) = @_;
    
    return  if(defined $tag->[1]{alt});

    push @{ $self->{ERRORS} }, {
        error => "missing alt from <$tag->[0]> tag", 
        message => "no alt attribute in <$tag->[0]> tag ($tag->[1]{src})" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
    };
}

sub _check_link {
    my ($self,$tag) = @_;
    
    return  unless(defined $tag->[1]{href} && !defined $tag->[1]{title});

    push @{ $self->{ERRORS} }, {
        error => "missing title from <$tag->[0]> tag", 
        message => "no title attribute in a tag ($tag->[1]{href}, '$tag->[3]')" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
    };
}

sub _check_format {
    my ($self,$tag) = @_;

    my %formats = (
        'i' => 'em',
        'b' => 'strong'
    );

    return  unless($formats{$tag->[0]});

    push @{ $self->{ERRORS} }, {
        error => "<$formats{$tag->[0]}> tag is preferred over <$tag->[0]> tag", 
        message => "Use CSS for presentation effects, or use <$formats{$tag->[0]}> for emphasis not <$tag->[0]> tag" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
    };
}

sub _check_title {
    my ($self,$tag) = @_;
    
    return  if(defined $tag->[1]{title});

    push @{ $self->{ERRORS} }, {
        error => "missing title from <$tag->[0]> tag", 
        message => "no title attribute in <$tag->[0]> tag" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
    };
}

sub _check_title_summary {
    my ($self,$tag) = @_;
    
    return  if(defined $tag->[1]{title} || defined $tag->[1]{summary});

    push @{ $self->{ERRORS} }, {
        error => "missing title/summary from <$tag->[0]> tag", 
        message => "no title or summary attribute in <$tag->[0]> tag" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
    };
}

sub _check_width {
    my ($self,$tag) = @_;
    
    return  unless($self->{level} > 1);
    return  unless(defined $tag->[1]{width} && $tag->[1]{width} =~ /^\d+$/);

    push @{ $self->{ERRORS} }, {
        error => "absolute units used in width attribute for <$tag->[0]> tag", 
        message => "use relative (or CSS), rather than absolute units for width attribute in <$tag->[0]> tag" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
    };
}

sub _check_height {
    my ($self,$tag) = @_;
    
    return  unless($self->{level} > 1);
    return  unless(defined $tag->[1]{height} && $tag->[1]{height} =~ /^\d+$/);

    push @{ $self->{ERRORS} }, {
        error => "absolute units used in height attribute for <$tag->[0]> tag", 
        message => "use relative (or CSS), rather than absolute units for height attribute in <$tag->[0]> tag" . ($FIXED ? " [row $tag->[4], column $tag->[5]]" : '')
    };
}

# -------------------------------------
# Private Methods : Other

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

=item level(LEVEL)

Level of compliance required to be checked. Valid levels are: 1 (A Level), 2
(AA Level) and 3 (AAA Level). Default level is 1. Invalid level are ignored.

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

