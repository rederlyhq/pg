##########################################################################
#
#  Implements "fuzzy" real numbers (two are equal when they are "close enough")
#

package Value::Real;
my $pkg = 'Value::Real';

use strict;
use vars qw(@ISA);
@ISA = qw(Value);

use overload
       '+'   => sub {shift->add(@_)},
       '-'   => sub {shift->sub(@_)},
       '*'   => sub {shift->mult(@_)},
       '/'   => sub {shift->div(@_)},
       '**'  => sub {shift->power(@_)},
       '.'   => sub {shift->_dot(@_)},
       'x'   => sub {shift->cross(@_)},
       '<=>' => sub {shift->compare(@_)},
       'cmp' => sub {shift->compare_string(@_)},
       'neg' => sub {shift->neg},
       'abs' => sub {shift->abs},
       'sqrt'=> sub {shift->sqrt},
       'exp' => sub {shift->exp},
       'log' => sub {shift->log},
       'sin' => sub {shift->sin},
       'cos' => sub {shift->cos},
     'atan2' => sub {shift->atan2(@_)},
  'nomethod' => sub {shift->nomethod(@_)},
        '""' => sub {shift->stringify(@_)};

#
#  Check that the input is a real number or a formula
#  or a string that evaluates to a number
#
sub new {
  my $self = shift; my $class = ref($self) || $self;
  my $x = shift; $x = [$x,@_] if scalar(@_) > 0;
  return $x if ref($x) eq $pkg;
  $x = [$x] unless ref($x) eq 'ARRAY';
  Value::Error("Can't convert ARRAY of length %d to %s",scalar(@{$x}),Value::showClass($class)) 
    unless (scalar(@{$x}) == 1);
  if (Value::isRealNumber($x->[0])) {
    return $self->formula($x->[0]) if Value::isFormula($x->[0]);
    return (bless {data => $x}, $class);
  }
  $x = Value::makeValue($x->[0]);
  return $x if Value::isRealNumber($x);
  Value::Error("Can't convert %s to %s",Value::showClass($x),Value::showClass($class));
}

#
#  Check that result is a number
#
sub make {
  my $self = shift;
  return $self->SUPER::make(@_) unless $_[0] eq "nan";
  Value::Error("Result is not a real number");
}

#
#  Create a new formula from the number
#
sub formula {
  my $self = shift; my $value = shift;
  Value::Formula->new($value);
}

#
#  Return the real number type
#
sub typeRef {return $Value::Type{number}}
sub length {1}

#
#  return the real number
#
sub value {(shift)->{data}[0]}

sub isZero {shift eq "0"}
sub isOne {shift eq "1"}


##################################################

#
#  Return a real if it already is one, otherwise make it one
#
sub promote {
  my $x = shift;
  return $x if (ref($x) eq $pkg && scalar(@_) == 0);
  return $pkg->new($x,@_);
}
#
#  Get the data from the promoted item
#
sub promoteData {@{(promote(shift))->data}}

##################################################
#
#  Binary operations
#

sub add {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->add($l,!$flag)}
  $r = promote($r);
  return $pkg->make($l->{data}[0] + $r->{data}[0]);
}

sub sub {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->sub($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $tmp}
  return $pkg->make($l->{data}[0] - $r->{data}[0]);
}

sub mult {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->mult($l,!$flag)}
  $r = promote($r);
  return $pkg->make($l->{data}[0]*$r->{data}[0]);
}

sub div {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->div($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $tmp}
  Value::Error("Division by zero") if $r->{data}[0] == 0;
  return $pkg->make($l->{data}[0]/$r->{data}[0]);
}

sub power {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->power($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $tmp}
  my $x = $l->{data}[0]**$r->{data}[0];
  return $pkg->make($x) unless $x eq 'nan';
  Value::Error("Can't raise a negative number to a power") if ($l->{data}[0] < 0);
  Value::Error("result of exponention is not a number");
}

sub compare {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->compare($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $tmp}
  my ($a,$b) = ($l->{data}[0],$r->{data}[0]);
  if ($l->getFlag('useFuzzyReals')) {
    my $tolerance = $l->getFlag('tolerance');
    if ($l->getFlag('tolType') eq 'relative') {
      my $zeroLevel = $l->getFlag('zeroLevel');
      if (abs($a) < $zeroLevel || abs($b) < $zeroLevel) {
	     $tolerance = $l->getFlag('zeroLevelTol');
      } else {
	     $tolerance = $tolerance * abs($a);
      }
    }
    return 0 if abs($a-$b) < $tolerance;
  }
  return $a <=> $b;
}

##################################################
#
#   Numeric functions
#

sub abs {$pkg->make(CORE::abs(shift->{data}[0]))}
sub neg {$pkg->make(-(shift->{data}[0]))}
sub exp {$pkg->make(CORE::exp(shift->{data}[0]))}
sub log {$pkg->make(CORE::log(shift->{data}[0]))}

sub sqrt {
  my $self = shift;
  return $pkg->make(CORE::sqrt($self->{data}[0]));
}

##################################################
#
#   Trig functions
#

sub sin {$pkg->make(CORE::sin(shift->{data}[0]))}
sub cos {$pkg->make(CORE::cos(shift->{data}[0]))}

sub atan2 {
  my ($l,$r,$flag) = @_;
  if ($l->promotePrecedence($r)) {return $r->atan2($l,!$flag)}
  $r = promote($r);
  if ($flag) {my $tmp = $l; $l = $r; $r = $l}
  return $pkg->make(CORE::atan2($l->{data}[0],$r->{data}[0]));
}

##################################################

sub string {
  my $self = shift; my $equation = shift; my $prec = shift;
  my $n = $self->{data}[0];
  my $format = ($equation->{context} || $$Value::context)->{format}{number};
  if ($format) {
    $n = sprintf($format,$n);
    if ($format =~ m/#\s*$/) {$n =~ s/(\.\d*?)0*#$/$1/; $n =~ s/\.$//}
  }
  $n = uc($n); # force e notation to E
  $n = 0 if abs($n) < $self->getFlag('zeroLevelTol');
  $n = "(".$n.")" if ($n < 0 || $n =~ m/E/i) && defined($prec) && $prec >= 1;
  return $n;
}

sub TeX {
  my $n = (shift)->string(@_);
  $n =~ s/E\+?(-?)0*([^)]*)/\\times 10^{$1$2}/i; # convert E notation to x10^(...)
  return $n;
}


###########################################################################

1;
