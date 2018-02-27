# File Name: Browser.pm
# Maintainer: Moshe Kaminsky <kaminsky@math.huji.ac.il>
# Last modified: Tue 15 Mar 2005 11:28:22 AM IST
###########################################################

############# description of this module ##################
# This module contains most of the implementation of the vim browser plugin.  
# The broad structure is like this:
# 
# * VIM::Browser - This is the main module that controls the overall 
# operation. It is also the only 'public' part: it is the only part used 
# directly in the browser.vim plugin.
#
# * VIM::Browser::Page - A class that represents a web page, or, more 
# generally, the contents of a location. Usually has a buffer associated to 
# it, but the buffer might be hidden.
#
# * VIM::Browser::Window - A class representing a browser window or tab.  
# Loosely corresponds to a vim window. Each such window generally has a Page 
# object associated to it (but the same Page may be associated to more than 
# one window).
#
# * VIM::Browser::AddrBook - A class representing a bookmark file, and 
# provides hash access to it.
#
# * LWP::Protocol::bookmarks - Implements accessing the bookmarks page foo 
# via 'bookmarks://foo/'
#
# * VIM::Browser::HistEvent - Represents one history event (an address 
# accessed at a given time)
#
# * VIM::Browser::History - the global history
#
# * LWP::Protocol::history - impelements accessing the global history via the  
# history:// uri
#
# More detailed description follows below.
##########################################################

###################### bookmark files ####################
# The following class provides access to bookmark files. A hash tied to this 
# class has nicknames as keys. The value for each key is a two element array 
# ref, the first element being the uri, and the second is a description 
# (usually the contents of the 'title' header field for that uri)
package VIM::Browser::AddrBook;
use base 'Tie::Hash';
use Vim qw(debug);
use open ':utf8';

sub TIEHASH {
    my $class = shift;
    my $self = { comment => '', file => shift };
    if ( -r $self->{'file'} ) {
        my $fh;
        unless ( open $fh, $self->{'file'} ) {
            Vim::error("Failed to open $self->{'file'} for reading");
            return undef;
        }
        local $_;
        my $start = 1;
        while ( <$fh> ) {
            if ( $start ) {
                if ( /^#/o ) {
                    $self->{'comment'} .= $_;
                } else {
                    $start = 0;
                }
            }
            next if /^#/o;
            $self->{'mark'}{$1} = [$2, $3] if /^(\w+)\s+(\S+)\s*(.*)$/o;
        }
    }
    bless $self => $class;
}

# re-create the bookmarks file (destroying any prior info)
sub update {
    my $self = shift;
    unless ( open FH, '>' , $self->{'file'} ) { 
        Vim::error("failed to write to $self->{'file'}");
        return undef;
    }
    print FH $self->{'comment'};
    print FH "$_ $self->{'mark'}{$_}[0] $self->{'mark'}{$_}[1]\n"
        foreach keys %{$self->{'mark'}};
    close FH;
    1;
}

# print the bookmarks
sub list {
    my $self = shift;
    VIM::Msg("Bookmarks in $self->{'file'}", 'Type');
    VIM::Msg("$_: $self->{'mark'}{$_}[0] # $self->{'mark'}{$_}[1]")
        foreach keys %{$self->{'mark'}};
}

# the tying routines. Most just do the hash operations on the $self->{'mark'} 
# hash, updating the file when necessary.
sub STORE {
    my ($self, $key, $value) = @_;
    if ( $self->EXISTS($key) ) {
        $self->{'mark'}{$key} = $value;
        $self->update();
    } else {
        # if the key is new, add only it to the bookmark file, thus retaining 
        # any comments
        unless ( open FH, '>>' , $self->{'file'} ) { 
            Vim::error("failed to write to $self->{'file'}");
            return undef;
        }
        print FH "$key $value->[0] $value->[1]\n";
        close FH;
        $self->{'mark'}{$key} = $value;
    }
}

sub FETCH {
    $_[0]->{'mark'}{$_[1]};
}

sub FIRSTKEY {
    my $self = shift;
    my $a = keys %{$self->{'mark'}};
    each %{$self->{'mark'}};
}

sub NEXTKEY {
    each %{ $_[0]->{'mark'} };
}

sub EXISTS {
    exists $_[0]->{'mark'}{$_[1]};
}

sub DELETE {
    delete $_[0]->{'mark'}{$_[1]};
    $_[0]->update();
}

sub CLEAR {
    $_[0]->{'mark'} = {};
    $_[0]->update();
}

sub SCALAR {
    scalar %{$_[0]->{'mark'}};
}


#### Allow uri/lwp access to bookmarks ####
# access bookmarks via bookmark://foo/ uris. We create a response by sending 
# a request for the bookmark _file_, and modifying field apropriately. The 
# important part is setting the content type to 'bookmarks', so that it is 
# formatted apropriately.
package LWP::Protocol::bookmarks;
use base qw(LWP::Protocol);
use Vim qw(debug);
use HTTP::Response;
use HTTP::Status;
use HTTP::Date;

sub request {
    my $self = shift;
    my $request = shift;
    my $uri = $request->uri;
    my $bookmark = $uri->authority;
    debug("bookmark is $bookmark");
    my $book = $VIM::Browser::AddrBook{$bookmark};
    my $response;
    if ( $book ) {
        $response = new HTTP::Response HTTP::Status::RC_OK, '', [
            'Last-Modified' => 
                HTTP::Date::time2str((stat(tied(%$book)->{'file'}))[9]),
            'Content-Type' => 'bookmarks',
            ], $book;
    } else {
        $response = new HTTP::Response HTTP::Status::RC_NOT_FOUND,
                        "No bookmarks file '$bookmark' exists";
    }
    $response->request($request);
    $response
}

# class for one history event. Nothing to exciting: a uri, an access time, 
# and a title, determined heuristically if not given. The < operator is 
# overloaded, for sorting the history list.
package VIM::Browser::HistEvent;
use overload '<' => 'hlt', fallback => 1;
use Data::Dumper;

sub new {
    my $class =shift;
    my $self = bless( { accessed => time, @_ } => $class );
    unless ( $self->{'title'} ) {
        my $auth = $self->uri->authority;
        $auth = 'localhost' if ( not $auth and $self->uri->scheme eq 'file');
        return unless $auth;
        $self->{'title'} = $auth;
    }
    $self
}

for my $method ( qw(accessed uri title) ) {
    *$method = sub {
        shift->{$method}
    }
}

sub actime {
    HTTP::Date::time2str(shift->accessed);
}
    

sub hlt {
    my ($x, $y);
    if ( $_[2] ) {
        $y = shift;
        $x = shift->accessed;
    } else {
        $x = shift->accessed;
        $y = shift;
        $y = $y->accessed if ref($y);
    }
    $x < $y
}

# the history is implemented as a fixed sized ordered array. Each entry is a 
# HistEvent object, and they are ordered by access time. When a new event is  
# added, and the size is exceeded, the oldest one is removed. The following 
# class is used to tie such arrays. In addition, it is associated to a file, 
# where the history is stored.
package VIM::Browser::History;
use UNIVERSAL qw(isa);
use Vim qw(debug);
use Data::Dumper;
use File::Basename;
use URI;
use Carp;
use open ':utf8';

sub TIEARRAY {
    my $class = shift;
    my $self = bless( { 
        events => [],
        accessed => -1,
        size => 30,
        file => shift,
    } => $class);
    VIM::Browser::makedir(dirname($self->{'file'}), 'history');
    if ( open my $IN, $self->{'file'} ) {
        # read events
        while ( <$IN> ) {
            chomp;
            my ($uri, $accessed, $title) = split(/ /, $_, 3);
            $self->PUSH({
                uri => (new URI $uri), 
                accessed => $accessed, 
                title => $title});
        }
    }
    $self
}

sub accessed {
    my $self = shift;
    my $res = $self->{'accessed'};
    $self->{'accessed'} = shift if @_;
    $res
}

sub FETCH {
    my $self = shift;
    $self->{'events'}[shift];
}

sub FETCHSIZE {
    scalar(@{shift->{'events'}});
}

sub size {
    VIM::Browser::setting('history_size', shift->{'size'});
}

sub STORE {
    shift->PUSH(pop);
}

sub STORESIZE {
    my $self = shift;
    $self->{'size'} = shift if @_;
    my $size = scalar(@{$self->{'events'}});
    splice(@{$self->{'events'}}, 0, $size - $self->size) if $size > $self->size;
}

sub CLEAR {
    my $self = shift;
    $self->{'events'}=[];
    $self->accessed(-1);
}

sub binsearch {
    my $array = shift;
    my $element = shift;
    my $lower = shift || 0;
    my $upper = shift || $#$array;
    return $lower if $upper < $lower;
    my $mid = ( $upper + $lower ) / 2;
    return $array->[$mid] <= $element ? 
        binsearch($array, $element, $mid + 1, $upper) :
        binsearch($array, $element, $lower, $mid - 1);
}

sub PUSH {
    my ($self, $event) = @_;
    unless (ref $event and UNIVERSAL::isa($event, 'VIM::Browser::HistEvent')) {
        $event = new VIM::Browser::HistEvent 
            (ref($event) eq 'HASH' ? %$event : (uri => $event));
    }
    return unless $event;
    for my $ind ( 0..$#{$self->{'events'}} ) {
        next unless $self->{'events'}[$ind];
        if ( $self->{'events'}[$ind]->uri eq $event->uri and
             $self->{'events'}[$ind] < $event ) {
            splice(@{$self->{'events'}}, $ind, 1);
            last;
        }
    }
    if ( $self->accessed <= $event->accessed ) {
        push @{$self->{'events'}}, $event;
        $self->accessed($event->accessed);
    } else {
        my $ind = binsearch($self->{'events'}, $event);
        splice(@{$self->{'events'}}, $ind, 0, $event);
    }
    $self->STORESIZE;
}

sub POP {
    my $self = shift;
    my $res = pop @{$self->{'events'}};
    $self->accessed(@{$self->{'events'}} ? $self->{'events'}[-1]->accessed 
                                         : -1);
    $res
}

sub SHIFT {
    my $self = shift;
    my $res = shift @{$self->{'events'}};
    $res
}

sub UNSHIFT {
    $_[0]->PUSH($_[1])
}

sub save {
    my $self = shift;
    open my $OUT, '>:utf8', $self->{'file'} 
        or Vim::warning('Failed to open history file ', $self->{'file'}) 
           and return;
    foreach ( @{$self->{'events'}} ) {
        my $str = sprintf("%s %d %s", $_->uri, $_->accessed, $_->title);
        print $OUT "$str\n";
    }
}

# implements access to the history page via the history:// uri. The main 
# function is to set content type to 'history'.
package LWP::Protocol::history;
use base qw(LWP::Protocol);
use Vim qw(debug);
use HTTP::Response;
use HTTP::Status;
use HTTP::Date;

