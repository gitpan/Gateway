# Makefile.PL for News::Gateway module
# $Id: Makefile.PL,v 0.8 1997/12/25 10:27:57 eagle Exp $
use ExtUtils::MakeMaker;

# We want to automatically detect and make a list of all add-on modules in
# the modules directory at the time of installation.  That's what this sub
# does.  It returns a list of module and install location pairs, where the
# install location is relative to $(INST_LIBDIR).
sub find_modules {
    opendir (MODULES, 'modules')
        or die "Cannot find modules directory: $!\n";
    map { 'modules/' . $_, '$(INST_AUTODIR)/' . $_ }
        grep { !/^\./ && $_ ne 'RCS' }
            readdir MODULES;
}

# Now write out the actual Makefile using that information.
my $modules = {
    'News/Gateway.pm' => '$(INST_LIBDIR)/Gateway.pm',
    'News/Gateway.pod' => '$(INST_LIBDIR)/Gateway.pod',
    find_modules
};
WriteMakefile (
    NAME         => 'News::Gateway',
    DISTNAME     => 'Gateway',
    MAN3PODS     => { 'News/Gateway.pod' =>
                      '$(INST_MAN3DIR)/News::Gateway.3' },
    PL_FILES     => { 'makepod.PL' => 'News/Gateway.pod',
                      'makepm.PL'  => 'News/Gateway.pm' },
    PM           => $modules,
    PREREQ_PM    => { 'News::Article' => 1.07 },
    VERSION_FROM => 'News/Gateway.in',
    dist         => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    realclean    => { FILES => 'News/Gateway.pod News/Gateway.pm' }
);
