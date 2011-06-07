package BawiX::Board::Poll;
use strict;
use warnings;
use Carp;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
    add_poll
    add_opt
    add_ans
	get_pollset
);


our ($DBH, %TBL);
$TBL{poll}      = 'bw_xboard_poll';
$TBL{opt}       = 'bw_xboard_poll_opt';
$TBL{ans}       = 'bw_xboard_poll_ans';

1;