sub request {
    my $self = shift;
    my $request = shift;
    my $hist = tied @VIM::Browser::History;
    my $event = $request->uri()->authority();
    my $response;
    if ( $event ) {
        # we want a specific event in the global history
        my $n = $hist->FETCHSIZE() - $event;
        my $ev = $VIM::Browser::History[$n];
        if ( defined $ev ) {
            $response = new HTTP::Response HTTP::Status::RC_TEMPORARY_REDIRECT, 
                            '', [ Location => $ev->uri ];
        } else {
            $response = new HTTP::Response HTTP::Status::RC_CONFLICT, 
                            "History event $event does not exist";
        }
    } else {
        # we want the history page
        $response = new HTTP::Response HTTP::Status::RC_OK, '', [
            'Last-Modified' => HTTP::Date::time2str($hist->accessed),
            'Content-Type' => 'history',
            ];
    }
    $response->request($request);
    $response
}

###################### web pages ############################
# VIM::Browser::Page represents one web page. Since most of the work is web 
# page related, this is where it is done.
#############################################################

package VIM::Browser::Page;
use overload '""' => 'as_string', '==' => 'ieq', fallback => 1;
use Encode;
use URI;
use Vim;
use Data::Dumper;
use Carp qw(carp croak verbose);
use warnings;
use open ':utf8';

# arguments for construction: after the class name we have an HTTP::Response, 
# and then pairs of key => value, with values for the various attributes.  
# This list must include at least the keys: buffer, fragment, links, images, 
# markup, type and uri.
sub new {
    my $class = shift;
    my $response = shift;
    my %args = @_;
    ### Fields of a Page
    my $self = {
        # title of the document
        title => undef,
        # the buffer object associated to this page.
        buffer => delete $args{'buffer'},
        # number of extra lines in the bottom of the buffer, not taken 
        # account in the lines of the links and fragments (due to the 
        # addition of headers)
        offset => 0,
        # a hash ref, containing various head fields. The most important ones 
        # are 'encoding', 'content type' and 'uri base'.
        header => undef,
        # a hash ref, containing for each fragment (aka anchor, the name= 
        # argument of an 'a' tag) the line number in the buffer where it 
        # occurs. Line numbers here and in the links field below start from 
        # 0.
        # Initialized by the formatter.
        fragment => delete $args{'fragment'},
        # an array ref, containing, for a number n, the list of links that 
        # occur on line n. Each value is an array ref, each of whose elements 
        # is a hash ref with (at least) the fields 'from' and 'to', 
        # containing the link start and end columns, resp. Form inputs are 
        # also members of these list. If an element contains a field 
        # 'target', it is considered that this link can be followed, and the 
        # value of 'target' is either the destination, or a sub that can be 
        # called with $self, and returns the destination (any legal value for 
        # VIM::Browser::Window::openUri).
        # The form input links are designed as follows: First, there is an 
        # item for every physical entity in the page text. Thus, in contrast 
        # to HTML::Form inputs, there is a distinct item for each radio 
        # button. They generally have 3 fields pointing to subs: 'getval' 
        # gets the value of the input as reflected in the page text (gets the 
        # page as an argument), 'setval' sets the value of the input in the 
        # page (gets the page, and the new value), and 'update' updates the 
        # corresponding input object (from HTML::Form) from the value in the 
        # page (gets the page). The form is stored in the 'form' field, and 
        # the input is stored in the 'input' field.
        # Initialized by the formatter.
        links => delete $args{'links'},
        # the inline images in the page. Structure is the same as the 'links' 
        # field
        images => delete $args{'images'},
        # the markup of the page. Structure the same as the 'links' field, 
        # but each element contains the markup kind ('kind'), the column in 
        # the line ('col'), and a field 'start' which is true iff it's the 
        # start of this markup
        markup => delete $args{'markup'},
        # the raw list of bytes retrieved from the location
        source => undef,
        # the vim file type corresponding to the source. Initialized by the 
        # formatter.
        type => delete $args{'type'},
        # a uri for this page (but note that more than one uri may lead to 
        # the same page due to redirection)
        uri => delete $args{'uri'},
        # an array of window ids displaying this page
        windows => {},
    };
    bless $self => $class;
    if ( $response ) {
        $self->request = $response->request;
        $self->response = $response;
        $self->header = { 
            'expires' => scalar(localtime($response->expires || 0)),
            'last modified' => scalar(localtime($response->last_modified || 0)),
            'content type' => scalar $response->content_type,
            'encoding' => VIM::Browser::getEncoding($response, 1),
            'language' => scalar $response->content_language,
            'server' => scalar $response->server,
            'keywords' => scalar $response->header('X-Meta-Keywords'),
            'description' => scalar $response->header('X-Meta-Description')
        };
        delete $self->header->{$_} 
            foreach grep { not $self->header($_) } keys %{$self->header};
        $self->header->{'uri base'} = VIM::Browser::getBase($response);
        $self->title = $response->title || 
            $self->header->{'uri base'}->authority;
    }
    $self->{$_} = $args{$_} foreach keys %args;
    $self->source = $response->can('decoded_content') ? 
        $response->decoded_content(
            default_charset => $VIM::Browser::AssumedEncoding) : 
        decode($self->header('encoding'), $response->content());
    $self->setSyntax;
    return $self;
}

# provide easy access to the fields

# hashes
for my $field (qw(header fragment windows)) {
    *$field = sub : lvalue {
        my $self = shift;
        @_ ? ( $self->{"$field"}{"@_"} ) : ( $self->{"$field"} );
    };
};

# arrays
for my $field (qw(links images markup)) {
    *$field = sub : lvalue {
        my $self = shift;
        @_ ? $self->{"$field"}[shift] : $self->{"$field"};
    };
};

# scalars
for my $field (qw(type title source offset uri request response)) {
    *$field = sub : lvalue {
        $_[0]->{$field};
    };
};

# return true if the buffer object of this page is associated to an actual 
# vim buffer. Returns undef if the page has no buffer object associated
sub bufAlive {
    my $self = shift;
    return unless $self->{'buffer'};
    my $num = eval { $self->{'buffer'}->Number() };
    return 0 if $@;
    return 0 unless VIM::Eval("bufexists($num)");
    1;
}

# return the vim buffer object for this page, with a sanity check.
sub buffer {
    my $self = shift;
    my $alive = $self->bufAlive;
    if (defined($alive) and not $alive) {
        carp("Using non existing buffer!");
        $self->{'buffer'} = undef;
    }
    $self->{'buffer'};
}

# Two pages are considered equal if they control the same buffer. It should 
# never occur that different pages control the same buffer.
sub ieq {
    $_[0]->buffer->Number == $_[0]->buffer->Number;
}

sub as_string {
    $_[0]->uri;
}

# issue the synmark commands for colorizing the various page constructs.
sub setSyntax {
    my $self = shift;
    my $links = $self->{'links'};
    my $images = $self->{'images'};
    my $markup = $self->{'markup'};
    for my $line ( 1..$self->Count() ) {
        foreach ( @{$links->[$line-1]} ) {
            if ( $_->{'input'} ) {
                my $type = $_->{'input'}->type;
                next if grep { $type eq $_ } qw(text radio textarea);
            }
            next unless ( defined($_->{'from'}) and defined($_->{'to'}));
            my $link = defined($_->{'target'});
            my $target = ($link and not ref $_->{'target'}) ? $_->{'target'} 
                                                            : '';
            my $visited = 
                ($target and $VIM::Browser::URI{$target}) ? 'Followed' : '';
            my $group = $link ? $visited . 'Link' : 'Form';
            # for the sake of performance, use SynMark(Start|End), not 
            # SynMark
            VIM::DoCommand(
                sprintf("SynMarkStart %s %d %d | SynMarkEnd %s %d %d",
                        $group, $_->{'from'} + $link, $line, 
                        # the column will become 0 if the value is INF, which 
                        # turns it to '$/' in synmark
                        $group, $_->{'to'} + 2 - $link, $line));
        }
        foreach ( @{$images->[$line-1]} ) {
            VIM::DoCommand(
                sprintf("SynMarkStart Image %d %d | SynMarkEnd Image %d %d",
                         $_->{'from'}+1, $line,     $_->{'to'}+1, $line));
        }
        foreach ( @{$markup->[$line-1]} ) {
            VIM::DoCommand(sprintf("SynMark%s %s %d %d",
                                   $_->{'start'} ? 'Start' : 'End',
                                   $_->{'kind'},
                                   $_->{'col'} + 1,
                                   $line));
        }
    }
}

# return the line of a given anchor name
sub fragmentLine {
    my $self = shift;
    my $fragment = shift;
    my $fragments = $self->fragment;
    return $fragments->{$fragment}; # + $self->offset;
}

## The document header, showing and removing
sub addHeader {
    my $self = shift;
    return if $self->offset;
    my $header = $self->header;
    my @lines = ( sprintf('Document header: %s {{{', $self->title || '' ) );
    push @lines, "  $_: " . $header->{$_} foreach keys %$header;
    push @lines, "}}}", '';
    @lines = ($self->title ? ( $self->title ) : ()) if ( scalar(@line) == 2 );
    $self->Append($self->Count, @lines);
    $self->offset = scalar(@lines);
}

sub removeHeader {
    my $self = shift;
    my $Offset = $self->offset;
    my $count = $self->Count;
    $self->Delete($count - $Offset + 1, $count) if $Offset;
    $self->offset = 0;
}

# get the line with the given number. Line numbers start from 1
sub getLine {
    my ($self, $line) = @_;
    return $self->Get($line + 1);
    my $Offset = $self->offset;
    $self->buffer->Get($line + $Offset + 1);
}

# set the line with the given number. Line numbers start from 1
sub setLine {
    my ($self, $line, @values) = @_;
    my $Offset = $self->offset;
    Vim::debug("Setting line $line to @values");
    #$self->Set($line + $Offset + 1, @values);
    $self->Set($line + 1, @values);
}

# update the area in the page dedicated to a textarea with the text
sub updateTextArea {
    my ($self, $line, $lines) = @_;
    Vim::debug("Updating textarea on line $line");
    my $link = $self->links($line)->[0];
    chomp (my @text = split /^/, $link->{'input'}->value);
    my $max = scalar(@text) - $lines;
    my $displine = $link->{'displayline'};
    $displine = $max if $displine > $max;
    $displine = 0 if $displine < 0;
    $link->{'displayline'} = $displine;
    splice @text, 0, $displine;
    splice @text, $lines if $max > 0;
    $self->setLine(++$line, @text);
    $line += scalar(@text);
    $lines -= scalar(@text);
    $self->setLine($line++, '') while ( $lines-- );
    1;
}

# return the link in the current cursor location, or undef if there is no 
# link. The returned object is the corresponding hashref in the 'links' 
# field.
# If a true argument is passed, look in the images instead of the links
sub findLink {
    my $self = shift;
    my $list = shift() ? 'images' : 'links';
    my ($row, $col) = Vim::cursor();
    #$row -= $self->offset;
    # no links in the header
    return undef if $row > $self->Count - $self->offset;
    my $links = $self->$list($row-1);
    # avoid warning when the 'from' field is undefined
    no warnings 'uninitialized';
    my @links = grep { $col >= $_->{'from'} and $col <= $_->{'to'} } @$links;
    use warnings 'uninitialized';
    shift @links || undef;
}

