package Tapper::Action;
BEGIN {
  $Tapper::Action::AUTHORITY = 'cpan:AMD';
}
{
  $Tapper::Action::VERSION = '4.0.1';
}
# ABSTRACT: Tapper - Daemon and plugins to handle MCP actions

use 5.010;
use warnings;
use strict;

use Moose;
use Tapper::Model 'model';
use Tapper::Config;
use YAML::Syck 'Load';
use Log::Log4perl;
use Try::Tiny;
use Class::Load ':all';

extends 'Tapper::Base';

has cfg => (is => 'rw', default => sub { Tapper::Config->subconfig} );


sub get_messages
{
        my ($self) = @_;

        my $messages;
        while () {
                $messages = model('TestrunDB')->resultset('Message')->search({type => 'action'});
                last if ($messages and $messages->count);
                sleep $self->cfg->{times}{action_poll_intervall} || 1;
        }
        return $messages;
}


sub run
{
        my ($self) = @_;
        Log::Log4perl->init($self->cfg->{files}{log4perl_cfg});

 ACTION:
        while (my $messages = $self->get_messages) {
                while (my $message = $messages->next) {
                        if (my $action = $message->message->{action}) {
                                my $plugin         = $self->cfg->{action}{$action}{plugin};
                                my $plugin_options = $self->cfg->{action}{$action}{plugin_options};
                                my $plugin_class   = "Tapper::Action::Plugin::${action}::${plugin}";
                                load_class($plugin_class);

                                if ($@) {
                                        $self->log->error( "Could not load $plugin_class: $@" );
                                } else {
                                        try{
                                                no strict 'refs'; ## no critic
                                                $self->log->info("Call ${plugin_class}::execute()");
                                                &{"${plugin_class}::execute"}($self, $message->message, $plugin_options);
                                        } catch {
                                                $self->log->error("Error occured: $_");
                                        }
                                }
                        }
                        $message->delete;
                }
        }
        return;
}

1; # End of Tapper::Action

__END__
=pod

=encoding utf-8

=head1 NAME

Tapper::Action - Tapper - Daemon and plugins to handle MCP actions

=head1 SYNOPSIS

There are a few actions that Tapper assigns to an external daemon. This
includes for example restarting a test machine that went to sleep during
ACPI tests. This module is the base for a daemon that executes these
assignments.

    use Tapper::Action;

    my $daemon = Tapper::Action->new();
    $daemon->run();

=head1 FUNCTIONS

=head2 get_messages

Read all pending messages from database. Try no more than timeout seconds

@return success - Resultset class containing all available messages

=head2 run

Run the Action daemon loop.

=head1 AUTHOR

AMD OSRC Tapper Team <tapper@amd64.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Advanced Micro Devices, Inc..

This is free software, licensed under:

  The (two-clause) FreeBSD License

=cut

