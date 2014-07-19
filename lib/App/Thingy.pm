package App::Thingy;
use warnings;
use strict;

=head1 NAME

App::Thingy - framework for building command-line tools

=head1 SYNOPSIS

    # build your module with this framework...
    package My::Example;
    use warnings;
    use strict;
    use base qw(App::Thingy);
    sub __init {
        my ($self) = @_;
        # put your object initialization code here
        ...
    }
    sub cmd_default {
	my ($self) = @_;
	$self->run("dog");
    }
    sub cmd__cat {
        my ($self, @args) = @_;
        ...
    }
    sub cmd__dog {
        my ($self, @args) = @_;
        ...
    }
    sub help__cat {
        # recommended but optional
        { syntax => "cat [FILE ...]",
          description => "concatenate one or more files" };
    }
    sub help__dog {
        { syntax => "dog [FILE ...]",
          description => "condogenate one or more files" };
    }
    1;

    # ...and somewhere in your executable program...
    my $foo = My::Example->new();
    $foo->run(@ARGV);

=head1 DESCRIPTION

App::Thingy is a framework for writing command-line tools that are
designed to perform one of many different tasks related to the same
thing (and likely sharing much of the same code) depending on the
first non-option argument (known as a "subcommand") you specify.

Plenty of examples of Unix utilities of this kind exist already.  Ones
you might be most familiar with are the command-line tools for most
software versioning and revision control systems in use today,
including git(1) and svn(1).

In the following simplified example based on svn(1):

    svn add PATH ...
    svn blame TARGET[@REV] ...
    svn cat TARGET[@REV] ...
    svn checkout URL[@REV] ... [PATH]
    ...

Your hypothetical implementation of the svn(1) command line utility
would have "add", "blame", "cat", "checkout", etc. as subcommands.
For each subcommand you write an object method called something like
cmd__add, cmd__blame, cmd__cat, cmd__checkout, aut cetera.  Each of
those object methods will receive as their arguments any subsequent
arguments one would specify on the command line after the name of the
subcommand (along with the object itself as the first argument).

=head1 BUILDING YOUR CLASS

=head2 Start a subclass of App::Thingy

You begin by creating a subclass of App::Thingy.  Simple enough:

    package My::Example;
    use warnings;		# you're at the VERY least using
    use strict;			# these pragmata, riiiiiiight?
    use base qw(App::Thingy);

    # put stuff documented below here...

    # as with any other module, at the very end of this file...
    1;

Objects in that class will be plain old standard blessed hash
references.

(This particular class, App::Thingy, will not support subclasses of it
created using the L<fields> pragma, or any object framework such as
Moose or Class::MethodMaker.  However, the creation of classes in the
App::Thingy hierarchy designed to work with such things is not outside
the realm of future possibility.  We might call them
App::Thingy::Fields, App::Thingy::Moose, etc.)

=head2 Object initialization

If you need to add extra code to be run when objects are created,
create an object method called __init:

    sub __init {
        my ($self) = @_;
        ...
    }

=head2 Implement Your Subcommands

For each subcommand you implement, just write an object method whose
name starts with "cmd__".

    sub cmd__add {
        my ($self, @paths) = @_;
        foreach my $path (@paths) {
            ...
        }
    }

If you want to implement a command name containing multiple words,
such as:

    $ ./tool give-the-dog-a-bone

    $ ./tool give_the_dog_a_bone

you must use underscores in your instance method's name:

    sub cmd__give_the_dog_a_bone {
        my ($self, @args) = @_;
        ...
    }

App::Thingy will take care of translation between '_' and '-' for you.

=head2 Your Objects And Code

Of course, with very few exceptions explained below, you will also be
able to add additional instance methods, class methods, package
variables, and hash keys of (almost) any name to your class.
App::Thingy itself will not concern itself with them.

=head2 Reserved Names

Avoid instance or class method names, object hash keys, and package
variable names containing the substring "__" that are not documented
here.  Your humble author reserves the right to use those for
App::Thingy internal purposes.

Also, the following method name is reserved:

    - run

=head2 Automatic Help

Also, let it be known that App::Thingy will provide a cmd__help method
for you.  It *should* be good enough most of the time.  You will be
able to invoke the command-line tool you're creating in one of the
following manners:

    $ ./tool help

    $ ./tool help <subcommand>

Should you desire to write a custom help method, you are welcome to do
so.  If you decide to call the parent class's cmd__help, be sure to
take arguments and pass them along like so:

    sub cmd__help {
        my ($self, @args) = @_;
        ...
        $self->SUPER::cmd_help(@args);
        ...
    }

Otherwise your user might type "./tool help give-the-dog-a-bone" and
they won't get help for that subcommand.