# find the next/prev link. Arguments are the direction (1 for next, -1 for 
# prev), and coordinate as returned by Vim::cursor. If an extra true argument 
# is given, search images instead of links.
# Returns the hashref corresponding to the link in the 'links' field, and the 
# line offset from the given line where the link appears (so the link will be 
# on line $row+$offset, where $offset is this offset.
sub findNextLink {
    my ($self, $dir, $row, $col, $images) = @_;
    my $list = $images ? 'images' : 'links';
    #$row -= ($self->offset + 1);
    $row--;
    # we might have been in the header - $offset will compensate for that
    #my $offset = 0;
    #if ( $row < 0 ) {
        #    return undef if $dir < 0;
        #    $offset = $row;
        #$row = $col = 0;
        #}
    # try first in the current line
    my $links = $self->$list($row);
    if ( $links ) {
        if ( $dir > 0 ) {
            my @links = grep { $_->{'from'} > $col } @$links;
            return (shift(@links), 0) if @links;
        } else {
            my @links = grep { $_->{'to'} < $col } @$links;
            return (pop(@links), 0) if @links;
        }
    }
    # if we got here, no match in the current line
    $links = [];
    # $limit-$nrow is the current line we are searching
    my $nrow = $dir * $row;
    my $limit = $dir < 0 ? 0 : $self->Count() - 1;
    while ( ++$nrow <= $limit ) {
        $links = $self->$list($dir * $nrow);
        last if @$links;
    }
    return undef unless @$links;
    return $dir < 0 ? ( $links->[-1], -($nrow + $row) ) 
                    : ( $links->[0], $nrow - $row );
}

# display the link target. The target can be:
# - a uri string
# - a uri object
# - an HTTP::Request object
sub linkTarget {
    my $self = shift;
    my $link = shift;
    (ref $link->{'target'}) ? &{$link->{'target'}}($self)
                            : $link->{'target'};
}

# display the raw source in a scratch buffer. The 'Update' command in the 
# scrarch buffer will re-display the page
sub viewSource {
    my ($self, $Cmd) = @_;
    VIM::DoCommand($Cmd);
    VIM::DoCommand('setfiletype ' . $self->type ) if $self->type;
    $Vim::Option{'buftype'} = 'nofile';
    $Vim::Option{'buflisted'} = 0;
    $Vim::Option{'swapfile'} = 0;
    $Vim::Option{'l:modifiable'} = 1;
    $main::curbuf->Append(0, split "\n", $self->source);
    VIM::DoCommand(
        'command! -buffer -bar Update perl VIM::Browser::updateSource(' . 
        $self->Number . ')' );
}

# dump to a file (for debugging)
sub dump {
    my $self = shift;
    my $file = shift || 'foo';
    open DUMP, '>:utf8', $file or return;
    my $out = @_ ? $self->{$_[0]} : $self;
    print DUMP Dumper($out);
    close DUMP;
}

# return the current value of an option in the associated buffer, set to a 
# new value if given
sub Option {
    my $self = shift;
    return unless $self->buffer;
    my $option = shift;
    my $num = $self->Number;
    my $val = VIM::Eval("getbufvar($num, '&" . $option . "')");
    if ( @_ ) {
        my $new = shift;
        $new = "'$new'" unless $new + 0 eq $new;
        VIM::DoCommand("call setbufvar($num, '&" . $option . "', $new)");
    }
    return $val;
}

# calls Set of the associated buffer, making it modifiable first
sub Set {
    my $self = shift;
    my $mod = $self->Option('modifiable', 1);
    $self->buffer->Set(@_);
    $self->Option('modifiable', $mod);
    1;
}

# calls Append of the associated buffer, making it modifiable first
sub Append {
    my $self = shift;
    my $mod = $Vim::Option{'l:modifiable'};
    $Vim::Option{'l:modifiable'} = 1;
    $self->buffer->Append(@_);
    $Vim::Option{'l:modifiable'} = $mod;
}

# calls Delete of the associated buffer, making it modifiable first
sub Delete {
    my $self = shift;
    my $mod = $Vim::Option{'l:modifiable'};
    $Vim::Option{'l:modifiable'} = 1;
    $self->buffer->Delete(@_);
    $Vim::Option{'l:modifiable'} = $mod;
}

# shortcut to call methods of the associated buffer, as if they were our
sub AUTOLOAD {
    return if our $AUTOLOAD =~ /::DESTROY$/o;
    my $self = shift;
    $AUTOLOAD =~ s/^(\w+::)*//o;
    return unless $AUTOLOAD =~ /^[A-Z]/o;
    $AUTOLOAD = ref($self->buffer) . "::$AUTOLOAD";
    unshift @_, $self->buffer;
    goto &$AUTOLOAD;
}

# for debugging - does nothing special
sub DESTROY {
    my $self = shift;
    debug("DESTROYing page for $self");
    #$VIM::Browser::lastDeletedPage = $self->uri;
    return;
    return if $self->{'keepbuffer'};
    my $buf = $self->buffer;
    if ( $buf ) {
        my $exists = VIM::Eval('bufexists(' . $buf->Number . ')');
        carp 'Buffer exists after page destruction: ' . $buf->Number 
            if $exists and $Vim::Option{'verbose'};
    }
}



## The window class represents a browser window, and (loosely) a vim window.  
#
# It should be destroyed when the window is closed. Thus, each window that 
# contains a browser, has a variable w:browserId, which enables us to find 
# the Window object associated to it.
package VIM::Browser::Window;
use overload '""' => 'as_string', fallback => 1;
use URI;
use Vim qw(debug);
use File::Basename;
use Data::Dumper;
use Carp qw(carp croak verbose);

# we have two argument when construction: the vim command to open a window 
# for this object (either undef, 'new' or 'vnew'), and this window's id.
sub new {
    my ($class, $Cmd, $Id) = @_;
    ### Fields of a Window:
    my $self = { 
        # the id stored in the w:browserId vim variable
        id => $Id, 
        # the history list for this window
        back => [],
        # the future list for this window (the pages that come up with the 
        # Forward command)
        forward => [],
        # the fragment in the page where this window currently is
        fragment => undef,
        # the Page object whose contents we are displaying
        page => undef,
    };
    VIM::Browser::doCommand($Cmd) if $Cmd;
    $Vim::Variable{'w:browserId'} = $Id;
    VIM::Browser::doCommand("resize 999");
    bless $self => $class;
}

# method access to the fields

# scalars
for my $field (qw(page fragment id)) {
    *$field = sub : lvalue {
        $_[0]->{$field};
    }
}

# arrays
for my $field (qw(back forward)) {
    *$field = sub : lvalue {
        my $self = shift;
        @_ ? $self->{$field}[shift] : $self->{$field};
    };
}

# the string representation includes the fragment
sub as_string {
    my $self = shift;
    croak "Window page undefined" unless $self->page;
    my $uri = $self->page->uri->clone;
    $uri->fragment($self->fragment);
    $uri;
}

# the line number of the current fragment
sub fragmentLine {
    my $self = shift;
    $self->page->fragmentLine($self->fragment);
}

# set this window to display the given page
sub setPage {
    my ($self, $page, $fragment) = @_;
    my $buf = $page->Number;
    Vim::debug("going to buffer $buf");
    VIM::Browser::doCommand("buffer $buf");
    $self->page = $page;
    $page->windows($self->id) = 1;
    VIM::Browser::set_status($page->uri());
    VIM::Browser::setupSidebar($buf) unless VIM::Browser::isRegular($self->id);
    $self->fragment = $fragment;
    VIM::Browser::doCommand($self->fragmentLine) if $fragment;
    1;
}

# open a location in the given Window, with default action, possibly using an 
# existing Page instead of creating a new one.  Returns 1 if the page is 
# displayed in the window, 0 otherwise
# The "request" can be anything that is legal as a first arg to handleRequest
sub openUri {
    my $self = shift;
    my $request = shift;
    my $page;
    my $fragment;
    VIM::Browser::goBrowser($self->id);
    if (ref($request) and $request->isa('HTTP::Request')) {
        $page = VIM::Browser::handleRequest($request);
    } else {
        my $uri = new URI $request;
        $fragment = $uri->fragment(undef);
        debug("Opening uri...");
        $page = $VIM::Browser::URI{"$uri"};
        if ( $page and not $page->buffer ) {
            debug("Buffer for cached page no longer exists, reopening");
            VIM::Browser::delPage($page);
            $page = undef;
        }
        $page = VIM::Browser::handleRequest($uri) unless $page;
    }
    return 0 unless $page;
    $self->setPage($page, $fragment);
    return 1;
}

# same as openUri, but keep the current page in the history
sub openNew {
    my $self = shift;
    if ( $self->page ) {
        debug("Pushing $self to the history stack");
        push @{$self->back}, "$self";
    }
    my $ret = $self->openUri(@_);
    pop @{$self->back} unless $ret;
    $ret
}

# get the link target of the given link, or the one at the current cursor 
# position if not given. The return type can be either a uri string or an 
# HTTP::Request object
sub getLink {
    my $self = shift;
    my $link = shift || $self->page->findLink;
    my $req = $self->page->linkTarget($link);
    return (ref($req) and $req->can('uri')) ? $req->uri->as_string : $req;
}

## history stuff

# show the history
sub showHist {
    my $self = shift;
    VIM::Msg("   $_") foreach reverse @{$self->forward};
    VIM::Msg("-> $self", 'Type');
    VIM::Msg("   $_") foreach reverse @{$self->back};
}

# go back/forward in this Window's history. Argument is the number of history 
# elements. Each of the history lists (back, forward) is treated as a stack.
sub goHist {
    my ($self, $Offset) = @_;
    my ($dir, $otherdir) = qw(forward back);
    if ( $Offset < 0 ) {
        ($dir, $otherdir) = qw(back forward);
        $Offset = -$Offset;
    }
    if ( @{$self->{$dir}} < $Offset ) {
        Vim::error("Can't go $Offset $dir in this window");
        return 0;
    }
    $Offset--;
    push @{$self->{$otherdir}}, 
        "$self", reverse(splice(@{$self->{$dir}}, -$Offset, $Offset));
    $self->openUri(pop @{$self->{$dir}});
}

############# The main package #################

package VIM::Browser;

# from CPAN
use LWP::UserAgent;
use LWP::Debug qw(+);
BEGIN {
    undef &LWP::Debug::_log;
}
use URI;
use URI::Heuristic qw(uf_uri);
use URI::file;
use HTML::Form 1.038;
use HTTP::Headers::Util qw(split_header_words);

# standard
use Tie::Memoize;
use Data::Dumper;
use File::Spec::Functions qw(:ALL);
use File::Basename;
use File::Path;
use File::Temp ();
use File::Glob ':glob';
use Encode;

# our own
use HTML::FormatText::Vim;
use Vim qw(debug);
use Mailcap;

use warnings;
use integer;
use open ':utf8';

BEGIN {
    our $VERSION = 1.1;
}

## Vim Interface

# get the value of the given setting. Looks a variable g:browser_<foo>.  
# Returns a default value if not found
sub setting {
    my $var = 'g:browser_' . shift;
    return exists $Vim::Variable{$var} ? $Vim::Variable{$var} : shift;
}

