

@lorem = (
"Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
"Nam pulvinar rhoncus justo in molestie.",
"Nunc neque lectus, rhoncus at rhoncus ac, congue et est.",
"In vel faucibus nisl, a lacinia dolor.",
"Vivamus molestie risus ligula, ac interdum diam tristique et.",
"Etiam finibus quis nunc at aliquet.",
"In mattis sagittis justo quis elementum.",
"Etiam at malesuada augue.",
"Suspendisse ut eros posuere erat pulvinar varius at eu risus.",
"Etiam imperdiet, augue vitae rutrum mollis, enim tellus efficitur tortor, non maximus leo tellus at massa.",
"Donec in dui a lacus hendrerit viverra.",
"Sed in iaculis elit, sed ultrices sem.",
"Etiam facilisis sem a erat vestibulum, eu accumsan est dignissim.",
"Sed posuere pharetra ex, in egestas velit varius eget.",
"Pellentesque vel neque velit.",
);

#print $lorem[3],"\n";
$s = scalar @lorem;
print "sizeof lorem = [$s]\n";

@context = (
"NETW",
"PROC",
"OFF_HOURS",
"AUTH",
"BUSINESS_HOURS",
"EMAIL",
"NGINX",
);
$c = scalar @context;
print "sizeof context = [$c]\n";

srand;
while(<>)
{

  $inputline = $_;
  chop $inputline;

  next if length $inputline < 5;

  $c1 = int(rand($c));
  $cont = $context[$c1];
 
  $a1 = int(rand($s));
  $line1 = $lorem[$a1];
 
  $a2 = int(rand($s));
  $line2 = $lorem[$a2];
 
  $a3 = int(rand($s));
  $line3 = $lorem[$a3];

  $rule = int(rand(10000));

  $outputline = $inputline . "|" . $cont . "|" . $rule . "|" . $line1 . " " .  $line2 . " " .  $line3;

# print "[$a1,$a2,$a3]  $outputline\n\n";
  print "$outputline\n\n";

}
