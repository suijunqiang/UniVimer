# File Name: Vim.pm
# Maintainer: Moshe Kaminsky <kaminsky@math.huji.ac.il>
# Last Modified: Tue 15 Mar 2005 11:27:17 AM IST
###########################################################
package HTML::TreeBuilder::Encode;
use HTML::TreeBuilder;
use base qw(HTML::TreeBuilder);
use Encode;

sub text {
    my $self = shift;
    my $text = decode_utf8(shift);
    $self->SUPER::text($text, @_);
}

package HTML::FormatText::Vim;
use Data::Dumper;
use URI;
use Vim;
use Encode;
use Math::BigInt;
sub INF { Math::BigInt->binf() }

use warnings;
use integer;

BEGIN {
    our $VERSION = 1.1;
}

# translation from attribute names (as in the perl modules and the vim 
# variables) to html tag names. This also determines the possible values.  
# Therefore, changes here should be reflected in the syntax files
our %Markup = qw(
    Bold       b
    Underline  u
    Italic     i 
    Teletype   tt
    Strong     strong
    Em         em
    Code       code
    Kbd        kbd
    Samp       samp
    Var        var
    Definition dfn
);

sub new {
    my ($class, %args) = @_;
    my $self = \%args;
    bless $self => $class;
}

sub formatSubtree {
    my ($self, $node) = @_;
    if ( ref $node ) {
        my $tag = $node->tag;
        my $func = "${tag}_start";
        $self->{'nextfragment'} = $node->attr('id') if $node->attr('id');
        my $goon = $self->can($func) ? (eval { $self->$func($node) } || $@) : 1;
        if ( $goon ) {
            $self->formatSubtree($_) foreach $node->content_list;
            $func = "${tag}_end";
            eval { $self->$func($node) } if $self->can($func);
        }
    } else {
        # got text
        eval { $self->textflow($node) };
    }
}

sub format_string {
    my $self = shift;
    my $tree = new HTML::TreeBuilder::Encode;
    $tree->parse(shift);
    $tree->eof();

    # $tree->dump if $Vim::Option{'verbose'};

    $tree->simplify_pres();
    $tree->number_lists();
    $self->begin();
    $self->formatSubtree($tree);
    $tree->delete();
    return $self->{'output'};
}

sub begin {
    my $self = shift;
    $self->{'curpos'} = 0;  # current output position.
    $self->{'line'} = 0; # current line number
    $self->{'hspace'} = 0;  # horizontal space pending flag
    $self->{'vspace'} = -1;
    $self->{'formcount'} = 0; # current form in the list of forms
    $self->{'output'} = '';
    $self->{'pre'} = 0;
    $self->{'links'} = [];
    $self->{'images'} = [];
    $self->{'markup'} = [];
    $self->{'nextmarkup'} = [];
    $self->{'fragment'} = {};
}

###############################################
# The elements
###############################################

# completely ignored elements (all contents is ignored)
for my $element ( qw(head script style del) ) {
    my $func = "${element}_start";
    *$func = sub { 0; };
}

#### links and anchors ####

sub add_link {
    my ($self, $target, $text) = @_;
    $target = new URI $target;
    my $relative = not defined $target->scheme();
    $target = $target->abs($self->{'base'});
    $text =~ tr/\n/ /;
    $self->out($text);
    push @{$self->{'links'}[$self->{'line'}]}, {
        target => $target->as_string,
        text => $text,
        from => $self->{'prepos'},
        to => $self->{'curpos'} - 1,
        sidebar => $relative,
    };
    1;
}

sub a_start {
    my $self = shift;
    my $node = $_[0];
    $self->{'lasttext'} = '';
    $self->{'href'} = $node->attr('href');
    1;
}

sub a_end {
    my $self = shift;
    my $node = $_[0];
    my $text = delete $self->{'lasttext'};
    if (my $target = delete $self->{'href'}) {
        $self->add_link($target, $text);
        if ( my $imgdata = delete $self->{'image'} ) {
            $imgdata->{'from'} = $self->{'prepos'};
            $imgdata->{'to'} = $self->{'curpos'} - 1;
            push @{$self->{'images'}[$self->{'line'}]}, $imgdata;
        }
    } else {
        $self->out($text);
    }
    $self->{'nextfragment'} = $node->attr('name') if $node->attr('name');
    1;
}