sub doCommand {
    my $cmd = shift;
    $cmd = "silent! $cmd" unless $Vim::Option{'verbose'};
    VIM::DoCommand($cmd);
}

sub msg {
    my $msg = shift;
    my $verbose = @_ ? shift : 1;
    Vim::msg($msg) if $Verbose >= $verbose;
}

sub set_status {
    $Vim::Variable{'w:browser_status_msg'} = shift;
    doCommand('redrawstatus');
}

sub LWP::Debug::_log {
    my $msg = shift;
    $msg =~ s/\n*$//;
    set_status($msg) unless $msg eq '()';
}


# This is totally stupid, but it appears there is no simple way to get the 
# file seperator for the current os.
our $FileSep = catdir('foo', 'bar');
# I hope no os uses foo or bar as the curdir :-)
$FileSep =~ s/^foo(.*)bar$/$1/o;

# create a directory if it does not exist
sub makedir {
    my ($dir, $id) = @_;
    unless ( file_name_is_absolute($dir) ) {
        Vim::warning("$id directory must be absolute, not $dir");
        return;
    }
    # make sure it exists
    if ( -d $dir ) {
        unless ( -r _ ) {
            Vim::warning "$dir is not readable";
            return;
        }
    } elsif ( -e $dir ) {
        Vim::warning "$dir exists, but is not a directory";
        return;
    } else {
        msg("$id directory $dir doesn't exist, creating...");
        mkpath($dir, 0, 0755);
        return 1;
    }
}

# return the list of files in the given directory. If the directory is not 
# given, use '.'. If the second argument is true, add a trailing slash to
# directory names
sub listDirFiles {
    my ($dir, $trailing) = @_;
    # uf_uri doesn't guess correctly for bare filenames without path
    # components. We will adopt this behaviour.
    return () unless $dir;
    # catfile (and catdir) on windows make the drive letter upper case -
    # don't use it!
    $dir .= '*';
    # $dir = $dir ? catfile($dir, "*") : "*";
    $flags = GLOB_TILDE; # | GLOB_NOSORT;
    $flags |= GLOB_MARK if $trailing;
    @res = bsd_glob($dir, $flags);
    map { s{/$}{$FileSep}o } @res if $trailing;
    return @res;
}

# are we in sidebar mode?
sub sidebar { 
    my $ret = $Vim::Variable{'g:browser_sidebar'};
    $ret ? ( $ret ) : ();
}

# check whether a browserId (window id) is regular or sidebar
sub isRegular {
    my $id = shift;
    no warnings 'numeric';
    return $id > 0;
}


## CONFIGURATION

our $InstDir = $Vim::Variable{'s:browser_install_dir'};

our @RunTimePath = split /,/, $Vim::Option{'runtimepath'};

# how verbose should we be
tie our $Verbose, 'VIM::Scalar', 'g:browser_verbosity_level', 2;

# The base directory for all our files. By default, the browser subdir of the 
# first writeable directory in runtimepath
tie our $DataDir, 'VIM::Scalar',
    'g:browser_data_dir', 
    catdir((grep { -w } @RunTimePath)[0], 'browser'),
    \&canonpath;

# full path to the global history file
tie our $HistFile, 'VIM::Scalar', 'g:browser_history_file', 
    catfile($DataDir, 'history');

# history size
tie our $HistSize, 'VIM::Scalar', 'g:browser_history_size', 30;

# the global history stack
tie our @History, 'VIM::Browser::History', $HistFile;

sub saveHist {
    (tied @History)->save;
}

# the directory containing all bookmark files. Each file in this directory is 
# considered to be a bookmark file.
tie our $AddressBookDir, 'VIM::Scalar',
    'g:browser_addrbook_dir',
    catdir($DataDir, 'addressbooks'),
    # update the bookmarks mechanism when this variable is read
    sub {
        my $dir = shift;
        { 
            # skip the whole bookmarks business if the directory is empty
            if ( $dir ) {
                $dir .= $FileSep;
                unless ( makedir($dir, 'Bookmarks') ) {
                    $dir = '';
                    redo;
                }
            } else {
                Vim::warning "Bookmarks are disabled";
            }
        }
        $dir;
    };

# the encoding we assume, if none is given in the document header
tie our $AssumedEncoding, 'VIM::Scalar', 'g:browser_assumed_encoding', 
    'utf-8', sub {
        my $val = shift;
        unless (Encode::resolve_alias($val)) {
            Vim::warning
                "The encoding $val is not recognized\n",
                "Please adjust g:browser_assumed_encoding (using utf8 instead)";
            $val = 'utf-8';
        }
    };

# cookies file
# HTTP::Cookies version < 1.36 has a bug, concerning browsing local files. If 
# we have such a version, disable cookies by default
eval 'use HTTP::Cookies 1.36';
tie our $CookiesFile, 'VIM::Scalar', 'g:browser_cookies_file',
    $@ ? '' : catfile($DataDir, 'cookies.txt');

# what to put in the From request header
tie our $FromHeader, 'VIM::Scalar', 'g:browser_from_header', $ENV{'EMAIL'};

# timeout for connecting (seconds)
tie our $TimeOut, 'VIM::Scalar', 'g:browser_connect_timeout', 120;

# an additional mailcap file used for vim
tie our $MailCap, 'VIM::Scalar', 'g:browser_mailcap_file', 
    catfile($DataDir, 'mailcap.local');

# initialize the mailcap system to use our mailcap files (in addition to the 
# default ones)
VIM::System::mailcap( $MailCap, catfile($InstDir, qw(browser mailcap)));

# temporary directory to use when viewing content with external programs
tie our $TmpDir, 'VIM::Scalar', 'g:browser_temp_dir', 
    catfile($DataDir, 'tmp'), sub {
        my $dir = shift;
        unless ( $dir and makedir($dir, 'Temporary') ) {
            $dir = tmpdir();
            Vim::warning(
                "Failed to create temporary directory, defaulting to $dir");
        }
        $dir
    };

# width of the sidebar (columns).
tie our $SidebarWidth, 'VIM::Scalar', 'g:browser_sidebar_width', 25;

# the page to open for empty :Browse command
tie our $HomePage, 'VIM::Scalar', 'g:browser_home_page', 
    ( $ENV{'HOMEPAGE'} || $ENV{'HOME'} || 'http://vim.sf.net/' );


## GLOBAL STATE
# We also have @History from above

# the hash of all Pages. Keys are absolute uris, values are page objects
our %URI;

# map buffer numbers to pages
our @Page;

# a hash associating browser window ids to Window objects. Window ids can be 
# of two types: an integer, for normal windows, or a command name for sidebar 
# windows. It is kept in the w:browserId variable of the corresponding vim 
# window
our $Browser = {};
# the current window id (for normal windows)
our $MaxWin = 0;

# the current Window object
our $CurWin;
# the current sidebar window object
our $CurSidebar;
# the window where the cursor is
our $CursorWin;

# return the relevant current window, depending on whether we want the 
# sidebar.
sub CurWin : lvalue {
    my $win = sidebar() ? \$CurSidebar : \$CurWin;
    $$win = shift if @_;
    $$win
}

# the set of buffers in the sidebar
our %Sidebar;

# bookmarks
my @AddrBookDirs = 
    map { catdir($_, qw(browser addressbooks) ) . $FileSep } @RunTimePath;
# the hash of all bookmark files. Each entry is a hash tied to AddrBook, and 
# the keys are the names of the files
tie our %AddrBook, 'Tie::Memoize', sub { 
    my $file = shift;
    for my $dir ( $AddressBookDir,  @AddrBookDirs ) {
        my $ffile = catfile($dir, $file);
        if ( -r $ffile ) {
            tie my %book, 'VIM::Browser::AddrBook', $ffile;
            return \%book;
        }
    }
    return ();
}, undef, sub { 
    my $file = shift;
    grep { -r catfile($_, $file) } ( $AddressBookDir, @AddrBookDirs );
};

# the current (default) bookmark file
tie our $CurrentBook, 'VIM::Scalar',
    'g:browser_default_addrbook',
    'default';

# the user agent
our $Agent = new LWP::UserAgent
    agent => "VimBrowser/$VERSION ",
    from => $FromHeader,
    timeout => $TimeOut,
    protocols_forbidden => [qw(mailto)],
    cookie_jar => $CookiesFile ? { file => $CookiesFile, autosave => 1 } 
                               : undef,
    env_proxy => 1,
    # at least for now, don't accept compressed encoding
    # default_headers => (new HTTP::Headers 'Accept-Encoding' => 'identity'),
    requests_redirectable => [qw(GET HEAD POST)];

## Methods for dealing with the request and response

# The flow of a request is as follows:
# 1. handleRequest() is called, with a given request (eg, a uri)
# 2. The requested content is fetched using the fetch() function
# 3. The action used to display the content is determined, using getAction(). 
# This may be either given (as the second argument), or deduced from the 
# response.
# 4. If the action is 'save', saveResponse() is called to save the content to 
# a file. Otherwise, openUsing() is called, with arguments determined by the 
# action.
# 5. openUsing() decodes (decompresses) the content, if necessary, then, 
# according to the action requested, either displays it by calling 
# pageFromResponse(), or displays it using an external program, possibly 
# capturing the text back and displaying it (via pageFromResponse).
# 6. If a page object was created, it is returned.

# deduce the encoding of a response
sub getEncoding {
    my $response = shift;
    my $nowarning = shift;
    my $encoding;
    my @ctype = split_header_words($response->header('content-type'));
    if (my $ctype = pop @ctype ) {
        my %params = @$ctype;
        $encoding = $params{'charset'};
    }
    if ( $encoding and not Encode::resolve_alias($encoding) ) {
        Vim::warning("$encoding: Unrecognized encoding") unless $nowarning;
        $encoding = undef;
    }
    $encoding = $AssumedEncoding unless $encoding;
    $encoding;
}

# get the uri base
sub getBase {
    my $response = shift;
    my $base = $response->base;
    # try to make it absolute
    $base = URI::file->new_abs($base->file) if $base->scheme eq 'file';
    $base
}

# fetch a uri/request
sub fetch {
    my $req = shift;
    my ($uri, $response);
    if ( not ref($req) or $req->isa('URI') ) {
        $uri = $req;
        msg("Fetching $uri...");
        $response = $Agent->get($uri);
    } else {
        $uri = $req->uri;
        msg("Sending request to $uri...");
        $response = $Agent->request($req);
    }
    Vim::error("Failed to fetch $uri:", $response->status_line)
        unless ($response->is_success);
    return $response;
}

