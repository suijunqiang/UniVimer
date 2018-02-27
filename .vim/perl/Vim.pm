# File Name: Vim.pm
# Maintainer: Moshe Kaminsky <kaminsky@math.huji.ac.il>
# Last Update: Sat 20 Nov 2004 09:50:24 PM IST
###########################################################

package VIM::Tie::Option;
use base 'Tie::Hash';

sub TIEHASH {
    bless {} => shift;
}

sub FETCH {
    my $res = VIM::Eval('&' . $_[1]);
}

sub STORE {
    my ($self, $Opt, $Value) = @_;
    unless ( $Value+0 eq $Value ) {
        # string value
        $Value =~ s/'/''/g;
        $Value = "'$Value'";
    }
    VIM::DoCommand('let &' . "$Opt=$Value");
}

package VIM::Tie::Vars;
use base 'Tie::Hash';

sub TIEHASH {
    bless {} => shift;
}

sub FETCH {
    my $res = $_[0]->EXISTS($_[1]) ? VIM::Eval($_[1]) : undef;
}

sub STORE {
    my ($self, $Var, $Value) = @_;
    unless ( $Value+0 eq $Value ) {
        # string value
        $Value =~ s/'/''/g;
        $Value = "'$Value'";
    }
    VIM::DoCommand("let $Var=$Value");
}

sub EXISTS {
    my $res = VIM::Eval("exists('$_[1]')");
}

sub DELETE {
    VIM::DoCommand("unlet! $_[1]");
}

package VIM::Scalar;
use base 'Tie::Scalar';
use Carp;

sub TIESCALAR {
    my ($class, $var, $default, $sub) = @_;
    croak 'Must supply the name of a vim variable' unless $var;
    croak "Third argument must be a code ref" 
        if (defined $sub and ref($sub) ne 'CODE');
    my $self = { 
        var => $var,
        default => $default,
        'sub' => $sub || sub { $_[0] },
    };
    bless $self => $class;
}

sub FETCH {
    my $self = shift;
    my $res = $Vim::Variable{$self->{'var'}};
    $res = $self->{'default'} unless defined $res;
    &{$self->{'sub'}}($res);
}

sub STORE {
    my ($self, $val) = @_;
    $Vim::Variable{$self->{'var'}} = $val;
}

package VIM::Sys;
use Mailcap;

sub new {
    my $class = shift;
    unshift @Mailcap::MAILCAPS, @_;
    $Mailcap::TERM = undef unless $Vim::Has{'gui_running'}; 
    bless { } => $class;
}

sub AUTOLOAD {
    return if our $AUTOLOAD =~ /::DESTROY$/o;
    Vim::error("$AUTOLOAD not implemented on $^O");
}

sub viewDef {
    my $self = shift;
    my $type = shift;
    my $file = shift;
    my $prog = $self->viewCmd($type, $file);
    if ( $prog ) {
        return $self->spawn($prog, @_);
    } else {
        0;
    }
}

sub viewCmd {
    my $self = shift;
    my ($entries, @progs) = Mailcap::getView { 1 } @_;
    for my $i ( 0..$#progs ) {
        $progs[$i] .= ' |' if $entries->[$i]->copiousoutput;
    }
    wantarray ? @progs : shift @progs;
}

sub viewWith {
    my ($self, $ctype, $file, $cleanup, $prog) = @_;
    my $term;
    $prog = Vim::browse(0, 
        "Choose a program to open files of type $ctype" . 
        '\n(use %s for the file name), add "|" in the end for filter', 
        '/usr/bin', '') unless $prog;
    if ( $prog ) {
        $prog = Mailcap::interpolate( $prog, 
            s => $file,
            t => $ctype,
            ':term' => undef,
        );
        return $self->spawn($prog, $cleanup);
    } else {
        0;
    }
}

sub spawn {
    my ($self, $cmd, $cleanup) = @_;
    if ( $cmd =~ /\|$/o ) {
        # copiousoutput
        open(my $PH, $cmd) or return;
        my @data = <$PH>;
        &$cleanup($cmd) if $cleanup;
        return [@data];
    }
    # if we got here, we run an external program and forget all about it
    my $pid = fork;
    # bail out if we failed to fork
    &$cleanup($cmd) if $cleanup and not defined $pid;
    # parent returns and goes on with its life
    return $pid if ($pid or not defined $pid);
    # in the child we run the command, and wait till it's finished for 
    # cleanup
    system $cmd;
    &$cleanup($cmd) if $cleanup;
    # a funny way to exit, but we dont want to trigger END blocks, etc
    exec '/bin/true';
}

