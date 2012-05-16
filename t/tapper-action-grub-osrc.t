use strict;
use warnings;
use 5.010;

#################################################
#                                               #
# This test checks whether messages in order    #
# are handled correctly.                        #
#                                               #
#################################################

use Test::More;
use English '-no_match_vars';
use Tapper::Schema::TestTools;
use Test::Fixture::DBIC::Schema;
use Tapper::Model 'model';

use Log::Log4perl;

my $string = "
log4perl.rootLogger           = DEBUG, root
log4perl.appender.root        = Log::Log4perl::Appender::Screen
log4perl.appender.root.stderr = 1
log4perl.appender.root.layout = SimpleLayout";
Log::Log4perl->init(\$string);

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/testrun_with_preconditions.yml' );
# -----------------------------------------------------------------------------------------------------------------

local $ENV{TAPPER_CONFIG_FILE} = "t/tapper.cfg";
Tapper::Config->_switch_context();

use_ok('Tapper::Action');

my $output;


# this eval makes sure we even try to stop the daemon when a test dies
eval {
        $output = `$EXECUTABLE_NAME -Ilib bin/tapper-action-daemon start`;
        is($output, '', 'Start without error');

        $output =  `$EXECUTABLE_NAME -Ilib bin/tapper-action-daemon status`;
        like($output, qr/Running:\s+yes/, 'Daemon is running');

        my $message = model('TestrunDB')->resultset('Message')->new({type => 'action',
                                                                     message => {action => 'updategrub',
                                                                                 host   => 'bullock',
                                                                                }});
        $message->insert;

        diag "Wait some seconds to give daemon time to work...";
        sleep 10;
        ok(-e '/tmp/bullock.lst', 'Grub file was copied');
};


$output = `$EXECUTABLE_NAME -Ilib bin/tapper-action-daemon stop`;
is($output, '', 'Stop without error');



done_testing;