# determine what action to take, depending on the response, and (possibly) a 
# requested action. Return the action to perform, possibly with arguments. 
# May prompt the user for the action. The action is determined as follows:
# a. If the action is given (as an argument), use it for the next stage, else 
# detemine it as follows:
#   1. if the content disposition is 'attachment', use 'save' as an action, 
#   with the given file name as the first argument
#   2. otherwise, if the content type is one we may display, use 'show' as 
#   the action
#   3. otherwise use 'ask'
# b. If the answer from the previous step is 'ask', present the user with a 
# confirmation dialog. Else use the given action.
# c. If the action resulting from b is 'save', determine a recommended file 
# name as the last component of the uri.
sub getAction {
    my $response = shift;
    my $action = shift;
    my $content = $response->content_type();
    unless ($content) {
        Vim::warning('Content type is empty, assuming "text/plain"');
        $content = 'text/plain';
    }
    # if we failed to perform the request, forget the initial intent and 
    # display the error message
    $action = undef if $response->is_error;
    unless ( defined $action ) {
        debug('asked for default action...');
        # no action was requested - determine what is the default one
        # check if the headers says this is an attachment (RFC 2183)
        my $disp = $response->header('content-disposition');
        if ( $disp and $disp =~ /^attachment/o ) {
            debug('  attachment found...');
            $action = 'save';
            my $file = $1 if $disp =~ /filename=([^;]*)/o;
            if ( $file ) {
                $file = basename($file);
                push @_, '', $file;
                debug("    Recommended file name: $file");
            }
        } else {
            # try to see if we can format and display this inline
            debug("  content type is $content...");
            if ( defined $FORMAT{$content} ) {
                $action = 'show';
            } else {
                # we are not given an action, this is not an attachment, and 
                # we can't display it directly - use a generic action
                $action = 'ask';
            }
        }
    }
    if ( $action eq 'ask' ) {
        # these are always available
        my %action = (
            save => '&Save to a file',
            external => '&Open with an external application',
            cancel => '&Cancel',
        );
        $action{'show'} = '&Display internally' 
            if ( defined $FORMAT{$content} );
        my @viewers = VIM::System::viewCmd($content, '%s');
        debug("got the following viewers: @viewers");
        my $viewer = shift @viewers;
        $action{$viewer} = "&View with system default viewer ($viewer)"
            if $viewer;
        $action{$_} = "view with: $_" foreach @viewers;
            
        my @valid;
        push @valid, 'show' if exists $action{'show'};
        push @valid, $viewer if defined $viewer;
        push @valid, @viewers, qw(external save cancel);
        my $opts = join('\n', map { $action{$_} } @valid);
        $opts =~ s/"/\\"/g;
        my $msg = $valid[0] eq 'show' ? 
          'How would you like to view the page?' :
          'The content type of this page is ' . $content . 
          '\nIt can not be displayed internally.\nWhat would you like to do?';
        my $ans = VIM::Eval("confirm(\"$msg\", \"$opts\")");
        debug("Answer is $ans");
        $action = $valid[$ans - 1];
        $action = '' if $action eq 'cancel';
    }
    if ( $action eq 'save' and not $_[1] ) {
        my @seg = $response->request->uri->path_segments;
        $_[1] = $seg[-1];
    }
    no warnings;
    debug("Final action is: $action, @_");
    use warnings;
    return ($action, @_);
}

# given $text, a ref to an array of text lines, $uri, and possibly a vim 
# buffer, create a buffer if not given. name it according to $uri, and 
# display $text in there. Return the buffer object.
sub dispUriText {
    my $text = shift;
    my $uri = shift;
    my $syntax = shift;
    my $buffer;
    my $bufname = Vim::fileEscape("VimBrowser:-$uri-");
    my $bufnr = VIM::Eval("bufnr('$bufname')");
    if ( $bufnr > 0 ) {
        debug("Buffer with this name exists ($bufnr), using it");
        push @_, grep { $_->Number == $bufnr } VIM::Buffers;
    }
    if ( @_ ) {
        # a specific buffer was requested
        $buffer = shift;
        debug( 'Using existing buffer "' . $buffer->Name . '" for ' . $uri);
        debug('going to buffer ' . $buffer->Number);
        doCommand('buffer ' . $buffer->Number);
    } else {
        debug('Creating a new buffer for ' . $uri);
        # This is a bit wrong because (theoretically) a file with the given 
        # name could exist
#x          VIM::DoCommand(
#x              "silent edit +setfiletype\\ browser #VimBrowser:-$uri-");
        doCommand('enew');
        doCommand('setfiletype browser');
        $buffer = $main::curbuf;
        debug('Current buffer is ' . $buffer->Number);
        doCommand("file $bufname");
        debug('Current buffer is ' . $buffer->Number);
        doCommand('ls!') if $Vim::Option{'verbose'} > 1;
        # for some reason, an extra buffer is created, wipe it out
        doCommand('bwipeout #') if $Vim::Variable{'v:version'} < 700;
    }
    $Vim::Option{'l:syntax'} = $syntax;
    my $mod = $Vim::Option{'l:modifiable'};
    $Vim::Option{'l:modifiable'} = 1;
    $buffer->Delete(1, $buffer->Count);
    $buffer->Append(0, @$text);
    $Vim::Option{'l:modifiable'} = $mod;
    return $buffer;
}

# given an HTTP::Response object, create a VIM::Browser::Page from it. Args 
# are the response object, and optionally a buffer to use for the page text.
sub pageFromResponse {
    my $response = shift;
    my $content_type = $response->content_type();
    $content_type = 'text/plain' unless $content_type;
    my $handler = $FORMAT{$content_type};
    return () unless defined $handler;
    my ($text, $links, $images, $markup, $fragments, $type, $syntax) = 
        &$handler($response);
    if ( @$text ) {
        my $request = $response->request;
        $uri = $request->uri;
        $uri->fragment(undef);
        my $vuri = $uri;
        my $post = $request->method eq 'POST';
        $vuri .= '(POST)' if $post;
        $vuri .= '/' unless $vuri=~ /\//o;
        my $buffer = dispUriText($text, $vuri, $syntax, @_);
        my $page = new VIM::Browser::Page $response,
            buffer => $buffer,
            links => $links,
            images => $images,
            markup => $markup,
            fragment => $fragments,
            type => $type,
            uri => $uri;
        unless ($post or $response->is_error or 
                grep { $content_type eq  $_ } qw(history bookmarks) ) {
            $URI{"$uri"} = $page;
            push @History, { uri => $uri, title => $page->title };
        }
        $Page[$page->Number] = $page;
        debug( $page ? 'Succefully created page, buffer is ' . $page->Number 
                     : 'Page creation failed' );
        $page;
    } else {
        # there is no text, for some reason
        Vim::warning('Document contains no data');
        return ();
    }
}

# save the contents of a response object to a file. signature is
# saveResponse(<resp>, [<file>, [<recfile>]])
# where <resp> is the response object, <file> is a destination file name, and 
# <recfile> is a proposed file name. if <file> is false, ask the user, 
# proposing <recfile>
sub saveResponse {
    my $response = shift;
    my $file = shift;
    unless ( $file ) {
        $file = shift || '';
        debug("Recommended file is $file");
        $file = Vim::browse(1, 'Save to file:', '', $file);
    }
    return 0 unless $file;
    # TODO: check if the file exists
    unless ( open FH, '>', $file ) {
        Vim::error("Unable to open $file for writing");
        return 0;
    }
    print FH $response->content;
    close FH;
    return 1;
}

# open the data of the given response (first arg), using the given program 
# (second arg). The might be translated, depending on the content encoding. 
# If the program is ':', display it internally using pageFromResponse(), and 
# return the corresponding page. If it is false but defined, use the default 
# system viewer (if possible). This uses the Mailcap module. If the program 
# argument is undefing, prompt for external program. If program is true (and 
# not ':'), assume this is the name of the program.
sub openUsing {
    my $response = shift;
    my $prog = shift;
    my $cencoding = $response->content_encoding;
    debug("Content encoding is $cencoding") if $cencoding;
    # should we decode the response using Mailcap?
    my $should_decode = ($cencoding and 
                        ($cencoding ne 'identity') and 
                        not $response->can('decoded_content'));
    if ( $prog eq ':' ) {
        # show internally
        if ( $should_decode ) {
            $prog = "cat '%s' |";
        } else {
            return pageFromResponse($response);
        }
    }
    my $ctype = $response->content_type;
    $ctype = 'text/plain' unless $ctype;
    my $suffix = Mailcap::nametemplate($ctype) || '%s';
    $suffix =~ s/^[^.]*//o;
    my $template = 'tmpXXXXXX';
    my $TMP = new File::Temp
        TEMPLATE => $template,
        SUFFIX => $suffix,
        DIR => $TmpDir,
        UNLINK => 0,
        ;
    if ( $should_decode ) {
        close $TMP;
        my $unzip = 
            Mailcap::getView { $_->copiousoutput } "application/$cencoding";
        debug("Decompressing using: $unzip");
        $unzip = "| $unzip > '$TMP'";
        unless ( open my $UZ, $unzip ) {
            Vim::warning("Failed to decompress using $unzip");
            return;
        }
        print $UZ $response->content;
    } else {
        undef $@;
        print $TMP $response->can('decoded_content') ? 
                $response->decoded_content( charset => 'none' ) :
                $response->content;
        if ( $@ ) {
            Vim::warning("Failed to decode $cencoding");
            return;
        }
        close $TMP;
    }
    my $cleanup = sub { unlink "$TMP" };
    my $res;
    if ( not $prog and defined $prog ) {
        # use system default
        $res = VIM::System::viewDef($ctype, "$TMP", $cleanup);
        undef $prog unless $res;
    }
    $res = VIM::System::viewWith($ctype, "$TMP", $cleanup, $prog) 
        unless (not $prog and defined $prog);
    if ( ref($res) ) {
        # we got some text back
        $response->content_type('text/plain') unless defined $FORMAT{$ctype};
        $response->content(join("", @$res));
        $response->content_encoding(undef);
        return pageFromResponse($response);
    } else { 0 }
}

# given a target request, and possibly and action, handle it. A request is 
# either a URI object, a uri string or an HTTP::Request object. If an action 
# is not given, it will be deduced using getAction. If an action is given, 
# any extra arguments are passed to the handling routines. The action is a 
# string, which currently can be:
# - 'show' - display the data internally, using a Page object
# - 'save' - save the content to a file
# - 'default' - use system default viewer for this content type to display 
# the data
# - 'external' - view the data using an external application prompted from 
# the user
# - 'ask' - ask the user what to do
sub handleRequest {
    my $uri = shift;
    $uri = new URI $uri unless ref($uri);
    debug("Opening $uri");
    my $response = fetch($uri);
    my ($action, @args) = getAction($response, shift);
    if ( $action eq 'show' ) {
        my $page = openUsing($response, ':', @_);
        if ( $page and $uri->isa('URI') and ($page->uri ne $uri) ) {
            $URI{"$uri"} = $page;
        }
        $page;
    } elsif ( $action eq 'save' ) {
        saveResponse($response, @_, @args);
        return undef;
    } elsif ( $action eq 'default' ) {
        openUsing($response, '', @_, @args);
    } elsif ( $action eq 'external' ) {
        openUsing($response, undef, @_, @args);
    } elsif ( $action ) {
        # we assume $action is the program to use
        openUsing($response, $action, @_, @args);
    } else { undef }
}

## FORMATTING