package VIM::Sys::MSWin32;
push @ISA, 'VIM::Sys';

package VIM::Sys::Unix;
push @ISA, 'VIM::Sys';

package VIM::System;

my $Sys;

sub mailcap {
    if ( @_ or not $Sys ) {
        $Sys = $^O eq 'MSWin32' ? new VIM::Sys::MSWin32 @_ : 
                                  new VIM::Sys::Unix @_;
    }
    $Sys
}


for my $sub (qw(spawn viewDef viewCmd viewWith)) {
    *$sub = sub { mailcap->$sub(@_) };
}

package Vim;
use base 'Exporter';
use Encode;

our @EXPORT_OK = qw(%Option %Variable error warning msg ask debug bufWidth 
                    cursor fileEscape);

use Tie::Memoize;

BEGIN {
    our $VERSION = 1.1;
}

tie our %Option, 'VIM::Tie::Option';
tie our %Variable, 'VIM::Tie::Vars';
tie our %Has, 'Tie::Memoize', sub {
    my $res = VIM::Eval("has('" . shift() . "')");
    $res ? $res : () 
};

sub error {
    VIM::Msg("@_", 'ErrorMsg');
}

sub warning {
    VIM::Msg("@_", 'WarningMsg');
}

sub msg {
    VIM::Msg("@_", 'Type');
}

sub ask {
    my $vimCmd = $Option{'guioptions'} =~ /c/ ? 'input' : 'inputdialog';
    my $res = VIM::Eval("$vimCmd(" . join(',', map { "'$_'" } @_) . ')');
}

sub browse {
    my ($save, $msg, $initdir, $default) = @_;
    $dir = '' unless defined $dir;
    $default = '' unless $default;
    my $cmd;
    if ( $save < 0 ) {
        if ( VIM::Eval("exists('*browsedir')") ) {
            $cmd = "browsedir('$msg', '$dir')";
        } else {
            $save = 0;
        }
    }
    $cmd = "browse($save, '$msg', '$dir', '$default')" unless $cmd;
    my $res = $Vim::Has{'browse'} ? VIM::Eval($cmd) : ask("$msg ", $default);
}

sub debug {
    my $msg = shift;
    my $verbose = shift || 1;
    my ($pack, $file, $line, $sub) = caller(1);
    ($pack, $file, $line) = caller;
    msg("$sub($line): $msg") if $Option{'verbose'} >= $verbose;
}

sub bufWidth {
    my $width = $Option{'l:textwidth'};
    $width =  VIM::Eval('winwidth(0)') - $Option{'l:wrapmargin'} unless $width;
    $width;
}

# get/set the cursor position in characters. Thanks to Antoine J. Mechelynck 
# for the idea.
sub cursor {
    # get the current position
    my ($row, $col) = $main::curwin->Cursor();
    my $line = decode_utf8($main::curbuf->Get($row));
    use bytes;
    my $part = substr($line, 0, $col);
    no bytes;
    $col = length(decode_utf8($part));
    if ( @_ ) {
        my ($new_r, $new_c) = @_;
        $line = decode_utf8 $main::curbuf->Get($new_r);
        $part = substr($line, 0, $new_c);
        use bytes;
        $new_c = length($part);
        no bytes;
        $main::curwin->Cursor($new_r, $new_c);
    }
    return ($row, $col);
}

