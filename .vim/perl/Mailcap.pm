# File Name: Mailcap.pm
# Maintainer: Moshe Kaminsky <kaminsky@math.huji.ac.il>
# Last modified: Sat 20 Nov 2004 09:52:55 PM IST
###########################################################

=pod

=head1 NAME

Mailcap - Manipulate and access mailcap information

=head1 SYNOPSIS

    # procedural interface
    use Mailcap qw(getView getCompose);

    # get the command to compose the plain text document foo.txt
    $cmd = getCompose { 1 } 'text/plain', 'foo.txt';
    system($cmd);

    # get the command to view bar.html on a terminal
    $cmd = getView { $_->needsterminal } 'text/html', 'bar.html';

    # get the description of the application/x-dvi content type
    print Mailcap::description('application/x-dvi');

    # object oriented interface
    use Mailcap;

    # create a new object representing all entries that run
    # on a terminal
    $mc = new Mailcap sub { $_->needsterminal }, @Mailcap::MAILCAPS;

    # same as above
    $cmd = $mc->getCompose('text/plain', 'foo.txt');
    $cmd = $mc->getView('text/html', 'bar.html');

    # print mailcap lines corresponding to the entries.
    $mc->dump;

See the documentation of each method for more examples.

=head1 DESCRIPTION

This module provides facilities for dealing with mailcap information. It 
provides two classes, I<Mailcap::Entry> that represents the data contained in 
one line of a mailcap file, and I<Mailcap>, a class that controls lists of 
I<Mailcap::Entry> objects, typically produced by reading some mailcap files.

The module also provides a procedural interface, to interact with the default 
settings (as described in B<rfc1254>).

=head2 EXPORT

None by default. All routines described below may be exported by request, as 
well as the configuration variables.

=cut

package Mailcap::Entry;

=pod

=head2 The I<Mailcap::Entry> class

This class represents a line in a mailcap file. This includes regular mailcap 
lines, as well as comments and empty lines. It implements methods for testing 
conditions on the mailcap entry, useful in the various filters used in the 
I<Mailcap> class.

=cut

use integer;
use warnings::register;
use overload qq("") => as_string, fallback => 1;

=pod

Each entry consists of several fields. These are either the fields that 
appear in the mailcap line, or meta fields. The fields that appear in a 
mailcap line have precisely the name with which they appear. The meta field 
names start with C<:>. In addition to the prescribed fields, any field 
starting with C<x-> can appear. Field names are case insensitive.

These are the meta types:

=over

=item :type

The main part of the content type (eg C<text>).

=item :subtype

The subtype part of the content type (eg, C<html>).

=item :view

The view command template

=item :comment

If this is defined, the object represents a comment rather than a genuine 
mailcap line. The value of the field is the comment line itself. Note that it 
may be defined but empty (false), for empty lines.

=item :file

The file from which this entry was created.

=item :linewidth

The width of the mailcap line corresponding to this entry. If the actual line 
is longer than this, the line is broken into several lines. This is used when 
stringifying the entry.

=back

=cut

# rfc1524
our @Fields = qw(
    :type
    :subtype
    :view
    edit
    compose
    composetyped
    x11-bitmap
    copiousoutput
    needsterminal
    nametemplate
    description
    test
    print
    textualnewlines
    :comment
    :file
    :linewidth
);

# possible values for the main part of the type
our @Types = qw(
    application
    audio
    image
    message
    multipart
    text
    video
);

our (%Field, %Type);
@Field{@Fields} = @Fields;
@Type{@Types} = @Types;

=pod

=head3 Methods of I<Mailcap::Entry>

The following methods are available:

=over

=cut

sub carp {
    warnings::warnif(@_);
}

=pod

=item Mailcap::Entry::new

        $entry = new Mailcap::Entry 
            'text/html; lynx -stdin -dump; copiousoutput',
            '/etc/mailcap';

        $entry = new Mailcap::Entry { 
            type => 'text', 
            ':view' => 'less',
            needsterminal => 1 };

Create a new object. If the first argument is a hash ref, it is taken to be a 
list of values for the fields of the entry. Otherwise, the first argument 
should be a mailcap line. The second argument will specify the mailcap file 
from which this line comes, and any extra arguments are interpreted as a list 
of field names and values, possibly overriding the data of the mailcap line.

=cut

sub new {
    my $class = shift;
    my $self = bless {} => $class;
    return $self unless @_;
    my $arg = shift;
    if ( ref($arg) ) {
        $self->field($_, $arg->{$_}) foreach keys %$arg;
        $self->field(':linewidth' => $Mailcap::LineWidth)
            unless $self->field(':linewidth');
    } else {
        $self->setString($arg);
        $self->field(':linewidth' => length $arg);
        $self->field(':file' => shift) if @_;
        $self->field(@_) if @_;
    };
    $self
}