# The following hash assigns, to each content type, a function for scanning 
# and formatting a source text with that type. It should return a list of 
# five values:
# - An array ref of lines, which will be put in the buffer without 
# modification.
# - An array ref of links, as described in the 'links' field of the 
# constructor of VIM::Browser::Page
# - A similar array of images
# - A similar array for markup
# - A hash ref of fragments, again as in the 'fragment' field of a Page.
# - The vim filetype corresponding to this content type
# - The syntax highlighting for this text. Any valid value for the vim 
# 'syntax' option
# The only mandatory argument to the function is the HTTP::Response object. 
# The rest of the arguments are treated as a hash of formatting hints.
# Two special content types, 'history' and 'bookmarks' are used for 
# formatting the respective data into a browser page
our %FORMAT = (
    'text/html' => sub {
        my $response = shift;
        my %hints = @_;
        my $encoding = getEncoding($response);
        $@=undef;
        my $html = $response->can('decoded_content') ?
            $response->decoded_content(default_charset => $AssumedEncoding) :
            decode($encoding, $response->content);
        if ( $@ ) {
            my $fallback = 'iso-8859-1';
            Vim::warning(<<EOF);
Failed decoding the content
Try changing the value of browser_assumed_encoding to
the expected character encoding of the page
Falling back to $fallback

EOF
            $html = $response->decoded_content(charset => $fallback);
        }
        return [] unless $html;
        my $width = Vim::bufWidth;
        my $base = getBase($response);
        my @forms = HTML::Form->parse($html, $base);
        my $formatter = new HTML::FormatText::Vim 
            lm => 0, 
            rm => $width,
            encoding => $encoding,
            # whether to break the line when reaching the right margin
            breaklines => setting('break_lines', 1),
            # the formatter will store the absolute uris for the links using 
            # this base
            base => $base,
            # the forms of this page
            forms => [ @forms ];
        my $text = $formatter->format_string($html);
        #x $text = encode_utf8($text);
        my $links = $formatter->{'links'};
        my $images = $formatter->{'images'};
        my $markup = $formatter->{'markup'};
        my $fragment = $formatter->{'fragment'};
        return [split "\n", $text], $links, $images, $markup, $fragment, 
               'html', 'ON';
    },
    'text/plain' => sub {
        # do nothing special
        my $response = shift;
        my $encoding = getEncoding($response);
        my $content = $response->can('decoded_content') ?
            $response->decoded_content(default_charset => $AssumedEncoding) :
            decode($encoding, $response->content);
        return [split "\n", $content], undef, undef, 
               undef, undef, undef, 'OFF';
    },
    'bookmarks' => sub {
        my $response = shift;
        my @files = split("\n", listBookmarkFiles());
        debug('uri is ' . $response->request->uri);
        my $current = $response->request->uri->authority;
        debug("current is $current");
        my @text = ( 
            "Bookmarks in file $current",
            '==================' . ( '=' x length($current) ),
            '',
        );
        my $links = [[], [], []];
        my $book = $response->content;
        for my $name ( keys %$book ) {
            my ($target, $desc) = @{$book->{$name}};
            $target = canonical($target);
            push @text, "* $name", "  $desc";
            push @$links, [{
                from => 2,
                to => length($name) + 1,
                text => $name,
                target => "$target",
            }], [];
        }
        push @text, ('', '-' x $SidebarWidth, '');
        push @$links, [], [], [];
        foreach ( @files ) {
            next if $_ eq $current;
            push @text, "[$_]";
            push @$links, [{
                from => 1,
                to => length,
                text => $_,
                target => "bookmarks://$_",
                sidebar => 1,
            }];
        }
        return ([@text], $links, undef, undef, undef, undef, 'browserBkmkPage');
    },
    history => sub {
        my $response = shift;
        my %domain;
        my @domains;
        for my $event ( reverse @History ) {
            next unless $event;
            my $auth = $event->uri->authority;
            $auth = 'localhost' 
                if ( not $auth and $event->uri->scheme eq 'file');
            next unless $auth;
            push @domains, $auth unless exists $domain{$auth};
            push @{$domain{$auth}}, $event;
        }
        my @text = (
            'Browsing History',
            '================',
        );
        my @links = ([], []);
        for my $domain ( @domains ) {
            push @text, '', "+ $domain";
            push @links, [], [];
            while ( $_ = shift @{$domain{$domain}} ) {
                my $text = $_->title;
                my $more = @{$domain{$domain}};
                push @text, sprintf("  %s-> $text", $more ? '|' : '`');
                push @text, sprintf("  %s     %s", $more ? '|' : ' ',
                                    $_->actime);
                push @links, [{
                    text => $text,
                    target => $_->uri->as_string,
                    from => 6,
                    to => length($text) + 5,
                }], [];
            }
        }
        return (\@text, \@links, undef, undef, undef, undef, 
                'browserBkmkPage');
    }
);

# some content types are actually plain text, but with a syntax highlighting
our %TextFormats = (
  # x-type      vim filetype
    csh      => 'csh',
    latex    => 'tex',
    tex      => 'tex',
    perl     => 'perl',
    sh       => 'sh',
    tcl      => 'tcl',
    texinfo  => 'texinfo',
    'c++hdr' => 'cpp',
    'c++src' => 'cpp',
    'chdr'   => 'c',
    'csrc'   => 'c',
    java     => 'java',
    pascal   => 'pascal',
    python   => 'python',
    pod      => 'pod',
); 

while ( my ($type, $ft) = each %TextFormats ) {
    $FORMAT{"application/x-$type"} = $FORMAT{"text/x-$type"} = sub {
        my @res = &{$FORMAT{'text/plain'}}(shift);
        $res[-1] = $ft;
        @res
    };
}

## Various helper functions

# scan all windows until we find:
# a. preferably the window corresponding to the current Window object
# b. otherwise, some browser window.
#
# In the second case, if a current window was defined, we remove it and set 
# the found window to be the current. If we found any browser window, the 
# situation will be that CurWin is the Window object corresponding to the 
# window we found, and the cursor is in that window. The return value is the 
# id of the window, or 0 if none found
sub goBrowser {
    my ($success, $Id);
    my $arg = @_ ? shift : (CurWin() ? CurWin()->id : undef);
    my $check;
    if ( defined $arg ) {
        $check = ref $arg ? $arg : sub { shift eq $arg };
    } else {
        $check = sub { 1 };
    }
    my $sidebar = sidebar();
    my $cur = VIM::Eval('winnr()');
    my $win = 0;
    foreach ($cur..scalar(VIM::Windows), 1..$cur-1) {
        $win = $_;
        debug("  Trying window $win...");
        if ($Id = VIM::Eval("getwinvar($win, 'browserId')" ) and
            (( $sidebar ? not isRegular($Id) : isRegular($Id) ) or @_)) {
            # found a browser window with the requested sidebarness
            debug("    Window $win has id $Id");
            $success = 1;
            last if &$check($Id);
        }
    }
    unless ( $success ) {
        delete $Browser->{$arg} if $arg and not ref $arg;
        CurWin(undef);
        return 0;
    }
    # if we got here, we found _some_ window. Return it if it's the current 
    # one, or if the current wasn't specified
    if ( &$check($Id) ) {
        doCommand("${win}wincmd w");
        debug("Entered window $win");
        CurWin = $Browser->{$Id};
        return $Id;
    }
    # if we got here, we found some window, but the $CurWin no longer has a 
    # window. Destroy all trace of $CurWin, and start over, searching for any 
    # browser window whatsoever.
    delete $Browser->{$arg};
    CurWin(undef);
    return goBrowser();
}

# return the given Page object, or, if not given, find a browser and return 
# its Page. Just a quick way to find the page on which we should operate
sub getPage {
    return shift if @_;
    unless ( goBrowser ) {
        Vim::error('Unable to find an open browser window');
        return;
    }
    return CurWin()->page;
}

# find the link currently under the cursor
sub findLink {
    my $link = shift;
    $link = $CursorWin->page->findLink() unless defined $link;
    $link
}

# completely delete a page from the system
sub delPage {
    my $page = shift;
    # Note: page might _not_ have a buffer
    my $uri = $page->uri;
    debug("Deleting page for $uri");
    delete $URI{"$uri"};
    for my $id ( keys %{$page->windows} ) {
        $Browser->{$id}->page = undef if defined $Browser->{$id};
    }
}

# create a new window object, and make it the current one. Arguments are a 
# vim command to create the vim window (passed to VIM::Browser::new) and a 
# window id
sub newWindow {
    my $cmd = shift;
    my $id = @_ ? shift : ++$MaxWin;
    debug("Creating window using '$cmd', id is '$id'");
    $CursorWin = CurWin = new VIM::Browser::Window $cmd, $id;
    $Browser->{CurWin->id} = CurWin;
}

# sidebar creation and destruction

# the $noResize variable solves the following problem: suppose the only 
# window in the sidebar belongs to 'Google foo'. Now we issue 'Google! bar', 
# so that the resulting page will replace the current one. The autocommands 
# will remove the old page, thereby making the sidebar empty, which will 
# cause it to be closed, only to be opened again by the new command. This is 
# unpleasant. We therefore don't close the sidebar in such a case, and use 
# $noResize to inform setupSidebar to not open it.
my $noResize;

sub setupSidebar {
    my $buf = shift;
    unless ( %Sidebar ) {
        if ( $noResize ) {
            $noResize = 0;
        } else {
            $Vim::Option{'columns'} += $SidebarWidth;
            VIM::Browser::doCommand("vertical resize $SidebarWidth");
        }
    }
    $Sidebar{$buf} = 1;
}