sub fileEscape {
    local $_ = shift;
    s/([?:%#])/\\$1/go;
    tr/?/%/ if $^O eq 'MSWin32';
    $_
}
    

__DATA__

# start of POD

=head1 NAME

Vim - General utilities when using perl from within I<vim>

=head1 SYNOPSIS

    perl <<EOF
    use Vim qw(%Option msg ask);

    $Option{'filetype'} = 'perl'; # set the filetype option
    $lines = $Vim::Variable{'b:foo'}; 
                        # get the value of the b:foo variable

    msg('perl is nice');
    $file = ask('Which file to erase?', '/usr/bin/emacs');

    tie $vimbin, 'VIM::Scalar',
        'g:vim_bin',                    # vim name of the variable
        'gvim',                         # default value
        sub { '/usr/bin/' . shift };    # add path to the value
    EOF

=head1 DESCRIPTION

This is a small module with utility functions for easier access to vim's 
facilities when working with perl. It provides the following exportable 
utilities:

=over

=item VIM::Scalar

A class to tie a perl variable to a vim variable. Reading the value of the 
will read the current value of the vim variable, and setting it will set the 
vim variable. The syntax is

C<tie $var, 'VIM::Scalar',> B<vim-var>[, B<default>[, B<sub>]]

Where I<$var> is the perl variable, B<vim-var> is a string containing the 
name of the vim variable, B<default>, if given is the value I<$var> will have 
if there is no vim variable by this name (if B<default> is not given, I<$var> 
will be C<undef> in this situation), and B<sub>, if given, is a sub ref that 
will be applied to the value (whether it comes from an actual vim variable, 
or the default value). The sub should accept the value, and return a modified 
value.

=item VIM::System

A few utilities for running system commands from within vim. Currently 
implemented the same way for all platforms (which is the correct way on 
unix). It uses the L<Mailcap> module. Provides the following functions:

=over

=item viewCmd

        $cmd = viewCmd($content_type, $filename)

Returns the command to view a given file with a given content type. 
Basically, the same as L<Mailcap/"getView">, except that an entry with the 
I<copiousoutput> field will be returned with a bar (B<E<verbar>>) in the end. 
This is makes it suitable for feeding to L</"spawn">.

=item viewDef

        viewDef($content_type, $filename)

View the given file, which has the given content type, with the default 
viewer, as returned by L</"viewCmd">. The return value is the return value of 
L</spawn>.

=item viewWith

       viewWith($content_type, $filename, $cleanup [, $prog])

View the given file, which has the given content type, with the supplied 
program B<$prog>. If the program is not supplied, prompt the user for one. 
B<$prog> may contain escape sequences B<%s> and B<%t> for the file name and 
content type, respectively, which will be interpolated using 
L<Mailcap/interpolate>. B<$cleanup> is passed as a second argument to 
L</spawn>. The return value is the return value of L</spawn>.

=item spawn

        $out = spawn($cmd, $cleanup)

Runs the given external command B<$cmd>. If B<$cmd> ends with a pipe 
(B<E<verbar>>), captures the output, and returns it as an array ref of lines. 
Otherwise, runs B<$cmd> in a forked child (and returns nothing). B<$cleanup>, 
if given, should be a code ref, which is run after the command is executed, 
typically to remove temporary files.

=back

=item %Option

A (magical) hash to set and get the values of vim options. When setting, the 
value is treated as a string unless it is numeric. Thus

        $Option{'lines'} = 30;

and

        $Option{'filetype'} = 'perl';

will both work, but

        $Option{'backupext'} = '1';

will not.

=item %Variable

A hash to set and get values of vim variables. Any legal vim variable name 
can be used (include C<b:> prefixes, etc.). When getting the value of a 
variable that does not exist, the result is C<undef>. The same rules apply 
with regard to string and numeric values as for options.

S<C<delete $Variable{'b:foo'}> > will unlet the variable, 
S<C<exists $Variable{'s:bar'}> > checks if the variable is defined.

=item %Has

C<$Has{'foo'}> will be true if vim's I<has('foo')> is true.

=item msg(), warning(), error()

Produce the given message, warning or error. Any number of arguments are 
allowed, and they are concatenated.

=item ask()

ask the user a question. The arguments and their meaning are the same as for 
vim's I<input()> function. The function will call I<input()> or  
I<inputdialog> depending on the C<c> option in B<guioptions>.

=item debug()

Produce the message given in the first argument, but only if the value of the 
C<verbose> option is at least the second argument (1 by default).

=item browse()

Does the same as vim's I<browse()>, except it works also when vim is 
compiled without B<+browse>, in which case it just asks for a file. If the 
first argument (I<save>) is negative, opens a directory requester.

=item bufWidth()

Returns the current buffer width according to the settings of B<textwidth> 
and B<wrapmargin>

=item cursor()

Similar to C<$curwin-E<gt>Cursor>, and has the same signature, but works in 
characters and not bytes.

=item fileEscape()

Escape characters in the given expression, so that the result can be used as 
a plain file name in vim.

=back

=head1 SEE ALSO

L<Mailcap>, vim(1)

=head1 AUTHOR

Moshe Kaminsky <kaminsky@math.huji.ac.il> - Copyright (c) 2004

=cut

