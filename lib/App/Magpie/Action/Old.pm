use 5.012;
use strict;
use warnings;

package App::Magpie::Action::Old;
# ABSTRACT: old command implementation

use Moose;
use Path::Tiny;

use App::Magpie::Action::Old::Module;
use App::Magpie::Action::Old::Set;

with 'App::Magpie::Role::Logging';
with 'App::Magpie::Role::RunningCommand';


=method run

    my @old = $old->run;

Return the list of Perl modules with a new version available on CPAN.

=cut

sub run {
    my ($self) = @_;
    my %category;

    my $outfile = path( "/tmp/cpan-o.stdout" );
    if ( $ENV{MAGPIE_REUSE_CPAN_O_OUTPUT} ) {
        $self->log( "re-using cpan -O output from $outfile" );
    } else {
        my $cmd = "cpan -O >$outfile 2>/tmp/cpan-o.stderr";
        $self->log( "running: $cmd" );
        system("$cmd") == 0
            or $self->log_fatal( "command [$cmd] exited with value " . ($?>>8) );
    }
    my @lines = $outfile->lines;

    # A file where will we store ignored / rejected lines from cpan -O
    # output
    my $rejfh  = path( "/tmp/cpan-o.rej" )->openw;
    my $noline = 0;

    # analyze "cpan -O" output - meaningful lines are of the form:
    # DBIx::Class::Helper::ResultSet::Shortcut::Columns  2.0160  2.0170
    LINE:
    foreach my $line ( @lines ) {
        $noline++;
        if ( $line !~ /
            ^       # begins with
            (\S+)   # anything non-whitespace (module name)
            \s+     # followed by some spaces
            (       # followed by an alternative
                v?(?:\d\S+)   # either sthg beginning with a digit (prefixed with optional v)
                |
                undef         # or litteral undef
            )
            \s+     # followed by some spaces
            (       # followed by an alternative
                v?(?:\d\S+)   # either sthg beginning with a digit (prefixed with optional v)
                |
                undef         # or litteral undef
            )
            $       # and an end of line
            /x ) {
            $rejfh->print( "$noline:$line" );
            next;
        }
        my ($modname, $oldver, $newver) = ($1,$2,$3);
        my $module = App::Magpie::Action::Old::Module->new(
            name => $modname, oldver => $oldver, newver => $newver );

        my $category = $module->category;
        $category{ $category } //= App::Magpie::Action::Old::Set->new(name=>$category);
        $category{ $category }->add_module( $module );
    }

    return values %category;
}



1;
__END__

=head1 SYNOPSIS

    my $old = App::Magpie::Action::Old->new;
    my @old = $old->run;


=head1 DESCRIPTION

This module implements the C<old> action. It's in a module of its own
to be able to be C<require>-d without loading all other actions.

