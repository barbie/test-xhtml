use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'              => 'Test-XHTML',
    'VERSION_FROM'	    => 'lib/Test/XHTML.pm',
    'PREREQ_PM'         => {
        'Class::Accessor::Fast' => 0,
        'Data::Dumper'          => 0,
        'File::Basename'        => 0,
        'File::Find::Rule'      => 0,
        'File::Path'            => 0,
        'HTML::TokeParser'      => 0,
        'IO::File'              => 0,
        'Test::Builder'         => 0,
        'Test::More'            => '0.70',
        'WWW::Mechanize'        => 0,
        'XML::LibXML'           => '1.70',
        'XML::Catalogs::HTML'   => 0,

        'Getopt::Long'          => 0        # xhtml-valid script only
                        },
    'INSTALLDIRS'       => 'site',
    'EXE_FILES'         => ['bin/xhtml-valid'],
    'NO_META'           => 1,

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT	=> 'Test your web page DTD validation.',
       AUTHOR	=> 'Barbie <barbie@cpan.org>') : ()),
);
