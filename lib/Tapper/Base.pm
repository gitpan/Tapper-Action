package Tapper::Base;
BEGIN {
  $Tapper::Base::AUTHORITY = 'cpan:TAPPER';
}
{
  $Tapper::Base::VERSION = '4.1.1';
}
# ABSTRACT: Tapper - Common functions for all Tapper classes

use Moose;
use Fcntl;
use LockFile::Simple;

use common::sense;

use 5.010;

with 'MooseX::Log::Log4perl';


sub kill_instance
{
        my ($self, $pid_file) = @_;

        # try to kill previous incarnations
        if ((-e $pid_file) and open(my $fh, "<", $pid_file)) {{
                my $pid = do {local $\; <$fh>}; # slurp
                ($pid) = $pid =~ m/(\d+)/;
                last unless $pid;
                kill 15, $pid;
                sleep(2);
                kill 9, $pid;
                close $fh;
        }}
        return 0;

}


sub run_one
{
        my ($self, $conf) = @_;

        my $command  = $conf->{command};
        my $pid_file = $conf->{pid_file};
        my @argv     = @{$conf->{argv} // [] } ;

        $self->kill_instance($pid_file);

        return qq(Can not execute "$command" because it's not an executable) unless -x $command;
        my $pid = fork();
        return qq(Can not execute "$command". Fork failed: $!) unless defined $pid;

        if ($pid == 0) {
                exec $command, @argv;
                exit 0;
        }

        return 0 unless $pid_file;
        open(my $fh, ">", $pid_file) or return qq(Can not open "$pid_file" for pid $pid:$!);
        print $fh $pid;
        close $fh;
        return 0;
}




sub makedir
{
        my ($self, $dir) = @_;
        return 0 if -d $dir;
        if (-e $dir and not -d $dir) {
                unlink $dir;
        }
        system("mkdir","-p",$dir) == 0 or return "Can't create $dir:$!";
        return 0;
}



sub log_and_exec
{
        my ($self, @cmd) = @_;
        my $cmd = join " ",@cmd;
        $self->log->debug( $cmd );
        my $output=`$cmd 2>&1`;
        my $retval=$?;
        if (not defined($output)) {
                $output = "Executing $cmd failed";
                $retval = 1;
        }
        chomp $output if $output;
        if ($retval) {
                return ($retval >> 8, $output) if wantarray;
                return $output;
        }
        return (0, $output) if wantarray;
        return 0;
}

1; # End of Tapper::Base

__END__
=pod

=encoding utf-8

=head1 NAME

Tapper::Base - Tapper - Common functions for all Tapper classes

=head1 SYNOPSIS

 package Tapper::Some::Class;
 use Moose;
 extends 'Tapper::Base';

=head1 FUNCTIONS

=head2 kill_instance

Kill the process whose id is in the given pidfile.

@param string - pid file name

@return success - 0
@return error   - error string

=head2 run_one

Run one instance of the given command. Kill previous incarnations if necessary.

@param hash ref - {command  => command to execute,
                   pid_file => pid file containing the ID of last incarnation,
                   argv     => array ref containg (optional) arguments}

@return success - 0
@return error   - error string

=head2 makedir

Checks whether a given directory exists and creates it if not.

@param string - directory to create

@return success - 0
@return error   - error string

=head2 log_and_exec

Execute a given command. Make sure the command is logged if requested and none
of its output pollutes the console. In scalar context the function returns 0
for success and the output of the command on error. In array context the
function always return a list containing the return value of the command and
the output of the command.

@param string - command

@return success - 0
@return error   - error string
@returnlist success - (0, output)
@returnlist error   - (return value of command, output)

=head1 AUTHOR

AMD OSRC Tapper Team <tapper@amd64.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Advanced Micro Devices, Inc..

This is free software, licensed under:

  The (two-clause) FreeBSD License

=cut