sub img_start {
    my($self,$node) = @_;
    my $alt = $node->attr('alt');
    my $text = defined($alt) ? $alt ? "{$alt}" : '' : '{IMAGE}';
    return 1 unless $text;
    $self->textflow( $text, 1 );
    my $target = URI->new_abs($node->attr('src'), $self->{'base'});
    my $imgdata = {
        target => $target->as_string,
        text => $text,
    };
    if ( $self->{'href'} ) {
        # we're in the middle of a link - keep the data to be added when the 
        # link info is available (a_end)
        $self->{'image'} = $imgdata;
    } else {
        $imgdata->{'from'} = $self->{'prepos'} + 1;
        $imgdata->{'to'} = $self->{'curpos'} - 2;
        push @{$self->{'images'}[$self->{'line'}]}, $imgdata;
    }
    1;
}

#### frames ####
sub frame_start {
    my ($self, $node) = @_;
    $self->out(('  ' x $self->{'framelevel'}) . 'FRAME: ');
    $self->add_link($node->attr('src'), ( $node->attr('name') || '[open]'));
    $self->vspace(0);
    1;
}

sub noframes_start {
    shift->hr_start();
    1;
}

sub frameset_start {
    my ($self, $node) = @_;
    if ( exists $self->{'framelevel'} ) {
        $self->{'framelevel'}++;
    } else {
        $self->{'framelevel'} = 0;
    }
    $self->vspace(1);
    1;
}

sub frameset_end {
    my $self = shift;
    $self->{'framelevel'}--;
    $self->vspace(1);
    1;
}

#### forms ####
sub form_start {
    my $self = shift;
    $self->{'form'} = $self->{'forms'}[$self->{'formcount'}++];
    1;
}

sub form_end {
    shift->vspace(1);
    1;
}

# TODO: need to sort this out
sub label_start {
    shift->{'hspace'} = 1;
    1;
}

sub do_checkbox {
    my ($self, $node, $form, $type) = @_;
    my ($line, $from, $to, $update, $getVal, $setVal);
    my @inputs = $form->find_input($node->attr('name'), $type);
    my $value = $node->attr('value');
    my $input;
    if ( defined $value ) {
        ($input) = grep { grep { $_ and ($_ eq $value) } $_->possible_values } 
                        @inputs;
    } else {
        ($input) = @inputs;
    }
    $self->out( '[' . 
        (($node->attr('checked') or $node->attr('selected')) ? 'X' : ' ') . 
                ']' );
    $from = $to = $self->{'curpos'} - 2;
    $line = $self->{'line'};
    $getVal = sub {
        substr(shift->getLine($line), $from, 1)
    };
    $setVal = sub {
        my $page = shift;
        my $text = $page->getLine($line);
        substr($text, $from, 1) = shift;
        $page->setLine($line, $text);
    };
    $update = sub {
        $input->value(&$getVal(shift) eq 'X' ? $value : undef);
    };
    return ($input, $line, $from, $to, $update, $getVal, $setVal);
}

