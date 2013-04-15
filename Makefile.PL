use 5.010001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Mojolicious::Plugin::Nexmo',
    VERSION_FROM      => 'lib/Mojolicious/Plugin/Nexmo.pm',
    PREREQ_PM         => {},
    ABSTRACT_FROM     => 'lib/Mojolicious/Plugin/Nexmo.pm',
    AUTHOR            => 'Andrey Khozov <avkhozov@googlemail.com>',
    META_MERGE => {
	resources => {
	    repository => 'http://github.com/avkhozov/Mojolicious-Plugin-Nexmo',
	    bugtracker => 'http://github.com/avkhozov/Mojolicious-Plugin-Nexmo/issues',
	    license => 'http://dev.perl.org/licenses/'
        }
    }
);
