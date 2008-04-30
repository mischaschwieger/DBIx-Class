package DBIx::Class::Storage::DBI::Replicated::Pool;

use Moose;
use MooseX::AttributeHelpers;
use DBIx::Class::Storage::DBI::Replicated::Replicant;
use List::Util qw(sum);

=head1 NAME

DBIx::Class::Storage::DBI::Replicated::Pool; Manage a pool of replicants

=head1 SYNOPSIS

This class is used internally by L<DBIx::Class::Storage::DBI::Replicated>.  You
shouldn't need to create instances of this class.
    
=head1 DESCRIPTION

In a replicated storage type, there is at least one replicant to handle the
read only traffic.  The Pool class manages this replicant, or list of 
replicants, and gives some methods for querying information about their status.

=head1 ATTRIBUTES

This class defines the following attributes.

=head2 replicant_type

Base class used to instantiate replicants that are in the pool.  Unless you
need to subclass L<DBIx::Class::Storage::DBI::Replicated::Replicant> you should
just leave this alone.

=cut

has 'replicant_type' => (
    is=>'ro',
    isa=>'ClassName',
    required=>1,
    default=>'DBIx::Class::Storage::DBI::Replicated::Replicant',
    handles=>{
    	'create_replicant' => 'new',
    },	
);


=head2 replicants

A hashref of replicant, with the key being the dsn and the value returning the
actual replicant storage.  For example if the $dsn element is something like:

    "dbi:SQLite:dbname=dbfile"
    
You could access the specific replicant via:

    $schema->storage->replicants->{'dbname=dbfile'}
    
This attributes also supports the following helper methods

=over 4

=item set_replicant($key=>$storage)

Pushes a replicant onto the HashRef under $key

=item get_replicant($key)

Retrieves the named replicant

=item has_replicants

Returns true if the Pool defines replicants.

=item num_replicants

The number of replicants in the pool

=item delete_replicant ($key)

removes the replicant under $key from the pool

=back

=cut

has 'replicants' => (
    is=>'rw',
    metaclass => 'Collection::Hash',
    isa=>'HashRef[DBIx::Class::Storage::DBI::Replicated::Replicant]',
    default=>sub {{}},
    provides  => {
		'set' => 'set_replicant',
		'get' => 'get_replicant',            
		'empty' => 'has_replicants',
		'count' => 'num_replicants',
		'delete' => 'delete_replicant',
	},
);


=head1 METHODS

This class defines the following methods.

=head2 create_replicants (Array[$connect_info])

Given an array of $dsn suitable for connected to a database, create an
L<DBIx::Class::Storage::DBI::Replicated::Replicant> object and store it in the
L</replicants> attribute.

=cut

sub create_replicants {
	my $self = shift @_;
	
	my @newly_created = ();
	foreach my $connect_info (@_) {
		my $replicant = $self->create_replicant;
		$replicant->connect_info($connect_info);
		$replicant->ensure_connected;
		my ($key) = ($connect_info->[0]=~m/^dbi\:.+\:(.+)$/);
		$self->set_replicant( $key => $replicant);	
		push @newly_created, $replicant;
	}
	
	return @newly_created;
}


=head2 connected_replicants

Returns true if there are connected replicants.  Actually is overloaded to
return the number of replicants.  So you can do stuff like:

    if( my $num_connected = $storage->has_connected_replicants ) {
    	print "I have $num_connected connected replicants";
    } else {
    	print "Sorry, no replicants.";
    }

This method will actually test that each replicant in the L</replicants> hashref
is actually connected, try not to hit this 10 times a second.

=cut

sub connected_replicants {
	my $self = shift @_;
	return sum( map {
		$_->connected ? 1:0
	} $self->all_replicants );
}

=head2 all_replicants

Just a simple array of all the replicant storages.  No particular order to the
array is given, nor should any meaning be derived.

=cut

sub all_replicants {
	my $self = shift @_;
	return values %{$self->replicants};
}


=head1 AUTHOR

John Napiorkowski <john.napiorkowski@takkle.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut


1;