sub input_start {
    my ($self, $node) = @_;
    my $type = lc($node->attr('type'));
    $type = 'text' unless $type;
    my $form = $self->{'form'};
    #return 1 unless $form;
    my $input = $form->find_input($node->attr('name'), $type);
    my ($line, $from, $to, $update, $target, $getVal, $setVal);
    if ( $type eq 'text' ) {
        my $value = $input->value;
        $self->out( "]> " );
        $line = $self->{'line'};
        $from = $self->{'curpos'} - 1;
        $to =  INF;
        $self->out($value);
        $getVal = sub {
            my $text = shift->getLine($line);
            my $res = substr($text, $from);
            $res =~ s/^\s*//o;
            $res =~ s/\s*$//o;
            $res
        };
        $setVal = sub {
            my $page = shift;
            my $text = $page->getLine($line);
            substr($text, $from) = shift;
            $page->setLine($line, $text);
        };
        $update = sub {
            $input->value(&$getVal(shift));
        };
        $self->vspace(0);
    } elsif ( $type eq 'submit' or $type eq 'image' ) {
        my $value = $node->attr('value') || 'Submit'; #  || "\u$type";
        $self->out( $value );
        $line = $self->{'line'};
        $to = $self->{'curpos'} - 1;
        $from = $self->{'prepos'};
        $setVal = $getVal = $update = sub { 1 };
        $target = sub {
            my $obj = shift;
            map { &{$_->{'update'}}($obj) } @{$form->{'vimdata'}};
            my $req = $input->click($form, 1, 1);
        };
    } elsif ( $type eq 'radio' ) {
        $self->out( '(' . ($node->attr('checked') ? '*' : ' ') . ')' );
        $from = $to = $self->{'curpos'} - 2;
        $line = $self->{'line'};
        my $value = $node->attr('value');
        $getVal = sub {
            substr(shift->getLine($line), $from, 1)
        };
        $setVal = sub {
            my $page = shift;
            my $text = $page->getLine($line);
            substr($text, $from, 1) = shift;
            $page->setLine($line, $text);
        };
        $update = sub {
            $input->value($value) if &$getVal(shift) eq '*';
        };
    } elsif ( $type eq 'checkbox' ) {
        ($input, $line, $from, $to, $update, $getVal, $setVal) = 
            $self->do_checkbox($node, $form, $type);
    } elsif ( $type eq 'password' ) {
        my $size = $node->attr('size') || 6;
        $self->out( '[' . '_' x $size . ']' );
        $to = $self->{'curpos'} - 2;
        $from = $to - $size + 1;
        $line = $self->{'line'};
        # getval will return whether this is set or not
        $getVal = sub { $input->value ? 1 : 0 };
        $setVal = sub {
            my $page = shift;
            my $value = shift;
            $input->value($value);
            my $text = $page->getLine($line);
            substr($text, $from, $size) = ($value ? '#' : '_') x $size;
            $page->setLine($line, $text);
        };
        $update = sub { 1 };
    } elsif ( $type eq 'file' ) {
        my $size = $node->attr('size') || 15;
        $size = 10 if $size < 10;
        $self->out( '[-<Browse>-'. ('-' x ($size - 10)) . ']' );
        $to = $self->{'curpos'} - 2;
        $from = $to - $size + 1;
        $line = $self->{'line'};
        $getVal = sub { $input->value };
        $setVal = sub {
            my $page = shift;
            my $value = shift;
            $value =~ s/^\s*//o;
            $value =~ s/\s*$//o;
            $input->value($value);
            $value = '-<Browse>-'. ('-' x ($size - 10)) unless $value;
            my $text = $page->getLine($line);
            substr($text, $from, $size) = substr($value, -$size);
            $page->setLine($line, $text);
        };
        $update = sub { 1 };
    } else {
        return
    }
    my $inDesc = {
        form => $form,
        input => $input,
        from => $from,
        to => $to,
        update => $update,
        target => $target,
        getval => $getVal,
        setval => $setVal,
    };
    push @{$self->{'links'}[$line]}, $inDesc;
    push @{$form->{'vimdata'}}, $inDesc;
    1;
}

sub select_start {
    my ( $self, $node ) = @_;
    if ( $node->attr('multiple') ) {
        $self->{'multi'} = 1;
        return 1;
    }
    my $form = $self->{'form'};
    #return 1 unless $form;
    my $name = $node->attr('name');
    my $input = $form->find_input($name, 'option');
    my @values = map { decode($self->{'encoding'}, $_) } $input->value_names;
    my $len = 0;
    my @lens = map { length(encode_utf8 $_) } @values;
    map { $len = $_ if $_ > $len } @lens;
    my $selval = $input->value;
    my ($selected) = grep { $input->value($_); $input->value eq $selval } 
                          $input->value_names;
    $selected = decode($self->{'encoding'}, $selected);
    $self->out("[$selected" . ( ' ' x ($len - length($selected))) . ']');
    my $line = $self->{'line'};
    my $to = $self->{'curpos'} - 2;
    my $from = $self->{'prepos'} + 1;
    my ($update, $getVal, $setVal);
    $getVal = sub {
        my $text = shift->getLine($line);
        my $res = substr($text, $from, $len);
        $res =~ s/^\s*//o;
        $res =~ s/\s*$//o;
        $res
    };
    $setVal = sub {
        my $page = shift;
        my $text = $page->getLine($line);
        substr($text, $from, $len) = sprintf("%-${len}s", shift);
        $page->setLine($line, $text);
    };
    $update = sub {
        $input->value(decode_utf8(&$getVal(shift)));
    };
    my $inDesc = {
        form => $form,
        input => $input,
        from => $from,
        to => $to,
        update => $update,
        target => undef,
        getval => $getVal,
        setval => $setVal,
    };
    push @{$self->{'links'}[$line]}, $inDesc;
    push @{$form->{'vimdata'}}, $inDesc;
    1;
}

