package XML::Ligero;
use strict;

use Exporter 5.57 'import';
our @EXPORT_OK = qw(xpath);
our $VERSION = 0.12;

sub xpath{
  local $_ = shift;
  my $qr_na = qr/(?:[a-zA-Z_](?:[-.\w]*:?[-.\w]+)?)/;
  #my $qr_va = qr/(?:"[^"<]*"|'[^'<]*')/;
  my $qr_va = qr/(?:"[^"]*"|'[^']*')/;
  my $qr_at = qr/(?:$qr_na\s*=\s*$qr_va\s*)/;
  my $qr_ta = qr%^(?:($qr_na)\s*($qr_at*)(/?)|/($qr_na)\s*|!--(.*)--|\?(.*)\?)$%s;
  my ($s,$p,$cwd,@t,$e,$i,$t,@x) = (1,0,''); #state, position, curWorkDir, openedTags, error, index, currentTag, xPath
  while($s && length substr $_,$p){
    ($s,$p,$e) = 60==ord substr($_,$p,1)?(2,$p+1):(0,$p,"< expected at $p")              if $s == 1;
    ($s,$p,$e) = ($i=index$_,'>',$p)>0 ? (3,$p) : (0,$p,"> expected at $p")              if $s == 2;
    ($s,$p,$e) = substr($_,$p,$i-$p)=~/$qr_ta/ ? (4,$i+1) : (0,$p,"error at $p")         if $s == 3;
    ($s,$t,$e) = ( 5, { fqn=>$1,  type=>$3?'single':'opened',  data=>$2             } )  if $s == 4 && $1;
    ($s,$t,$e) = ( 5, { fqn=>$4,  type=>            'ending'                        } )  if $s == 4 && $4;
    ($s,$t,$e) = ( 8, {           type=>            'commnt',  data=>$5             } )  if $s == 4 && $5;
    ($s,$t,$e) = ( 8, {           type=>            'instrc',  data=>$6             } )  if $s == 4 && $6;
    ($s,$t,$e) = ( 0,             undef,            "qr_ta regex error at $i"         )  if $s == 4;
    if(                                                                                     $s == 5){
      ($$t{prefix},$$t{name}) = $$t{fqn} =~ /(?:([^:]+):)?(.*)/;
      $$t{prefix} ||= '_default';
      my $P = $t[$#t];
      my %ns = %{$$P{ns}} if $P;
      $ns{_default} ||= 'http://_default';
      $$t{ns} = \%ns;
      if($$t{type} eq 'ending'){
        if(!$P || $$P{prefix} ne $$t{prefix} || $$P{name} ne $$t{name}){
          ($s,$e) = (0,"parsing error: nodes $$P{name} and $$t{name} closing error at position $i");
        }else{
          $s = 8;
          $cwd =~ s!/[^/]+$!!;
          pop @t;
        }
      }else{
        $cwd .= "/$$t{fqn}";
        my (@attr,%n,$k);
        push @attr,$1,substr$2,1,-1 while defined $$t{data} && $$t{data}=~s/\s*($qr_na)\s*=\s*($qr_va)\s*//;
        my %attr = @attr;
        if(scalar @attr){
          for(grep ++$k%2, @attr){
            if(exists $n{$_}){
              ($s,$e) = (0,"parsing error: attribute '$_' is not unique at position $i");
              last;
            }else{
              push @x,"$cwd\[\@$_='$attr{$_}']"}}
        }else{
          push @x,$cwd}
        $$t{attr} = \@attr;
        $$t{ns} = {%ns, map /xmlns:(\S+)/ ? ($1,$attr{$_}) : (_default=>$attr{$_}), grep /^xmlns(?::\S+)?/, keys %attr};
        if($$t{type} eq 'opened'){
          $s = 6; 
          push @t,$t;
        }else{
          $s = 8;
          $cwd =~ s!/[^/]+$!!;
        }}}
    ($s,$p,$e) = substr($_,$p)=~/^(\s*[^\s<][^<]*)/ ? (7,$p+length$1) : (8,$p)           if $s == 6;
    push @x,$1 and $s-=6                                                                 if $s == 7;
    ($s,$p,$e) = substr($_,$p)=~/^(\s*)(?:<|$)/ ? (1,$p+length$1) : (0,$p,"error at $p") if $s == 8}
  $e = 'parsing error: tag '.$t[$#t]->{fqn}." not closed at position $p" if scalar @t;
  $e ? $e : \@x;
}

1;
