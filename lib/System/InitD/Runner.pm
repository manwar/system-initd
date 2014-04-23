package System::InitD::Runner;

use strict;
use warnings;
use Carp;
use System::Process;
use POSIX;

sub new {
    my ($class, %params) = @_;
    my $self = {};

    if (!$params{start}) {
        croak "start param is required";
    }

    if (!$params{usage}) {
        croak 'Usage must be specified';
    }

    if ($params{daemon_name}) {
        $self->{daemon_name} = $params{daemon_name};
    }

    # if (ref $params{usage} eq 'CODE') {
    #     *{__PACKAGE__::usage} = $params{usage};
    # }
    else {
        $self->{_text}->{usage} = $params{usage};
    }

    $self->{_commands} = {
        start   =>  $params{start},
        stop    =>  $params{stop},
    };

    if ($params{restart_timeout}) {
        $self->{_args}->{restart_timeout} = $params{restart_timeout};
    }

    if ($params{pid_file}) {
        $self->{pid} = System::Process::pidinfo(
            file    =>  $params{pid_file}
        );
    }

    if ($params{kill_signal}) {
        $self->{_args}->{kill_signal} = $params{kill_signal};
    }

    if ($params{process_name}) {
        $self->{_args}->{process_name} = $params{process_name};
    }

    bless $self, $class;
    return $self;
}


sub run {
    my $self = shift;
    unless ($ARGV[0]) {
        $self->usage();
        return 1;
    }

    if ($self->can($ARGV[0])) {
        my $sub = $ARGV[0];
        $self->$sub();
    }
    else {
        $self->usage();
    }
    return 1;
}


sub start {
    my $self = shift;

    # TODO: Add command check
    my $command = $self->{_commands}->{start}->{cmd};

    if ($self->is_alive()) {
        print "Daemon already running\n";
        return;
    }
    my @args = @{$self->{_commands}->{start}->{args}};
    system($command, @args);
    return 1;
}


sub stop {
    my $self = shift;

    if ($self->{pid}) {
        my $signal = $self->{kill_signal} // POSIX::SIGTERM;
        $self->{pid}->kill($signal);
    }
    return 1;
}


sub restart {
    my $self = shift;

    $self->stop();

    if (my $t = $self->{_args}->{restart_timeout}) {
        sleep $t;
    }

    $self->start();
    return 1;
}


sub status {
    my $self = shift;

    unless ($self->{pid}) {
        print "Daemon is not running";
        exit 0;
    }

    if ($self->is_alive()) {
        print "Daemon already running";
    }

    exit 0;
}


sub usage {
    my $self = shift;

    print $self->{_text}->{usage}, "\n";
    return 1;
}


sub is_alive {
    my $self = shift;
    return 0 unless $self->{pid};

    return 1 if $self->{_args}->{process_name} eq $self->{pid}->command() && $self->{pid}->cankill();

    return 0;
}


sub load {
    my ($self, $subname, $subref) = @_;

    if (!$subname || !$subref) {
        croak 'Missing params';
    }

    croak 'Subref must be a CODE ref' if (ref $subref ne 'CODE');

    no strict 'refs';
    *{__PACKAGE__ . "\::$subname"} = $subref;
    use strict 'refs';

    return 1;
}

1;

__END__