sub select_end {
    my $self = shift;
    $self->vspace(1) if delete $self->{'multi'};
    1;
}

sub option_start {
    my ($self, $node) = @_;
    return 0 unless $self->{'multi'};
    my $form = $self->{'form'};
    #return 1 unless $form;
    $self->vspace(0);
    my ($input, $line, $from, $to, $update, $getVal, $setVal) =
        $self->do_checkbox($node, $form, 'option');
    my $inDesc = {
        form => $form,
        input => $input,
        from => $from,
        to => $to,
        update => $update,
        target => undef,
        getval => $getVal,
        setval => $setVal,
        multi => 1,
    };
    push @{$self->{'links'}[$line]}, $inDesc;
    push @{$form->{'vimdata'}}, $inDesc;
    1;
}

sub option_end {
    shift->vspace(0);
    1;
}

sub textarea_start {
    my ($self, $node) = @_;
    my $form = $self->{'form'};
    #return 1 unless $form;
    my $name = $node->attr('name');
    my $input = $form->find_input($name, 'textarea');
    my $lines = $node->attr('rows') || 10;
    my ($line, $update, $getVal, $setVal);
    $self->vspace(0);
    my $text = '--- Click to edit the text area ---';
    my $width = $self->{'rm'} - $self->{'lm'};
    $self->out($text . ('-' x ( $width - length($text) - 4) ) . ' {{{');
    $line = $self->{'line'};
    my $value = $input->value;
    my $clines = $lines;
    foreach ( split /^/, $value ) {
        chomp;
        Vim::debug("Adding $_ ($clines)", 3);
        $self->vspace(0);
        $self->pre_out($_);
        Vim::debug('Line is now ' . $self->{'line'}, 3);
        last unless --$clines;
    }
    Vim::debug("Adding $clines empty lines", 3);
    $self->vspace($clines);
    $self->out('}}} ' . ( '-' x ($width - 4 )));
    Vim::debug('Line is now ' . $self->{'line'}, 3);
    $getVal = sub { $input->value };
    $setVal = sub {
        my $page = shift;
        my $value = shift;
        if (defined $value) {
            $input->value($value);
        } else {
            $value = $input->value;
        }
        $page->updateTextArea($line, $lines);
    };
    $update = sub { 1 };
    my $inDesc = {
        form => $form,
        input => $input,
        from => $self->{'lm'},
        to => $self->{'rm'},
        update => $update,
        target => undef,
        getval => $getVal,
        setval => $setVal,
        displayline => 0,
    };
    push @{$self->{'links'}[$line]}, $inDesc;
    push @{$form->{'vimdata'}}, $inDesc;
    0;
}

#### headers ####