# get a partial uri or a bookmark, and return the canonical absolute uri.  
# This operates recursively so we may have bookmarks pointing to other 
# bookmarks, etc. The other arguments are interpreted as arguments: They are 
# concatenated after the uri, with + or & in front, depending on whether they 
# contain a '='.
sub canonical {
    local $_ = shift;
    if (@_) {
        my $uri = canonical($_);
        return undef unless defined $uri;
        $uri .= shift;
        $uri .= ((/\=/ ? '&' : '+') . $_) while $_ = shift;
        return new URI $uri;
    };
    # if this is _not_ a bookmark request, return the absolute uri
    unless ( s/^://o ) {
        s{/*$}{}o;
        return uf_uri($_);
    }
    # if we got here, it's a bookmark - determine the bookmark file, and 
    # remove it from the request
    my $book = s/^([^:]*)://o ? $1 : $CurrentBook;
    $book = $CurrentBook unless $book;
    unless (exists $AddrBook{$book}) {
        Vim::error("Bookmark file $book does not exist");
        return undef;
    };
    return "bookmarks://$book" unless $_;
    if (exists $AddrBook{$book}->{$_}) {
        return canonical($AddrBook{$book}->{$_}[0]);
    } else {
        Vim::error("Entry '$_' does not exists in bookmark file '$book'");
        return undef;
    }
}

# given a canonical uri, determine how to handle it, according to the scheme.
# If the variable g:browser_<scheme>_handler is defined, we use it to launch 
# the required handler, and return undef. If g:browser_<scheme>_command is 
# defined, we use it as a vim command to run, and return undef. Otherwise, 
# the uri is returned, and is handled internally, assuming it is supported.
sub checkScheme {
    my $uri = shift;
    $uri = new URI $uri unless ref $uri;
    return $uri unless $uri->isa('URI');
    my $scheme = $uri->scheme;
    unless ( defined $scheme ) {
        Vim::error(<<EOF);
Unable to determine the scheme of '$uri'.
Please try a more detailed uri.
EOF
        return undef;
    };
    my $handler = setting("${scheme}_handler");
    my %flag = ( 
        s => "$uri", 
        o => $uri->can('opaque') ? scalar $uri->opaque() : '', 
        p => $uri->can('path') ? scalar $uri->path() : '',
        f => $uri->can('fragment') ? scalar $uri->fragment() : '',
        a => $uri->can('authority') ? scalar $uri->authority() : '',
        q => $uri->can('query') ? scalar $uri->query() : '',
        '%' => '%',
    );
    my $flags = join('', keys %flag);
    if ( $handler ) {
        $handler =~ s/%([$flags])/$flag{$1}/g;
        msg("Launching: '$handler'");
        VIM::System::spawn($handler);
        return undef;
    } elsif ( $handler = setting("${scheme}_command") ) {
        $handler =~ s/%([$flags])/$flag{$1}/g;
        doCommand($handler);
        return;
    } elsif ( $Agent->is_protocol_supported($uri) ) {
        return $uri;
    } else {
        Vim::error(<<EOF);
The '$scheme' scheme is not supported.
Define g:browser_${scheme}_handler or g:browser_${scheme}_command
to add external support as a system or vim command
EOF
        return undef;
    }
}

######################################################
#                   public area                      #
# These are functions used by the browser.vim plugin #
######################################################

## autocommands

# The current window is the one we're in, if it is a browser window.  
# Otherwise, it's the last browser window we've been to. This function is 
# called to update the situation from the BufEnter autocommand
sub winChanged {
    my $id = $Vim::Variable{'w:browserId'};
    if ( defined $id ) {
        debug("Entered a browser window, id is $id");
        
        if ( isRegular($id) ) {
            $CursorWin = $CurWin = $Browser->{$id};
        } else {
            $CursorWin = $CurSidebar = $Browser->{$id};
        }
    } else {
        Vim::warning("entered a browser window with no id");
        $CursorWin = undef;
    }
}

# close the sidebar if the last sidebar window has left it. See also the 
# comment about $noResize above.
sub bufWinLeave {
    my $buf = shift;
    my $page = $Page[$buf];
    my $id = $Vim::Variable{'w:browserId'};
    debug("deleting $id from the list of windows of page $buf");
    delete $page->windows->{$id} if $page;
    return unless %Sidebar;
    debug("Deleting buffer $buf from the sidebar");
    debug("  Deleted!") if delete $Sidebar{$buf};
    unless ( %Sidebar ) {
        if ( sidebar() ) {
            $noResize = 1;
        } else {
            $Vim::Option{'columns'} -= $SidebarWidth;
        }
    }
}

# attach a window object to the current window, if one does not exist, with 
# the page for given buffer as its page. Called by the BufWinEnter command, 
# in case someone was naughty and entered a buffer that belongs to the 
# browser directly
sub setWindowPage {
    my $buf = shift;
    my $id = $Vim::Variable{'w:browserId'};
    if ( defined $id ) {
        winChanged;
    } else {
        newWindow;
    }
    CurWin->setPage($Page[$buf]);
    1;
}

# remove the page with the given buffer name from the system. Called from the 
# BufUnload autocommand
sub bufUnload {
    my $bufnr = shift;
    my $page = delete $Page[$bufnr];
    debug("Cleaning page for buffer $bufnr");
    unless ( $page ) {
        Vim::warning("Page does not exist for buffer $bufnr");
        return;
    }
    delPage($page);
}

# show the target of the link (given, or under the cursor). Called by the 
# CursorHold autocommand (as well as by others)
sub showLinkTarget {
    # (TODO) This funny arrangement is used because the 'T' flag in 
    # 'shortmess' is not always in effect, for some reason. It works only 
    # from the autocmd. So if the link is passed in explicitly, we show 
    # nothing if the line is too long.
    my $short = @_;
    my $text = $CursorWin->getLink(@_);
    return unless defined $text;
    my $width = $Vim::Option{'columns'};
    return if ( $short and length "$text" > $width - 20 );
    msg( $text );
}

# set the text in the text area from the current buffer. Called from the 
# BufLeave autocmd of TextArea buffers
sub setTextArea {
    return unless $CurrentTextArea;
    warn 'setTextArea called for ' . $main::curbuf->Name() 
        unless $main::curbuf->Name =~ /^Browser-TextArea-/o;
    my $text = join("\n", $main::curbuf->Get(1..$main::curbuf->Count()));
    debug("Setting textarea to $text");
    &{$CurrentTextArea->{'setval'}}($CurrentTextArea->{'page'}, $text);
}
    
## main functionality

# reload the current page
sub reload {
    return 0 unless my $Page = getPage;
    my $request = $Page->request;
    my $force = shift;
    if ( ($request->method eq 'POST') and not $force ) {
        msg('"!" not given, resubmit form data? ([y]/n)', 0);
        my $resubmit = VIM::Eval('nr2char(getchar())');
        return 0 if lc($resubmit) eq 'n';
    }
    my $buffer = $Page->buffer;
    my $NewPage = handleRequest($request, 'show', $buffer);
    return 0 unless $NewPage;
    # the old page is about to be destroyed, but it shares the buffer with 
    # the new one. Setting this flag will keep us from wiping out the buffer 
    # in the DESTROY method.
    $Page->{'keepbuffer'} = 1;
    CurWin->setPage($NewPage);
    return 1;
}

# browse to a given location. The location is taken directly from the user, 
# and supports the bookmark notation. If an extra argument is given, it 
# forces opening a new window. If the argument is empty, split horizontally, 
# if it is '!' split vertically. If no extra argument is given, split 
# (horizontally) only if there is no open browser window
sub browse {
    my $uri = shift || $HomePage;
    $uri = canonical(split ' ', $uri);
    return unless defined $uri;
    return unless defined checkScheme($uri);
    my $vert = $_[0] || '';
    my $cmd = '';
    $vert =~ tr/!/v/;
    my @sidebar = sidebar();
    debug("SIDEBAR: @sidebar");
    my $found = goBrowser(@sidebar);
    if ( $found ) {
        debug("  found $found");
        if ( @sidebar ? $sidebar[0] eq $found : not @_ ) {
            $cmd = undef;
        } else {
            $cmd = "${vert}new";
        }
    } else {
        $cmd = @sidebar ? 'topleft vnew' : 'wincmd b | new';
    }
    if ( $cmd ) { 
        debug("new window command is '$cmd'");
        newWindow($cmd, @sidebar);
    }
            
    CurWin()->openNew($uri);
    unless ( CurWin->page ) {
        # no page is associated to the window, we didn't really open anything 
        # in vim, delete the Window object
        delete $Browser->{CurWin->id};
        CurWin(undef);
        $CursorWin = undef;
        doCommand('quit');
    }
}

# form input methods.

# rotate input values for 'option' and 'radio' inputs. Arguments are the 
# offset (default 1) and the link (default current). For 'radio', the 
# rotation is cyclic.
sub nextInputChoice {
    my $offset = shift || 1;
    my $page = $CursorWin->page;
    my $link = findLink(shift);
    return unless $link;
    my $input = $link->{'input'};
    my $type = $input->type;
    my $form = $link->{'form'};
    my $name = $input->name;
    my $encoding = $page->header('encoding') || $AssumedEncoding;
    if ( $type eq 'option' ) {
        my $value = &{$link->{'getval'}}($page);
        my @values = map { encode_utf8(decode($encoding, $_)) } 
            $input->value_names;
        my %index;
        @index{@values} = 0..$#values;
        my $index = $index{$value} + $offset;
        &{$link->{'setval'}}($page, $values[$index]) 
            unless ($index > $#values or $index < 0);
    } elsif ( $type eq 'radio' ) {
        my @values = 
            grep { $_->{'input'}->type eq 'radio' and 
                   $_->{'input'}->name eq $name } @{$form->{'vimdata'}};
        my ($value) = grep { &{$_->{'getval'}}($page) eq '*' } @values;
        my %index;
        @index{@values} = 0..$#values;
        my $index = ($index{$value} + $offset) % scalar(@values);
        &{$value->{'setval'}}($page, ' ');
        &{$values[$index]->{'setval'}}($page, '*');
    }
}

# change the value of a form input. Input is the link (default current).
sub clickInput {
    my $page = $CursorWin->page;
    my $link = findLink(shift);
    return unless $link;
    my $form = $link->{'form'};
    return unless $form;
    my $input = $link->{'input'};
    my $name = $input->name;
    my $type = $input->type;
    my $value = &{$link->{'getval'}}($page);
    my $encoding = $page->header('encoding') || $AssumedEncoding;
    if ( $type eq 'text' ) {
        $Vim::Option{'l:modifiable'} = 1;
        doCommand('startinsert!');
    } elsif ( $type eq 'submit' ) {
        follow($link);
    } elsif ( $type eq 'file' ) {
        my $file = Vim::browse(0, 'Choose a file to attach');
        &{$link->{'setval'}}($page, $file);
    } elsif ( $type eq 'checkbox' ) {
        &{$link->{'setval'}}($page, $value eq 'X' ? ' ' : 'X');
    } elsif ( $type eq 'radio' ) {
        foreach (@{$form->{'vimdata'}}) {
            next unless ($_->{'input'}->type eq 'radio' and 
                         $_->{'input'}->name eq $name);
            if (&{$_->{'getval'}}($page) eq '*') {
                &{$_->{'setval'}}($page, ' ');
                last;
            };
        };
        &{$link->{'setval'}}($page, '*');
    } elsif ( $type eq 'option' ) {
        if ( $link->{'multi'} ) {
            &{$link->{'setval'}}($page, $value eq 'X' ? ' ' : 'X');
        } else {
            my @values = map { chomp; encode_utf8(decode($encoding, $_)) } 
                $link->{'input'}->value_names;
            my @ind = (1..9, 'a'..'z')[0..$#values];
            my $choices = join('\n', 
                               map { '&' . shift(@ind) . ". $_" } @values);
            my $ind = VIM::Eval("confirm('', \"$choices\")" );
            return unless $ind;
            &{$link->{'setval'}}($page, $values[$ind-1]);
        }
    } elsif ( $type eq 'password' ) {
        my $response = VIM::Eval("inputsecret('?')");
        &{$link->{'setval'}}($page, $response);
    } elsif ( $type eq 'textarea' ) {
        # for some reason, pedit triggers the BufLeave autocommand, so we 
        # make sure it does nothing
        undef $CurrentTextArea;
        doCommand("pedit Browser-TextArea-$name");
        doCommand('wincmd P');
        $Vim::Option{'l:buftype'} = 'nofile';
        chomp(my @text = split /^/, $input->value);
        $main::curbuf->Append(0, @text) if @text;
        $CurrentTextArea = $link;
        $CurrentTextArea->{'page'} = $page;
    } else { return };
}

# submit the form of the given (or current) input
sub submit {
    my $link = findLink shift;
    unless ( $link and $link->{'form'} ) {
        Vim::error('No input to submit');
        return;
    }
    my $page = $CursorWin->page;
    my $form = $link->{'form'};
    my @submit = grep { $_->{'target'} } @{$form->{'vimdata'}};
    unless ( @submit ) {
        Vim::Error('Unable to find submit button');
        return;
    }
    follow( shift @submit );
}

# follow the link under the cursor
sub follow {
    my $link = findLink(shift);
    if ($link) {
        if ( my $target = $CursorWin->page->linkTarget($link) ) {
            if ( defined($target = checkScheme($target)) ) {
                my ($oldSidebar) = sidebar();
                $Vim::Variable{'g:browser_sidebar'} = $CursorWin->id() if 
                    ($link->{'sidebar'} and not isRegular($CursorWin->id()));
                debug("Opening in " . (sidebar() ? 'sidebar' : 'main'));
                goBrowser;
                debug('following in win ' . CurWin->id) if defined(CurWin());
                unless (defined CurWin) {
                    my @sidebar = sidebar();
                    my $cmd = @sidebar ? 'topleft vnew' : 'wincmd b | new';
                    newWindow($cmd, @sidebar);
                }
                CurWin->openNew($target);
                $Vim::Variable{'g:browser_sidebar'} = $oldSidebar;
            }
        } elsif ( $link->{'form'} ) {
            clickInput($link);
        }
    } else {
        Vim::error($CursorWin->page . ': No link at this point!');
    }
}

# save the contents of the link under the cursor to a given file. The file is 
# either given as an argument, or is prompted from the user.
sub saveLink {
    my $link = $CursorWin->getLink;
    if ($link and not ref $link) {
        return 0 unless defined($link = checkScheme($link));
        handleRequest($link, 'save', @_);
    } else {
        Vim::error($CursorWin->page . ': No link at this point!');
        return 0;
    }
}

# this is called when clicking the right mouse button, to build the context 
# menu in a context sensitive way
sub buildMenu {
    my $link = $CursorWin->page->findLink;
    if ( $link ) {
        doCommand('menu .1 PopUp.Follow\\ Link :BrowserFollow<CR>');
        doCommand('menu .1 PopUp.Save\\ Link :BrowserSaveLink<CR>');
    } else {
        doCommand('unmenu PopUp.Follow\\ Link');
        doCommand('unmenu PopUp.Save\\ Link');
    }
    $link = $CursorWin->page->findLink(1);
    if ( $link ) {
        doCommand('menu .1 PopUp.View\\ Image :BrowserImageView<CR>');
        doCommand('menu .1 PopUp.Save\\ Image :BrowserImageSave<CR>');
    } else {
        doCommand('unmenu PopUp.View\\ Image');
        doCommand('unmenu PopUp.Save\\ Image');
    }
    if ( @{$CursorWin->back} ) {
        doCommand('menu .1 PopUp.Back :BrowserBack<CR>');
    } else {
        doCommand('unmenu PopUp.Back');
    }
    if ( @{$CursorWin->forward} ) {
        doCommand('menu .1 PopUp.Forward :BrowserForward<CR>');
    } else {
        doCommand('unmenu PopUp.Forward');
    }

}

# handle the inline image under the cursor. All args are passed to 
# handleRequest()
sub handleImage {
    my $image = $CursorWin->page->findLink(1);
    my $link = $CursorWin->getLink($image);
    if ($link) {
        return 0 unless defined($link = checkScheme($link));
        my $name = $link;
        $name =~ s!^.*/!!o;
        handleRequest($link, @_, $name);
    } else {
        Vim::error($CursorWin->page . ': No image at this point!');
        return 0;
    }
}

# find the n-th next/previous link, relative to the cursor position. n is 
# given as the first parameter. It's sign determines between prev and next.
# If an extra argument is given and true, look for images instead.
sub findNextLink {
    my ($row, $col) = Vim::cursor();
    my $count = shift;
    my $dir = $count < 0 ? -1 : 1;
    my ($link, $offset);
    while ( $dir * $count > 0 ) {
        ($link, $offset) = $CursorWin->page->findNextLink($dir, $row, $col, @_);
        if ( $link ) {
            $row += $offset;
            $col = $link->{'from'};
            Vim::cursor($row, $col);
            $count -= $dir;
        } else { last };
    }
    unless ( $link ) {
        msg('No further links', 2);
        return;
    }
    showLinkTarget($link);
}

# scroll the text in the textarea
sub scrollText {
    my $page = $CursorWin->page;
    my $link = findLink;
    ($link) = $page->findNextLink(-1, Vim::cursor()) unless $link;
    unless ( $link and defined $link->{'displayline'} ) {
        msg('Not on a text area', 2);
        return;
    }
    my $lines = shift || 1;
    $link->{'displayline'} += $lines;
    &{$link->{'setval'}}($page);
    1;
}

# show the history for the current window
sub showHist {
    return unless getPage;
    $CurWin->showHist;
}

# go back/forward in history
sub goHist {
    return unless getPage;
    CurWin()->goHist(@_);
}

# add/remove header fields for the page
sub addHeader {
    return unless my $Page = getPage;
    $Page->addHeader;
}

sub removeHeader {
    return unless my $Page = getPage;
    $Page->removeHeader;
}

# close the sidebar
sub closeSidebar {
    $Vim::Variable{'g:browser_sidebar'} = 'foo';
    VIM::DoCommand('quit') while goBrowser;
    if ( $noResize ) {
        $Vim::Option{'columns'} -= $SidebarWidth;
        $noResize = 0;
    }
    $Vim::Variable{'g:browser_sidebar'} = '';
}

# view the page source. The argument says whether to split it horizontally 
# ('') or vertically ('!')
sub viewSource {
    return unless my $Page = getPage;
    my $dir = shift;
    $dir =~ tr/!/v/;
    $Page->viewSource($dir . 'new');
}

# update the browser after changing the source. This is called by the 
# 'Update' command, installed by the viewSource method
sub updateSource {
    my $page = $Page[shift];
    $page->response->content(
        join("\n", $main::curbuf->Get(1..$main::curbuf->Count())));
    goBrowser();
    my $new = pageFromResponse($page->response, $page->buffer);
    $page->{'keepbuffer'} = 1;
    CurWin()->setPage($new);
    $new;
}

# bookmark the current page under the given nickname. The description will 
# come from the title. If the extra argument is true, delete the given 
# bookmark.
sub bookmark {
    unless ( $AddressBookDir ) {
        Vim::error(<<'EOF');
Bookmarks are disabled. To enable bookmarks, 
set g:browser_addrbook_dir to an absolute path
EOF
        return undef;
    }
    local $_ = shift;
    my $bang = shift;
    my $book = s/^:?([^:]*)://o ? $1 : $CurrentBook;
    $book = $CurrentBook unless $book;
    if ( $bang ) {
        delete $AddrBook{$book}->{$_};
    } else {
        my $Page = getPage();
        unless ( $AddrBook{$book} ) {
            tie my %book, 'VIM::Browser::AddrBook', 
                catfile($AddressBookDir, $book);
            $AddrBook{$book} = \%book;
        }
        $AddrBook{$book}->{$_} = ["$Page->{'uri'}", $Page->title];
    }
}

# change to the bookmark file given by the first argument. If the second 
# argument is true, change to this file even if it does not exist. This book 
# will be the one whose bookmarks are used without mentioning the book name
sub changeBookmarkFile {
    my ($file, $create) = @_;
    my $book = $AddrBook{$file};
    if ( $book ) {
        my $bf = tied(%$book)->{'file'};
        unless ( -w $bf ) {
            Vim::warning("Bookmark file $bf not writeable");
        }
    } elsif ( not $AddressBookDir ) {
        Vim::error(<<'EOF');
Bookmarks are disabled. To enable bookmarks, 
set g:browser_addrbook_dir to an absolute path
EOF
        return;
    } elsif ( not $create ) {
        Vim::error("Bookmark file '$file' doesn't exist (use ! to create)");
        return;
    }
    $CurrentBook = $file;
    msg("Bookmark file is now '$CurrentBook'");
}
    
# list all bookmarks in the given/current bookmark file
sub listBookmarks {
    my $book = $_[0] ? $_[0] : $CurrentBook;
    my $abook = $AddrBook{$book};
    if ( $abook ) {
        tied(%$abook)->list;
    } else {
        Vim::error("Bookmarks file $book does not exist");
    }
}

#### completion functions

# to complete bookmark file names (relative to $AddressBookDir)
sub listBookmarkFiles {
    my %files = map { $_ => 1 } 
                    map { listDirFiles($_, 0) } 
                        ( $AddressBookDir, @AddrBookDirs );
    return join("\n", map {basename $_} keys %files);
}

# to complete (extended) uris
sub listBrowse {
    my ($Arg, $CmdLine, $Pos) = @_;
    if ( $Arg !~ /^:/o ) {
        # we have a decent uri or a file name
        my $Uri = 0;
        if ( lc($Arg) =~ /^file:/o ) {
            $Arg = (new URI $Arg)->file;
            $Uri = 1;
        } elsif ( $Arg =~ m{^(\w+):/}o and 
                  # allow drive letters on windows
	          not ( $^O eq 'MSWin32' and length($1) == 1 ) ) {
            # can't complete anything but files
            return '';
        }
        my $Dir = catpath((splitpath($Arg))[0..1]);
        my @List = listDirFiles($Dir, 1);
        # Don't use catfile here since it removes the trailing slash!
        # @List = map { catfile($Dir, $_) } @List if $Dir;
        #@List = map { "$Dir$_" } @List if $Dir;
        @List = map { (new URI::file $_)->as_string } @List if $Uri;
        return join("\n", @List);
    }
    if ( $Arg =~ /^:([^:]*):/o ) {
        # complete a bookmark from the given bookmarks file
        my $book = $1 ? $1 : $CurrentBook;
        return join("\n", map { ":$1:$_" } keys %{$AddrBook{$book}});
    } else {
        # complete a bookmarks file
        my $res = listBookmarkFiles();
        $res =~ s/^/:/mgo;
        $res =~ s/$/:/mgo;
        return $res;
    }
}

1;

__DATA__

# start of POD

=head1 NAME

VIM::Browser - perl part of the vim browser plugin

=head1 DESCRIPTION

This module is part of the vim(1) B<browser> plugin. It contains the 
implementation of all the functionality, except for the HTML translation, 
which is performed by L<HTML::FormatText::Vim>. It is not very useful by 
itself.

If you are looking for the documentation of the browser plugin, it's in the 
F<browser.pod> file. If you are looking for documentation about the 
implementation, look at the comments in the body of this source file.

=head1 SEE ALSO

This modules uses the perl modules:

L<URI>, L<URI::Heuristic>, L<URI::file>, L<LWP::UserAgent>, L<LWP::Protocol>, 
L<LWP::Protocol::file>, L<HTML::Form>, L<HTTP::Cookies>, L<HTTP::Response>, 
L<HTTP::Response>, L<HTTP::Status>, L<HTTP::Date>

From cpan, and also

L<HTML::FormatText::Vim>, L<Vim>, L<Mailcap>

from the browser plugin distribution.

The documentation of the browser plugin is in F<browser.pod>

=head1 AUTHOR

Moshe Kaminsky <kaminsky@math.huji.ac.il> - Copyright (c) 2004

=head1 LICENSE

This program is free software. You may copy or 
redistribute it under the same terms as Perl itself.

=cut

