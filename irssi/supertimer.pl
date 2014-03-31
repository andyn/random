use strict;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = '1.0';
%IRSSI =
(
 authors     => 'Mr. Janne Paalijarvi. Google me.',
 contact     => 'usvi@IRCnet',
 name        => 'Timer script with disk backup',
 description => 'Add notification timers for tasks and important things. Adding multiple timers are possible.',
 license     => 'BSD',
 changed     => 'Sun Mar 30 21:19:12 EEST 2014'
);

my $timer_file = Irssi::get_irssi_dir . "/supertimer.dat";
my %timer_list = ();
my $timer_reference = 0;


sub load_timers
{
    open(timer_file_handle, "<", $timer_file);
    my $level = 0;
    my $network = "";
    my $channel = "";
    my $nick = "";
    my $temp_line = "";

    while($temp_line = readline(*timer_file_handle))
    {
	if($temp_line =~ /[ ]*\}[ ]*/)
	{
	    $level--;
	}
	elsif($level == 0)
	{
	    if($temp_line =~ /[ ]*([^ \=]+)[ ]*\=[ ]*\{[ ]*\n/)
	    {
		$network = $1;
		$level++;
		$timer_list{$network} = ();
	    }
	}
	elsif($level == 1)
	{
	    if($temp_line =~ /[ ]*([^ \=]+)[ ]*\=[ ]*\{[ ]*\n/)
	    {
		$channel = $1;
		$level++;
		$timer_list{$network}{$channel} = ();
	    }
	}
	elsif($level == 2)
	{
	    if($temp_line =~ /[ ]*([^ \=]+)[ ]*\=[ ]*\{[ ]*\n/)
	    {
		$nick = $1;
		$level++;
		$timer_list{$network}{$channel}{$nick} = ();
	    }
	}
	elsif($level == 3)
	{
	    if($temp_line =~ /[ ]*([0-9]+)\:([0-9]+)\:(.*)\n/)
	    {
		if(($2 + 0) > time())
		{
		    $timer_list{$network}{$channel}{$nick}{$1} = "$2:$3";
		}
	    }
	}
    }
    close(timer_file_handle);
    sanitize_timers();
}


sub list_timers
{
    my $i = 1;

    for my $network ( keys %timer_list )
    {
        print("Network: " . $network);

        for my $channel ( keys %{$timer_list{$network}})
        {
            print(" Channel: " . $channel);

	    for my $nick ( keys %{$timer_list{$network}{$channel}})
	    {
		print("  Nick: " . $nick);

		foreach(sort(keys(%{$timer_list{$network}{$channel}{$nick}})))
		{
		    print("   $i: " . $_ . ":" . $timer_list{$network}{$channel}{$nick}{$_});
		    $i++;
		}
	    }
        }
    }
}


sub get_next_timeout
{
    my $next_add_time = 3396211122;
    my @timeout_params;

    for my $network ( keys %timer_list )
    {
        for my $channel ( keys %{$timer_list{$network}})
        {
	    for my $nick ( keys %{$timer_list{$network}{$channel}})
	    {
		foreach(sort(keys(%{$timer_list{$network}{$channel}{$nick}})))
		{
		    my $temp_line = $timer_list{$network}{$channel}{$nick}{$_};

		    if($temp_line =~ /([0-9]+)\:(.*)/)
		    {
			if(($1 + 0) < $next_add_time)
			{
			    @timeout_params = ($network, $channel, $nick, $_, $2);
			    $next_add_time = ($1 + 0);
			}
		    }
		}
	    }
        }
    }
    return @timeout_params;
}




sub activate_next_timer
{
    if($timer_reference != 0)
    {
	Irssi::timeout_remove($timer_reference);
	$timer_reference = 0;
    }
    #my ($network, $channel, $nick, $add_time, $2)
    my @timeout_params = get_next_timeout("", "");

    if($timeout_params[0] ne "")
    {
	print("Next timeout in " . ($timeout_params[3] - time()));
	$timer_reference = Irssi::timeout_add_once(10 + ($timeout_params[3] - time()) * 1000, 'announce_timer',
						   ($timeout_params[0], $timeout_params[1], $timeout_params[2], $timeout_params[3], $timeout_params[4]));
    }
}

sub announce_timer
{
    my ($network, $channel, $nick, $add_time, $reason) = @_;
    print("Timeout announced:$reason");
    $timer_reference;
    remove_timer($network, $channel, $nick, $add_time);
    sanitize_timers();
    list_timers();
    activate_next_timer();
}


sub remove_timer
{
    my ($network, $channel, $nick, $add_time) = @_;
    print("Deleting $network, $channel, $nick, $add_time");
    delete($timer_list{$network}{$channel}{$nick}{$add_time});
}


sub sanitize_timers
{
    for my $network ( keys %timer_list )
    {
        for my $channel ( keys %{$timer_list{$network}})
        {
	    for my $nick ( keys %{$timer_list{$network}{$channel}})
	    {
		if(scalar(keys(%{$timer_list{$network}{$channel}{$nick}})) == 0)
		{
		    delete($timer_list{$network}{$channel}{$nick})
		}
	    }
	    if(scalar(keys(%{$timer_list{$network}{$channel}})) == 0)
	    {
		delete($timer_list{$network}{$channel})
	    }
	}
	if(scalar(keys(%{$timer_list{$network}})) == 0)
	{
	    delete($timer_list{$network})
	}
    }
}



Irssi::command_bind("stload", "load_timers");
Irssi::command_bind("stprint", "list_timers");

load_timers();
activate_next_timer();