# shape of the underline for the i-th header
my @line = qw(= - ^ + " .);

for my $level ( 1..6 ) {
    my $start = "h${level}_start";
    my $end = "h${level}_end";
    *$start = sub { shift->header_start($level, @_) };
    *$end = sub { shift->header_end($level, @_) };
}

sub header_start {
    my($self, $level, $node) = @_;
    no integer;
    $self->vspace(1 + (6-$level) * 0.4);
    use integer;
    my $align = $node->attr('align') || '';
    $self->center_start if lc($align) eq 'center';
    push @{$self->{'nextmarkup'}}, {
        kind => "Header$level",
        start => 1,
        sline => $self->{'line'},
    };
    1;
}

sub header_end {
    my ($self, $level, $node) = @_;

    $self->pre_out('');
    push @{$self->{'markup'}[$self->{'line'}]}, {
        kind => "Header$level",
        start => 0,
        col => $self->{'curpos'} - 1,
        line => $self->{'line'},
    };
    $self->vspace(0);
    $self->out($line[$level-1] x ($self->{'curpos'} - $self->{'lm'}));
    my $align = $node->attr('align') || '';
    $self->center_end if lc($align) eq 'center';
    $self->vspace(1);
    1;
}

#### style markup ####
for my $markup ( keys %Markup ) {
    my $start = $Markup{$markup} . '_start';
    my $end = $Markup{$markup} . '_end';
    *$start = sub {
        my $self = shift;
        push @{$self->{'nextmarkup'}}, {
            kind => $markup,
            start => 1,
            sline => $self->{'line'},
        };
        1;
    };
    *$end = sub {
        my $self = shift;
        $self->pre_out('');
        if ( $self->{'href'} or $self->{'selecttext'} ) {
            push @{$self->{'nextmarkup'}}, {
                kind => $markup,
                start => 0,
                sline => $self->{'line'},
            };
        } else {
            push @{$self->{'markup'}[$self->{'line'}]}, {
                kind => $markup,
                start => 0,
                col => $self->{'curpos'} - 1,
                line => $self->{'line'},
            };
        }
        1;
    }
}

sub cite_start {
    my $self = shift;
    $self->textflow('`');
    push @{$self->{'nextmarkup'}}, {
        kind => 'Cite',
        start => 1,
        sline => $self->{'line'},
    };
    1;
}

sub cite_end {
    my $self = shift;
    $self->textflow("'");
    if ( $self->{'href'} or $self->{'selecttext'} ) {
        push @{$self->{'nextmarkup'}}, {
            kind => 'Cite',
            start => 0,
            sline => $self->{'line'},
        };
    } else {
        push @{$self->{'markup'}[$self->{'line'}]}, {
            kind => 'Cite',
            start => 0,
            col => $self->{'curpos'} - 1,
            line => $self->{'line'},
        };
    }
    1;
}

#### large scale document structure ####
sub hr_start {
    my $self = shift;
    $self->vspace(1);
    $self->out('-' x ($self->{rm} - $self->{lm}));
    $self->vspace(1);
    1;
}

sub br_start {
    shift->vspace(0, 1);
    1;
}

sub p_start {
    shift->vspace(1);
    1;
}

sub p_end {
    shift->vspace(1);
    1;
}

sub center_start {
    my $self = shift;
    $self->{'center'}++;
    $self->{'oldlm'} = $self->{'lm'};
    $self->{'oldrm'} = $self->{'rm'};
    my $width = $self->{'rm'} - $self->{'lm'};
    $self->{'lm'} += $width / 10;
    $self->{'rm'} -= $width / 10;
    1;
}

sub center_end {
    my $self = shift;
    $self->{'center'}--;
    $self->vspace(1);
    return 1 if $self->{'center'};
    $self->{'lm'} = $self->{'oldlm'};
    $self->{'rm'} = $self->{'oldrm'};
    1;
}

sub div_start {
    my($self, $node) = @_;
    my $align = $node->attr('align') || '';
    return $self->center_start if lc($align) eq 'center';
    1;
}

sub div_end {
    my($self, $node) = @_;
    my $align = $node->attr('align') || '';
    return $self->center_end if lc($align) eq 'center';
    $self->vspace(1);
}

sub nobr_start {
    shift->{'nobr'}++;
    1;
}

sub nobr_end {
    shift->{'nobr'} = 0;
}

sub wbr_start {
    shift->{'hspace'} = 2;
    1;
}

sub pre_start {
    my $self = shift;
    $self->vspace(0);
    $self->out('~>');
    $self->adjust_lm(2);
    $self->adjust_rm(-2);
    $self->{'pre'}++;
    $self->{'prestart'} = 1;
    $self->vspace(0);
    1;
}

sub pre_end {
    my $self = shift;
    $self->adjust_lm(-2);
    $self->adjust_rm(2);
    chomp($self->{'output'});
    # we _don't_ want vspace here, because we don't want to go to the lm
    $self->nl;
    $self->out('<~');
    $self->vspace(0);
    $self->{'pre'}--;
}

sub listing_start      { shift->pre_start( @_ ) }
sub listing_end        { shift->pre_end(   @_ ) }
sub     xmp_start      { shift->pre_start( @_ ) }
sub     xmp_end        { shift->pre_end(   @_ ) }

sub blockquote_start {
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm( +2 );
    $self->adjust_rm( -2 );
    1;
}

sub blockquote_end {
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm( -2 );
    $self->adjust_rm( +2 );
}

sub address_start {
    my $self = shift;
    $self->vspace(1);
    $self->i_start(@_);
    1;
}

sub address_end {
    my $self = shift;
    $self->i_end(@_);
    $self->vspace(1);
}

#### tables - need serious improvement (TODO) ####

sub table_start { 
    shift->vspace(1);
    1;
}

sub table_end { 
    shift->vspace(1);
    1;
}

sub tr_start {
    my $self = shift;
    $self->{'rowstart'} = 1;
    1;
}

sub tr_end { shift->vspace(0); 1; }

sub td_start {
    my $self = shift;
    if ( $self->{'rowstart'} ) {
        $self->{'rowstart'} = 0;
    } else {
        $self->out(' ');
    }
    1;
}

sub th_start {
    my $self = shift;
    if ( $self->{'rowstart'} ) {
        $self->{'rowstart'} = 0;
    } else {
        $self->out(' ');
    }
    $self->b_start(@_);
}

sub th_end { shift->b_end(@_) }

#### lists and list elements ####
sub ul_start {
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm( +2 );
    1;
}

sub ul_end {
    my $self = shift;
    $self->adjust_lm( -2 );
    $self->vspace(1);
}

sub li_start {
    my $self = shift;
    $self->bullet( shift->attr('_bullet') || () );
    $self->adjust_lm(+2);
    1;
}

sub li_end {
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm( -2);
}

sub menu_start      { shift->ul_start(@_) }
sub menu_end        { shift->ul_end(@_) }
sub  dir_start      { shift->ul_start(@_) }
sub  dir_end        { shift->ul_end(@_) }

sub ol_start {
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm(+2);
    1;
}

sub ol_end {
    my $self = shift;
    $self->adjust_lm(-2);
    $self->vspace(1);
}

sub dl_start {
    my $self = shift;
    $self->vspace(1);
    1;
}

sub dl_end {
    my $self = shift;
    $self->vspace(1);
}

sub dt_start {
    my $self = shift;
    $self->vspace(1);
    1;
}

sub dd_start {
    my $self = shift;
    $self->adjust_lm(+6);
    $self->vspace(0);
    1;
}

sub dd_end {
    my $self = shift;
    $self->vspace(1);
    $self->adjust_lm(-6);
}

#########################################
# Utilities
#########################################

sub bullet {
    my $self = shift;
    $self->vspace(0);
    $self->out(@_ ? shift() . ' ' : '');
}

sub vspace {
    my ($self, $lines, $add) = @_;
    if ($lines > $self->{'vspace'}) {
        $self->{'vspace'} = $lines;
    } elsif ($add) {
        $self->{'vspace'} += $add;
    }
    1;
}

sub adjust_lm {
    my $self = shift;
    my $lm = $self->{'lm'} += shift;
    my $shift = $lm - $self->{'curpos'};
    if ( $shift > 0 ) {
        $self->{'curpos'} = $lm;
        $self->collect(' ' x $shift);
    }
}

sub adjust_rm {
    $_[0]->{'rm'} += $_[1];
}

sub nl {
    my $self = shift;
    $self->{'line'}++;
    $self->{'curpos'} = 0;
    $self->collect("\n");
    1;
}

sub do_vspace {
    my $self = shift;
    my $vspace = @_ ? shift : -1;
    $vspace = $self->{'vspace'} if ($self->{'vspace'} > $vspace);
    if ( $vspace >= 0 ) {
        $self->nl() while $vspace-- >= 0;
        $self->{'vspace'} = -1;
        $self->{'hspace'} = 0;
        $self->{'curpos'} = $self->{'lm'};
        $self->collect(' ' x $self->{'lm'});
    }
}

sub textflow {
    my $self = shift;
    if ( $self->{'href'} or exists $self->{'selecttext'}) {
        $self->{'lasttext'} .= shift;
    } else {
        if ($self->{'pre'} or $_[1]) {
            # Strip one leading newline so that a <pre> tag can be placed on 
            # a line of its own without causing extra vertical space as part 
            # of the preformatted text.
            if ( $self->{'prestart'} ) {
                $_[0] =~ s/^\n//;
                $self->{'prestart'} = 0;
            }
            $self->pre_out( $_[0] );
        } else {
            for (split(/(\s+)/, $_[0])) {
                next unless length;
                $self->out($_);
            }
        }
    }
    1;
}

sub pre_out {
    my $self = shift;
    $self->do_vspace;
    my @lines = split /^/, shift;

    push @{$self->{'markup'}[$self->{'line'}]}, 
        map { $_->{'col'} = $self->{'curpos'}; 
              $_->{'line'} = $self->{'line'};
              $_ 
          } @{$self->{'nextmarkup'}};
    $self->{'nextmarkup'} = [];

    foreach ( @lines ) {
        my $nl = chomp;
        $_ = encode_utf8 $_;
        $self->collect($_);
        if ( $nl ) {
            $self->do_vspace(0);
        } else {
            $self->{'prepos'} = $self->{'curpos'};
            $self->{'curpos'} += length;
        }
    }
    1;
}

sub out {
    my $self = shift;
    my $text = shift;
    return unless defined $text;

    if ($text =~ /^\s*$/) {
        $self->{hspace} = 1;
        return;
    }

    $text =~ tr/\x{a0}/ /;
    my $len = length $text;
    $text = encode_utf8 $text;

    $text =~ tr/\x{0d}//d;

    $self->do_vspace;
    
    $self->{'fragment'}{delete $self->{'nextfragment'}} = $self->{'line'} 
        if $self->{'nextfragment'};
    if ($self->{'hspace'}) {
        if ($self->{'curpos'} + $len > $self->{'rm'} and 
            ($self->{'hspace'} > 1 or 
             (not $self->{'nobr'} and $self->{'breaklines'})) ) {
            # word will not fit on line; do a line break
            $self->do_vspace(0);
        } else {
            # word fits on line; use a space
            $self->collect(' ');
            ++$self->{'curpos'};
            Vim::debug("Added ' ', curpos is " . $self->{'curpos'}, 4);
        }
        $self->{'hspace'} = 0;
    }
    
    $self->collect($text);
    $self->{'prepos'} = $self->{'curpos'};
    $self->{'curpos'} += $len;
    Vim::debug("Added '$text', curpos is " . $self->{'curpos'}, 4);

    push @{$self->{'markup'}[$self->{'line'}]}, map { 
        $_->{'col'} = $_->{'start'} ? $self->{'prepos'} 
                                    : $self->{'curpos'} - 1;
        $_->{'line'} = $self->{'line'};
        $_ 
    } @{$self->{'nextmarkup'}};
    $self->{'nextmarkup'} = [];

    1;
}

sub collect {
    my $self = shift;
    $self->{'output'} .= shift;
    1;
}

1;

__DATA__

# start of POD

=head1 NAME

HTML::FormatText::Vim - format html for displaying using the vim browser

=head1 DESCRIPTION

This module is part of the vim(1) B<browser> plugin. It is used to format 
html before displaying it in a vim buffer. I don't think it's very useful by 
itself.

=head1 SEE ALSO

L<HTML::TreeBuilder>, L<HTML::Element>

This module used to be a derived class of L<HTML::FormatText> (and hence of 
L<HTML::Formatter>). This is no longer so. The reason is that I had to 
override many of the methods, including some of the main ones, so I didn't 
gain much from this inheritance. It also appears that the HTML-Format package 
is a rarely satisfied dependency. I therefore imitated (some times 
mouse-copied) some of the methods of those modules, especially those of 
L<HTML::Formatter>, and made the rquired changes.

The documentation of the plugin is available in the file F<browser.pod> in 
the plugins distribution.

=head1 AUTHOR

Moshe Kaminsky <kaminsky@math.huji.ac.il> - Copyright (c) 2004

=head1 LICENSE

This program is free software. You may copy or 
redistribute it under the same terms as Perl itself.

=cut
