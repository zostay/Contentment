package Contentment::Catalog;

use strict;
use warnings;

our $VERSION = '0.04';

use base qw( Class::Singleton Exporter );

use Readonly;

Readonly our $FEATURELESS    =>    0x0;
Readonly our $SEARCH         =>    0x1;
Readonly our $LIST_TERMS     =>    0x2;
Readonly our $FREEFORM_TERMS =>    0x4;
Readonly our $SUBTERMS       =>    0x8;
Readonly our $TERM_LINKS     =>   0x10;
Readonly our $SYNONYMS       =>   0x20;
Readonly our $QUANTITATIVE   =>   0x40;
Readonly our $REVERSE        =>   0x80;
Readonly our $SCORE          =>  0x100;
Readonly our $EDIT           =>  0x200;

our @EXPORT_FEATURES = qw(
    $FEATURELESS
    $SEARCH
    $LIST_TERMS
    $FREEFORM_TERMS
    $SUBTERMS
    $TERM_LINKS
    $SYNONYMS
    $QUANTITATIVE
    $REVERSE
    $SCORE
    $EDIT
);

our @EXPORT_QUANTITATIVE_TYPES = qw(
    $INTEGER
    $FLOAT
    $DATETIME
);

our @EXPORT_OK = (
    @EXPORT_FEATURES,
    @EXPORT_QUANTITATIVE_TYPES,
);

our %EXPORT_TAGS = (
    features => \@EXPORT_FEATURES,
    types    => \@EXPORT_QUANTITATIVE_TYPES,
);

=head1 NAME

Contentment::Catalog - Provides categorization and indexing features

=head1 SYNOPSIS

  # Get a list of the available indexes
  my @indexes = $context->catalog->indexes;

  for my $index (@indexes) {

      # Get a list of avilable terms
      my @terms = $index->terms;

      for my $term (@terms) {

          # Get a list of generators
          my @generators = $index->generators;

      }
      
  }

=head1 DESCRIPTION

One frequently controversial component of a CMS is the categorization system. Contentment attempts to avoid this problem by providing a framework for building categorization systems so that any controversy just leads to the replacement of whatever system someone doesn't like.

That is, rather than create some all encompassing categorization system or some dead-simple one that your grandma who thinks the boogey-man is going to jump out of the her CD-ROM drive can use, you can have either or both or neither depending upon your need. Thus, instead of providing a category or taxonomy system, Contentment provides the indexing system, which allows you to implement whatever category system you prefer.

=head2 HOW DOES IT WORK?

Instead of trying codify how you content should be classified, this system merely codifies how a classification system works. This is done via three basic classes of objects: an Indexer, an Index, and a Term.

=head2 INDEXERS

If you just want to use the system and you really don't care how the guts work, skip to the next section, L</"INDEXES">. 

Any implementation of a categorization system starts with an indexer. The index basically tells L<Contentment::Catalog> what indexes are available. See L<Contentment::Indexer> for details on implementing one.

=head2 INDEXES

By using the C<indexes()> or C<index()> method of L<Contentment::Catalog>, you fetch all available indexes or a single named index, respectively. The purpose of the index is to describe a set of terms. The way terms are described depends on the type of index.

=head2 TERMS

A term is a textual string name, which may have synonyms or other properties. It may have subterms. Primarily, a term will refer to zero or more generators.

Please see L<Contentment::Term> for the methods a term provides.

=head2 METHODS

=over

=cut

sub new {
    my $class = shift;
    return bless {}, $class;
}

=index $catalog->register_indexer($indexer)

Register the indexer plugin, C<$indexer>. The object given must conform to the interface documented in L<Contentment::Indexer>.

=cut

sub register_indexer {
    my $self = shift;
    push @{ $self->{indexers} }, shift;
}

=item @indexes = $catalog->indexes

=item @indexes = $catalog->indexes(@features)

Retrieves all indexes known to the system and returns it in C<@indexes> (which might be empty if none are registered).

If the optional C<@features> argument is passed, only indexes having I<all> of the features specified will be returned:

  # Fetch all the indexes that are reversible and have subterms
  my @revsub_indexes = $context->catalog->indexes($REVERSIBLE | $SUBTERMS);

=cut

sub indexes {
    my $self     = shift;
    my $features = shift;

    my @indexes;
    for my $indexer (@{ $self->{indexers} }) {
        push @indexes, $indexer->indexes;
    }

    if (defined $features) {
        return grep { ($features & $_->features) == $features } @indexes;
    }

    else {
        return @indexes;
    }
}

=item $named_index = $catalog->index($name)

Search for an index by name.

=cut

sub index {
    my ($self, $name) = @_;
    my ($index) = grep { $_->name eq $name } $self->indexes;
    return $index;
}

=item @terms = $catalog-E<gt>search_terms(@strings)

Given a set of strings, this method should return an array of terms that match any of the given strings.

If there are no matches, the method should return an empty list.

=cut

sub search_terms {
    my $self = shift->instance;

    my @indexes = $self->indexes($SEARCH);
    my @terms;
    for my $index (@indexes) {
        push @terms, $index->search(@_);
    }

    return @terms;
}

=item @generators = $catalog-E<gt>search(@strings)

Given a set of strings, this method should return an array of generators linked to terms matched by any of the given strings.

If there are no matches, the method should return an empty list.

=cut

sub search {
    my $self = shift->instance;

    my @terms = $self->search_terms(@_);
    my @generators;
    for my $term (@terms) {
        push @generators, $term->generators;
    }

    return @generators;
}

=back

=head2 CONTEXT

=over

=item $catalog = $context-E<gt>catalog

Returns an instance of the Contentment catalog object.

=cut

sub Contentment::Context::catalog {
    my $self = shift;
    return defined $self->{catalog} ? $self->{catalog} :
        Contentment::Exception->throw(message => "Catalog is not available.");
}

=back

=head2 HOOKS

=over

=item Contentment::Catalog::begin

The hook runs when the plugin is first initialized. The handlers are passed the context as the single argument. It is intended that plugins with indexers can use this hook to call C<register_indexer()>:

  sub my_index_registrar {
      my $ctx = shift;
      $ctx->catalog->register_indexer(Contentment::MyPlugin::Indexer->instance);
  }

=back

=head2 HOOK HANDLERS

=over

=item Contentment::Catalog::begin

This handler runs via the "Contentment::begin" hook and calls the "Contentment::Catalog::begin" hook. It also configures the context object.

=cut

sub begin {
    my $context = shift;
    $context->{catalog} = Contentment::Catalog->new;
    Contentment::Hooks->call("Contentment::Catalog::begin", $context);
}

=back

=head1 AUTHOR

Andrew Sterling Hanenkamp, E<lt>hanenkamp@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2005 Andrew Sterling Hanenkamp E<lt>hanenkamp@cpan.orgE<gt>.  All 
Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut

1