Also, for any of your commands that take arguments in some form of
syntax, you will probably want to write a help__<cmd> method in order
to make your tool's online help useful:

    sub help__cat {
        return { syntax      => "[FILE ...]",
                 description => "concatenate one or more files" };
    }

Otherwise, the online help will only be able to mention that a "cat"
command even exists.

Because App::Thingy is not able to determine the syntax of your
cmd__cat automatically, you should provide a syntax as per the above
example.  You do not need to include the command's name in the syntax
string; it will be prepended for you.

Also, because someone typing "./tool help" or "./tool help cat" will
probably want to know what the "cat" command does, you should also
provide a description.

=head1 POSSIBLE FUTURE PLANS FOR App::Thingy

=over 4

=item *

Integration with Getopt::Long.  Maybe Getopt::Std.

=item *

Integration with the L<fields> pragma.

=item *

Integration with object frameworks like Moose and Class::MethodMaker.

=back

=head1 AUTHOR

Darren Embry <dse@webonastick.com>

=cut

use File::Basename qw(basename);

our $__PROGNAME;
BEGIN {
	$__PROGNAME = basename($0);
}

sub new {
	my ($class) = @_;
	my $self = {};
	bless($self, $class);
	if ($self->can("__init")) {
		$self->__init();
	}
	return $self;
}

sub run {
    my ($self, $subcommand, @arguments) = @_;
    if (!defined $subcommand) {
	my $method = $self->can("cmd_default");
	if (!$method) {
	    $self->__die_help("no command specified.\n");
	}
	$self->$method();
    } else {
	my $method = $self->__method($subcommand);
	if (!$method) {
	    $self->__die_help("unknown command '$subcommand'.\n");
	}
	$self->$method(@arguments);
    }
}

sub cmd__help {
	my ($self, $subcommand) = @_;
	if (defined $subcommand) {
		my ($method, $name) = $self->__help_method($subcommand);
		if ($method) {
			my $help = $self->$method();
			my $syntax      = defined $help ? $help->{syntax}      : undef;
			my $description = defined $help ? $help->{description} : undef;
			if (defined $syntax) {
				print("usage: $__PROGNAME $subcommand $syntax\n");
			} else {
				print("usage: $__PROGNAME $subcommand\n");
			}
			if (defined $description) {
				print("$description\n");
			}
		} else {
			$self->__die_help("No specific help for '$name'.\n");
		}
	} else {
		my $subcommand_help_is_available = 0;
		print("usage:\n");
		foreach my $subcommand ($self->__subcommand_list()) {
			my ($method, $name) = $self->__help_method($subcommand);
			if ($method) {
				my $help = $self->$method();
				my $syntax      = defined $help ? $help->{syntax}      : undef;
				my $description = defined $help ? $help->{description} : undef;
				$subcommand_help_is_available = 1;
				if (defined $syntax) {
					print("  * $__PROGNAME $subcommand $syntax\n");
				} else {
					print("  * $__PROGNAME $subcommand\n");
				}
			} else {
				print("    $__PROGNAME $subcommand\n");
			}
		}
		if ($subcommand_help_is_available) {
			print("\n");
			print("For help on each available subcommand (indicated with * above), type:\n");
			print("  $__PROGNAME help <subcommand>\n");
		}
	}
}

sub __subcommand_list {
	my ($self) = @_;
	my @subcommands = do {
		no strict "refs";
		sort map { m{^cmd__} ? $' : () } keys(%{ref($self) . "::"});
	};
	s{^cmd__}{} foreach @subcommands;
	s{_}{-}g    foreach @subcommands;
	return @subcommands;
}

sub __method {
	my ($self, $subcommand) = @_;
	return undef if !defined $subcommand;
	$subcommand = $self->__normalize($subcommand);
	my $method_name = "cmd__$subcommand";
	if (wantarray) {
		return ($self->can($method_name), $subcommand);
	} else {
		return $self->can($method_name);
	}
}

sub __help_method {
	my ($self, $subcommand) = @_;
	return undef if !defined $subcommand;
	$subcommand = $self->__normalize($subcommand);
	my $method_name = "help__$subcommand";
	if (wantarray) {
		return ($self->can($method_name), $subcommand);
	} else {
		return $self->can($method_name);
	}
}

sub __normalize {
	my ($self, $subcommand) = @_;
	$subcommand =~ s{\-}{_}g;
	return $subcommand;
}

sub __warn {
	my ($self, @args) = @_;
	warn("$__PROGNAME: " . join("", @args));
}

sub __die {
	my ($self, @args) = @_;
	die("$__PROGNAME: " . join("", @args));
}

sub __die_help {
	my ($self, @args) = @_;
	$self->__warn(@args);
	$self->__die("Type '$__PROGNAME help' for help.\n");
}

1;