=pod

=item field

        $file = $entry->field(':file');

        $entry->field(edit => 'vim %s', needsterminal => 1);

Get or set the value of fields. With one argument, return the value of that 
field. With more than one argument, set fields to corresponding values. 
Returns the list of old values.

=cut

sub field {
    my $self = shift;
    my @ret = ();
    while (@_) {
        my $field = shift;
        local $_ = lc $field;
        $self->carp("'$field' is not a legal mailcap field") 
            unless ($Field{$_} or /^x-$Mailcap::TOKEN/o or /^:/o );
        push @ret, $self->{$_};
        if ( @_ ) {
            my $val = shift;
            if ( $_ eq ':type' ) {
                $val = lc $val;
                $self->carp("Illegal type field '$val'") 
                unless ( $Type{$val} or $val =~ /^x-$Mailcap::TOKEN/o );
            } elsif ( $_ eq ':comment' ) {
                $self->carp("'$val' is not a legal comment")
                unless ( $val =~ /^#/o or $val =~ /^\s*$/o );
            }
            $self->{$_} = $val;
        }
    }
    wantarray ? @ret : $ret[0];
}

=pod

=item type

=item subtype

=item comment

Return or set the corresponding meta field to the given values.

=cut

for my $field ( qw( type subtype comment ) ) {
    *$field = sub { shift->field(":$field", @_) };
}

=pod

=item isComment

Returns true if entry is a comment.

=cut

sub isComment { defined scalar shift->comment }

=pod

=item copiousoutput

=item needsterminal

=item description

=item nametemplate

Return the value of the corresponding field.

=cut

for my $field ( qw( copiousoutput needsterminal description nametemplate) ) {
    *$field = sub { shift->field($field, @_) };
}

=pod

=item typefield

        $full = $entry->typefield;

        $entry->typefield('text/html');

with no arguments: get the full content type of the entry. With a content 
type string as an argument: set the C<:type> and C<:subtype> fields of the 
entry according to the given string.

=cut

sub typefield {
    my $self = shift;
    my $ret = $self->type;
    $ret .= '/' . ($self->subtype() || '*') if (defined $ret);
    if ( @_ ) {
        my $type = shift;
        my $subtype = ( $type =~ s{/($Mailcap::TOKEN|\*)}{}o ) ? $1 : '*';
        $self->type( $type );
        $self->subtype( $subtype );
    }
    $ret;
}

=pod

=item setString

Set the fields of the entry according to the given mailcap string.

=cut

sub setString {
    my $self = shift;
    chomp(local $_ = shift);
    %$self = ();
    if ( /^#/o or /^\s*$/o ) {
        # a comment or a blank line
        $self->field(':comment' => $_);
        return;
    }
    local @_ = split $Mailcap::FIELDSEP;
    $self->typefield( shift );
    $self->field( ':view' => shift );
    foreach ( @_ ) {
        # the set of field names is more restricted than 'token', but we make 
        # the check inside the field() method
        if ( /($Mailcap::TOKEN)=($Mailcap::MTEXT)/o ) {
            $self->field($1, $2);
        } else {
            $self->field($_, 1);
        }
    }
    $self;
}

=pod

=item as_string

Return a mailcap line representing this entry. This method implements the 
stringifying operator for this class. Can optionally be called with a line 
width argument, overriding the value of L</":linewidth">.

=cut

sub as_string {
    my $self = shift;
    my $width = shift || $self->{':linewidth'};
    return $self->{':comment'} if $self->{':comment'};
    my $res = $self->typefield;
    my $len = length $res;
    my $catfield = sub {
        my $field = shift;
        my $lf = length $field;
        $res .= '; ';
        $len += 2;
        if ( $len + $lf < $width or $len <= 4 ) {
            $res .= $field;
            $len += $lf;
        } else {
            $res .= "\\\n    $field";
            $len = 4 + $lf;
        }
    };
    &$catfield($self->{':view'});
    foreach ( keys %$self ) {
        next if /^:/o;
        no warnings 'numeric';
        if ( $self->{$_} == 1 ) {
            &$catfield($_);
        } else {
            &$catfield("$_=" . $self->{$_});
        }
    }
    $res
}

=pod

=item isProper

Return true if the content type is proper, ie, has a real subtype and not a 
wildcard.

=cut

sub isProper { my $sub; defined($sub = shift->subtype()) and $sub ne '*' }

=pod

=item isStdin

        $stdin = $entry->isStdin('edit');

Returns true if the given field reads from stdin (or writes to stdout). This 
happens iff the value of the field does not contain the C<%s> sequence. If 
the field name is dropped, defaults to C<:view>.

=cut

sub isStdin {
    my $self =  shift;
    my $field = shift || ':view';
    Mailcap::isStdin($self->field($field));
}

=pod

=item matches

        $entry->matches('text/html; charset=utf-8');
        # true if the cotent type of $entry is 'text/html' or
        # 'text/*'

Return true if the content type of the entry matches the given content type.

=cut

sub matches {
    my $self = shift;
    return 0 if defined $self->comment;
    my $ftype = shift;
    return 1 unless $ftype;
    $ftype = lc $ftype;
    $ftype =~ s/;.*//o;
    my ($type, $subtype) = split /\s*\/\s*/, $ftype;
    $type eq $self->type() and (not $self->isProper() or 
                                $self->subtype() eq $subtype);
}

=pod

=item getCmd

        $cmd = $entry->getCmd(':view', 'foo.txt');

Get the command for the field given as the first argument. The rest of the 
arguments are like the same as for L</"interpolate"> (but the C<:redir> and 
the C<:term> fields are deduced from the command). If only the first argument 
is given, returns the template. If no arguments are given, defaults to 
C<:view>. If the requested command is not described by this entry, returns 
C<undef>.

=cut

sub getCmd {
    my $self = shift;
    my $cmd = lc shift || ':view';
    $cmd = ':view' if $cmd eq 'view';
    my $template = $self->field( $cmd );
    return $template unless ($template and @_);
    unshift @_, 's' if @_ < 2;
    my %args = @_;
    $args{':redir'} = ( $args{':redir'} || ' > ' )
        if ( $cmd eq 'compose' or $cmd eq 'composetyped' or $cmd eq 'test' );
    if ( $self->needsterminal ) {
        $args{':term'} = '' unless exists $args{':term'};
    } else {
        delete $args{':term'};
    }
    return Mailcap::interpolate($template, %args);
}

=pod

=item test

        $ok = $entry->test(%args);

Perform the test for this entry, applied to the given arguments (as for 
L</"interpolate">. Returns true if the test is successful or if there is no 
test field for this entry.

=cut

sub test {
    my $self = shift;
    my $cmd = $self->getCmd('test', @_);
    return $cmd ? (system($cmd) == 0) : 1;
}

=pod

=back

=cut

=pod

=head2 The I<Mailcap> class

The I<Mailcap> class represents a list of mailcap entries. For an object 
C<$mc> of this class, C<@$mc> is gives the list of entries. Each entry is, by 
default, an object of class I<Mailcap::Entry>, but this can be altered by 
changing L</"$Mailcap::NewEntry"> to create something else (with the same 
interface), or by deriving from I<Mailcap> and overriding the L</"newEntry"> 
method.

=cut

package Mailcap;

use integer;
use warnings::register;
use strict;
use overload '@{}' => 'entries', fallback => 1;
use Exporter;
use base qw(Exporter);

use File::Spec::Functions;
use UNIVERSAL qw(isa);

use subs qw(readFile);

use vars qw($LineWidth $Filter $NewEntry $TERM @MAILCAPS);

our %EXPORT_TAGS = ( 'all' => [ qw(
    entries
    pushFiles
    unshiftFiles
    firstEntry
    getCmd
    getView
    getEdit
    getCompose
    getPrint
    description
    dump
    $LineWidth
    $Filter
    $NewEntry
    @MAILCAPS
    mailcaps
    MAILCAP
    readFile
    isStdin
    interpolate
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(	
);

our $VERSION = '0.01';    

#### some constants ####

# The character that separates two entries in a path. Should be able to get 
# it from one of the File::* thingies, but where?
my %PATHSEP = ( MSWin32 => ';', MacOS => ',' );
my $PATHSEP = $PATHSEP{$^O} || ':';

## Syntactic elements of a line, according to the various RFCs. Don't know if 
## there is actual reason to make it 'our', but there's no harm either.
#
# A 'token' according to rfc1521
our $TOKEN = qr{[^()<>@,;:\\"/\[\]?=\s[:cntrl:]]*};
# 'mtext' according to rfc1524
our $MTEXT = qr/(?:[^;\\[:cntrl:]]|\\.)*/;
# 'quoted-string', rfc822
our $QSTRING = qr/"([^"\\[:cntrl:]]|\\.)*"/;
# The re on which we split a mailcap line into fields, and also a 
# content-type value. Unfortunately, look-behind is implemented only for 
# fixed width patterns, so this will not work in the (unlikely) case that the 
# ; is preceded by an even, >0 number of backslashes. (TODO)
our $FIELDSEP = qr/\s*(?<=[^\\]);\s*/;

#### methods/subs

=pod

=head3 Methods of I<Mailcap>

Each method of this class can also be called as a regular sub (see examples 
in the L</"SYNOPSIS">). If this happens, a default object is used, created 
with the list in L</"@Mailcap::MAILCAPS"> as the files.

=over

=cut

sub getSelf (\@);

sub carp {
    warnings::warnif(@_);
}

=pod

=item Mailcap::new

        $mc = new Mailcap [I<file1>, ...]

        $mc = new Mailcap I<code>, [I<file1>, ...]

        $mc = new Mailcap I<args>, [I<file1>, ...]

Create a new Mailcap object. Each Mailcap object represents a list of mailcap 
entries (lines in a mailcap file). Each of I<file1> and the following 
parameters should be paths of mailcap files (either one file or several files 
separated by the system path separator). The L</"pushFiles"> method of the 
object will be called with this list of files. Alternatively, each such 
argument can be an open file handle.

If a coderef I<code> is given, it becomes the L</'filter'> field of this 
object, see L</"pushFiles"> for details.

If, on the otherhand, a hash ref I<args> is given, it should contain the 
values for the objects parameters. The recognized parameters are:

=over

=item C<'entries'>

A listref of entries controlled by this object. Each entry is an object of 
type B<Mailcap::Entry> (or any other object with the same interface). 
Normally this is empty, and constructed from the I<file> arguments. In any 
case, if the I<file> arguments are given, their entries are appended to the 
given ones.

=item C<'filter'>

A coderef used to for filtering the data in the I<file> arguments. Only 
entries for which the given subroutine is true will be included. C<$_> is an 
alias for the object in question inside this sub. The default for this field 
is given in L</$Mailcap::Filter>. For example

        $mc = new Mailcap 
            sub { not $_->isComment },
            '/etc/mailcap'

will create an object that contains all the actual (non-comment) entries in 
F</etc/mailcap>.

=item C<'linewidth'>

The requested width of a mailcap file, in case one is dumped from this 
object. Each line in the resulting file will have this number of characters 
(if possible). If this is false, preserve the length of the original line, or 
use L</$Mailcap::LineWidth> if this is not known. The default is 
L</$Mailcap::LineWidth>.

=item C<'term'>

The terminal to use when running commands with a C<needsterminal> field. 
Default is L</"$Mailcap::TERM">. Set this to C<undef> if the program is 
running in a terminal. See L</"interpolate"> for more details.

=back

=cut

sub new {
    my $class = shift;
    my $self = bless { 
        entries => [],
        filter => $Filter,
        linewidth => $LineWidth,
        term => $TERM,
    } => $class;
    $self->{'newEntry'} = sub { $self->newEntry(shift) };
    my $arg1 = ref($_[0]);
    $self->{'filter'} = shift if $arg1 eq 'CODE';
    if ( $arg1 eq 'HASH' ) {
        my $args = shift;
        @$self{keys %$args} = values %$args;
    }
    $self->pushFiles(@_);
    $self;
}

=pod

=item newEntry

        $entry = $mc->newEntry(I<string>[, I<file>])

Returns a new B<Mailcap::Entry>, constructed via the sub given in 
L</"$Mailcap::NewEntry">, with its L</":linewidth"> field set to C<$self>s 
L</"'linewidth'">. I<string> is a mailcap string from which to create a new 
B<Mailcap::Entry>, and I<file>, if given, is the file where it was found.

This method is not meant to be called directly. Instead, it is used by 
methods like L</"pushFiles"> to add entry objects for mailcap lines.

=cut

sub newEntry {
    my $self = shift;
    my $res = &$NewEntry(@_);
    $res->field(':linewidth' => $self->{'linewidth'}) 
        if $self->{'linewidth'};
    $res
}

=pod

=item entries

        # procedural interface
        $entries = entries;

        # object oriented interface
        $entries = $mc->entries;

        @entries = @$mc;

        # add an entry to $mc
        push @$mc, $entry;

Get a reference to the list entries. This method inplements the B<@{}> 
operator of B<Mailcap>. Note that it is perfectly legal to change modify this 
list, as in the last example.

=cut

sub entries {
    my $self = getSelf(@_);
    $self->{'entries'}
}

sub readFiles {
    my $self = shift;
    @_ = map { ref($_) ? $_ : split /$PATHSEP/o } @_;
    my $filter = $self->{'filter'};
    my $newEntry = sub { $self->newEntry(@_) };
    my ($entries, $files) = ([], []);
    foreach ( @_ ) {
        my @entries = readFile $filter, $_, $newEntry;
        next unless @entries;
        push @$entries, @entries;
        push @$files, $_;
    }
    return $entries, $files;
}

=pod

=item pushFiles

        # procedural interface
        pushFiles('/foo/bar/mailcap');

        # object oriented interface
        $mc->pushFiles('/foo/bar/mailcap');

        # push several files
        pushFiles('/foo/mailcap', '/bar/mailcap');

        # same, but works only on unix:
        pushFiles('/foo/mailcap:/bar/mailcap');

Read all entries in the given files, produce a new entry object for each, 
filter them using the L</"'filter'"> field, and add these entries to the list 
of entries. Each argument can be either a file name, several such names 
joined with the system path separator, or an open file handle.

For each line in the file, the L</"newEntry"> method is called to with that 
line to create a new entry. The entry is then passed to to the sub given by 
the L</'filter'> field. If this sub returns a true value, the entry is added 
to the list of entries.

If any entry from a file is added to the list of entries, the file name is 
added to the C<files> field.

=cut

sub pushFiles {
    my $self = getSelf(@_);
    my ($entries, $files) = $self->readFiles(@_);
    push @{$self->{'entries'}}, @$entries;
    push @{$self->{'files'}}, @$files;
    $self
}

=pod

=item unshiftFiles

Same as L</pushFiles>, but entries (and file names) are added to the 
beginning, rather than end, of the entry list.

=cut

sub unshiftFiles {
    my $self = getSelf(@_);
    my ($entries, $files) = $self->readFiles(@_);
    unshift @{$self->{'entries'}}, @$entries;
    unshift @{$self->{'files'}}, @$files;
    $self
}

=pod

=item firstEntry

        $entry = firstEntry 'text/plain', sub { $_->copiousoutput };

        # object oriented interface
        $entry = $mc->firstEntry('text/html; charset=latin1');

Get the first entry in the list of entries for the given type, and for which 
the given code is true. Inside the code, C<$_> is an alias for the entry to 
be examined. If the code is omitted, match any entry for the given type. If 
no entry satisfying the conditions exists, returns C<undef>.

In list context, returns the list of all entries matching the conditions.

=cut

sub firstEntry {
    my $self = getSelf(@_);
    my $type = shift;
    my $code = shift || sub { 1 };
    my @entries = grep { $_->matches($type) and &$code } @$self;
    wantarray ? @entries : shift @entries;
}

=pod

=item getCmd

        $cmd = getCmd { $_->needsterminal } ':view', 
                      'application/pdf', 'foo.pdf';

        $cmd = $mc->getCmd('compose', 'text/html; charset=utf-8', 
                           s => 'bar.html', n => 1);

Returns a string with the command to perform the given action for the given 
file using the first entry that matches the type, the given code and the 
B<test> parameter. The code is optional in the object oriented interface, but 
not in the procedural one. In list context, returns the commands for all 
matching entries.

The arguments after the content type are interpreted as follows: If there is 
one argument, it is taken to be the file name (substituted for the B<%s> 
sequence in the command). If there is more than one, it is taken to be a list 
of named parameters, the key being the the sequence letter to replace, and 
the value the replacement. There is no need to specify the B<t> key, though - 
it will taken from the type argument if not given. See L</"interpolate"> for 
a fuller explanation of the flags.

=cut

sub getCmd (&@) {
    my $self = getSelf(@_);
    my $filter = shift;
    unless ( ref($filter) eq 'CODE' ) {
        unshift @_, $filter;
        $filter = sub { 1 };
    }
    my $cmd = shift;
    my $type = shift;
    my %args = @_ == 1 ? ( s => shift ) : @_;
    $args{'t'} = $type unless exists $args{'t'};
    $args{':term'} = $self->{'term'} unless exists $args{':term'};
    my @entries = $self->firstEntry( $type, sub { 
            $_->field($cmd) and   # this entry has the given command
            &$filter and          # the user specified filter matches
            $_->test(%args)       # the entry matches the test, if any
        });
    if ( wantarray ) {
        (\@entries, map { $_->getCmd($cmd, %args) } @entries);
    } else {
        my $entry = shift @entries;
        return undef unless $entry;
        $entry->getCmd($cmd, %args);
    }
}

sub _callGetCmd {
    my $self = shift;
    my $cmd = shift;
    $self->getCmd(ref($_[0]) eq 'CODE' ? shift : (), $cmd, @_);
}

=pod

=item getView

        $cmd = getView { 1 } 'text/html', 'foo.html';

        $cmd = $mc->getView(sub { $_->copiousoutput }, 
                            'text/plain', 'bar.txt');

Get the B<view> command for the given content type, satisfying the given 
code, for the given file. The code is optional for the object oriented 
interface. The arguments after the content type are interpreted the same as 
in L</"getCmd">.

=cut

sub getView (&@) {
    my $self = getSelf(@_);
    $self->_callGetCmd(':view', @_);
}

=pod

=item getEdit

Same as L</"getView">, but for the B<edit> command.

=cut

sub getEdit (&@) {
    my $self = getSelf(@_);
    $self->_callGetCmd('edit', @_);
}

=pod

=item getCompose

Same as L</"getView">, but for the B<compose> command.

=cut

sub getCompose (&@) {
    my $self = getSelf(@_);
    $self->_callGetCmd('compose', @_);
}

=pod

=item getPrint

Same as L</"getView">, but for the B<print> command.

=cut

sub getPrint (&@) {
    my $self = getSelf(@_);
    $self->_callGetCmd('print', @_);
}

=pod

=item description

        $desc = description('text/html');

        $desc = $mc->description('text/html');

Get the description of the given content type.

=cut

sub description {
    my $self = getSelf(@_);
    $self->getCmd('description', shift);
}

=pod

=item nametemplate

        $name = nametemplate('text/html');
        # got '%s.html'

        $name = $mc->nametemplate('text/html', 'foo');
        # got 'foo.html';

Get the nametemplate for the given content type.

=cut

sub nametemplate (@) {
    my $self = getSelf(@_);
    $self->getCmd('nametemplate', @_);
}

=pod

=item dump

        @lines = dump { not $_->isComment };

        $mc->dump;

In void context, prints the mailcap lines for the entries. Otherwise, returns 
the lines in a list. If the code is given, print or return only lines for 
entries matching the code.

=cut

sub dump(;&) {
    my $self = getSelf(@_);
    my $filter = shift;
    my @entries = @$self;
    @entries = grep { &$filter } @entries if $filter;
    if ( defined wantarray ) {
        return map { "$_\n" } @entries;
    } else {
        print "$_\n" foreach @entries;
    }
}
    
=pod

=back

=cut

=pod

=head3 Configuration

The following variables affect the operation of the module. They set the 
defaults used for newly created I<Mailcap> object, and thus also for the 
fixed object used for the procedural interface. Note that to affect the 
behavoir of the procedural interface in this way, the variables should be set 
B<before> any of these subs is used.

=over

=cut

=pod

=item $Mailcap::LineWidth

The default width of a mailcap line, when printing or otherwise representing 
an entry as a string. This is only a recommendation - lines will be broken 
only on the C<;> separating mailcap fields.

Note that a I<Mailcap> object has a field L</"'linewidth'">. The value of 
this field is what actually is used, and the value of this variable is the 
default value for the field (and in particular, it is the value for the 
procedural interface).

Default value is C<76>.

=cut

our $LineWidth = 76;

=pod

=item $Mailcap::Filter

The default filter to use when adding mailcap files. Only entries from the 
file for which this code returns a true value will be taken. C<$_> inside the 
sub is an alias to the entry object.

As with L</"$Mailcap::LineWidth">, this is only the default value for the 
L</"'filter'"> field of a I<Mailcap>.

Default value is C<sub { 1 }>.

=cut

our $Filter = sub { 1 };

=pod

=item $Mailcap::NewEntry

Code to be used for creating a new entry. The input of this method is a 
mailcap line, and optionally the mailcap file name from which it is taken. It 
should return an object with the same interface as I<Mailcap::Entry>.

Setting this method allows one to provide a new class instead of the default 
I<Mailcap::Entry>, without overriding I<Mailcap>.


The default is C<sub { new Mailcap::Entry @_ }>.

=cut

our $NewEntry = sub { new Mailcap::Entry @_ };

=pod

=item $Mailcap::TERM

The terminal command to use for entries with the C<needsterminal> field. 
Should be set to C<undef> is the program is running in a terminal. If the 
variable is defined, an C<%s> sequence in it will be replaced with the 
command to run. If there is no C<%s> sequence, adds the command to the end. 
See L</"interpolate"> for details.

The default is C<$TERM -e %s>, where C<$TERM> is the value of the C<TERM> 
environment variable, defaulting to B<xterm> if it is not set.

=cut

our $TERM = (defined $ENV{'TERM'} ? $ENV{'TERM'} : 'xterm') . ' -e %s';

=pod

=item @Mailcap::MAILCAPS

The list of mailcap files to use by default. This is used only when 
constructing the default object for the procedural interface. Each item in 
the list is a string, with a list of files separated by the system's path 
separator. Note that if the separator is actually used (ie, there is more 
than one file in any of the list items), this becomes system dependent.

Alternatively, members of this list can also be open file handles.

The default is the value if the C<MAILCAPS> environment variable, if it is 
set, otherwise it is
C<qw($HOME/.mailcap /etc/mailcap /usr/etc/mailcap /usr/local/etc/mailcap)>

=cut

our @MAILCAPS;

if ( exists $ENV{'MAILCAPS'} ) { 
    @MAILCAPS = ( $ENV{'MAILCAPS'} );
} else {
    @MAILCAPS = map { catfile(rootdir, @$_) } (
            [qw(etc mailcap)],
            [qw(usr etc mailcap)],
            [qw(usr local etc mailcap)],
        );
    unshift @MAILCAPS, catfile($ENV{'HOME'}, '.mailcap') 
        if defined $ENV{'HOME'};
}

=pod

=back

=cut

#######

=pod

=head3 Utility functions

The following routines are not methods - they are mostly subroutines that 
perform low level functionality used by the classes. However, they might be 
useful on their own right.

=over

=cut

sub isHandle {
    ref($_[0]) or $_[0] =~ /^GLOB\(0x[0-9a-f]+\)$/o
}

=pod

=item mailcaps

This function returns the content of L</"@Mailcap::MAILCAPS"> in one of two 
canonical forms: In list context, a list of file names is returned (each item 
will have exactly one file). In scalar context, the list of files joined by 
the path separator is returned.

=cut

sub mailcaps {
    wantarray ? map { isHandle($_) ? $_ : split /$PATHSEP/ } @MAILCAPS 
              : join($PATHSEP, @MAILCAPS)
}

our $MAILCAP;

=pod

=item MAILCAP

Returns the default I<Mailcap> object used for the procedural interface.

=cut

sub MAILCAP () {
    $MAILCAP = new Mailcap mailcaps() unless defined $MAILCAP;
    $MAILCAP
}

=pod

=item readFile

        @entries = readFile { 1 } '/etc/mailcap';

        @entries = readFile { not $_->isComment } '/etc/mailcap', 
                            sub {...};

Read the mailcap file given by the second argument, and return a list entries 
representing its contents, filtered using the code given in the first 
argument. If a third argument is given, it should be a coderef, to be used 
for creating an entry. The arguments to this code are the mailcap line and 
the name of the file from which it is taken. The default is 
L</"$Mailcap::NewEntry">.

=cut

sub readFile {
    my $filter = shift;
    my $file = shift;
    my $newEntry = shift || $NewEntry;
    my $MC;
    if ( isHandle($file) ) {
        $MC = $file;
    } else {
        open $MC, $file or return;
    }
    my @entries;
    while ( <$MC> ) {
        $_ .= <$MC> while s/\\$//o;
        push @entries, &$newEntry($_, $file);
    }
    @entries = grep { &$filter } @entries if $filter;
    return @entries;
}

sub getSelf (\@) {
    my $args = shift;
    my $self;
    if ($args and @$args and ref $args->[0] and 
        UNIVERSAL::isa($args->[0], 'Mailcap') ) {
        $self = shift @$args;
    } else {
        $self = MAILCAP();
    }
    $self
}

=pod

=item isStdin

        $test = isStdin '/usr/bin/less';
        # true

        $test = isStdin '/usr/bin/less %s';
        # false

Returns true if the given command template does not contain the C<%s>  
sequence.

=cut

sub isStdin {
    return shift !~ /(^|[^\\](?:\\\\)*)%s/o;
}

sub escape {
    my $char = shift;
    my $str = shift;
    $str =~ s/$char/\\$char/g;
    $str
}

=pod

=item interpolate

        $cmd = interpolate '/usr/bin/xpdf %s', 'foo.pdf';
        # $cmd is '/usr/bin/xpdf foo.pdf'

        $cmd = interpolate 
            'lynx -assume-charset=%{charset} -stdin', 
            s => 'bar.html', t => 'text/html; charset=utf-8';
        # $cmd is "( lynx -assume-charset=utf-8 -stdin ) <'bar.html'"

        $cmd = interpolate 
            'lynx -assume-charset=%{charset} -stdin', 
            s => 'bar.html', t => 'text/html; charset=utf-8',
            ':term' => 'xterm -e';
        # $cmd is: 
        # xterm -e "( lynx -assume-charset=utf-8 -stdin ) <'bar.html'"
        
This function takes a command template, as may be given in the view field of 
a mailcap line, and substitution values for the sequence that may occur in 
the command, and produces a command that may be server, eg, to C<system>.

If only one argument is given after the template, it is taken to be the file 
name (substituted for C<%s>). Otherwise, the arguments should be pairs 
matching a substitution letter to its value. If the C<F> flag is given, but 
the C<n> flag is not, it is deduced from the number of elements in the value 
of C<F>.

If a value for C<s> is given, but C<%s> does not appear in the template, it 
is assumed that the command reads from the standard input or writes to the 
standard output, and the command will be produces accordingly. To determine 
whether it should read from stdin or write to stdout, the special key 
C<:redir> is checked in the arguments. If this key is defined its value is 
used as a redirection sign (thus it should be C<E<gt>> for writing to 
stdout). If it is not defined, C<E<lt>> is assumed.

If the value of the key C<:term> is defined, it is used as terminal command 
using which the command should be run. An C<%s> sequence in the value will be 
replaced by the command, in double quotes. If there is no C<%s>, it will be 
added to the end of that value. If the value is empty (or otherwise false but 
defined), the value of L</"$Mailcap::TERM"> will be used.

=cut

sub interpolate {
    my $template = shift;
    my %flags = @_ > 1 ? @_ : ( s => shift );
    if ( defined $flags{'t'} ) {
        @_ = split $FIELDSEP, $flags{'t'};
        $flags{'t'} = shift;
        foreach ( @_ ) {
            # TODO: what about header field comments?
            $flags{"{\L$1\E}"} = $2 if /($TOKEN)=($TOKEN|$QSTRING)/o;
        }
    }
    if ( defined $flags{'F'} and ref($flags{'F'}) ) {
        my @files = keys %{$flags{'F'}};
        $flags{'n'} = @files unless defined($flags{'n'});
        $flags{'F'} = join ' ', 
            map { sprintf("'%s' '%s'", $flags{'F'}->{$_}, $_) } @files;
    }
    my $stdin = 1;
    my $replace = sub {
        my $key = shift;
        $stdin = 0 if $key eq 's';
        return $flags{$key} if defined $flags{$key};
        carp "A replacement for \%$key is not supplied, using ''";
        return '';
    };
    $template =~ 
        s/(^|[^\\](?:\\\\)*)%([[:alpha:]]|\{$TOKEN\})/$1 . &$replace($2)/ge;
    if ( $stdin and $flags{'s'} ) {
        $template = "( $template ) " . 
                    ( $flags{':redir'} || '<' ) . "'" . 
                    escape("'", $flags{'s'}) . "'";
    }
    if ( defined(my $term = $flags{':term'}) ) {
        $term = $TERM unless $term;
        $term .= ' %s' if isStdin($term);
        $template = sprintf($term, '"' . escape('"', $template) . '"');
    }
    return $template;
}

=pod

=back

=cut

1;

=head1 WARNINGS

If warnings are on, the module may emit several warnings, as described below. 
These may be turned of using the keywords I<Mailcap> and I<Mailcap::Entry>, 
depending on the warning. For example:

        no warnings 'Mailcap';
        # do something
        use warnings 'Mailcap';

=over

=item A replacement for %D is not supplied, using ''

(I<Mailcap>) The module is trying to produce a command from some template 
that contains the given sequence C<%D>, but the value for this sequence is 
not given. This warning is produced by L</"interpolate">.

=item '%s' is not a legal mailcap field

(I<Mailcap::Entry>) the L</"field"> method was called to set the value of a 
field which is not a meta field, and is not a valid field according to 
B<rfc1524> (Namely, it is not one of the fixed field names, and does not 
start with C<x->).

=item Illegal type field '%s'

(I<Mailcap::Entry>) The L</"field"> method was called to set the primary type 
for the entry, but the value is not one of the allowed values according to 
B<rfc1524>.

=item '%s' is not a legal comment

(I<Mailcap::Entry>) The L</"field"> method was called to set the C<:comment> 
meta field, but the given value is not a legal mailcap comment.

=back

=head1 FILES

The default list of mailcap files, as described in rfc1524, is:

=over

=item *

F<$HOME/.mailcap>

=item *

F</etc/mailcap>

=item *

F</usr/etc/mailcap>

=item *

F</usr/local/etc/mailcap>

=back

=head1 SEE ALSO

B<rfc1524>, B<mailcap(4)>, B<mailcap(5)> (whichever is installed), 
B<metamail(1)>

=head1 AUTHOR

Moshe Kaminsky <kaminsky@math.huji.ac.il> - Copyright (c) 2004

=head1 LICENSE

This library is free software. You may copy or redistribute it under the same 
terms as Perl itself.

=cut
