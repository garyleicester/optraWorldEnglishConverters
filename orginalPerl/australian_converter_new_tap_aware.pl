#!/usr/local/bin/perl

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';
use utf8;

$wordlist = shift;

open(WORDLIST, "$wordlist") || die "Unable to open wordlist data";
binmode(WORDLIST, ":utf8");

while (<WORDLIST>) {

$line = $_;

chomp $line;
$line =~ s/\r//g;
$line =~ s/\n//g;

if ($line =~ /^Headword$/) { next; }

$NEED{$line} = "$line";

}

close(WORDLIST);

my $orthconsonants = "qwrtypsdfghjklzxcvbnm";
my $orthvowels = "euioa";
my $phoneticconsonants = "pbtdkɡtʃʒfvθðszhmnŋlrjwxˈˌ";
my $phoneticconsonants2 = "pbtdkɡtʃʒfvθðszhmnŋlrjwx";
my $phoneticconsonants2lessrj = "pbtdkɡtʃʒfvθðszhmnŋlwx";
my $phoneticconsonants2notjod = "pbtdkɡtʃʒfvθðszhmnŋlrwx";
my $phoneticconsonants2notr = "pbtdkɡtʃʒfvθðszhmnŋljwx";
my $phoneticconsonants2notjodw = "pbtdkɡtʃʒfvθðszhmnŋlrx";
my $phoneticconsonantsnostress = "pbkɡʒvθðmnŋrjxdt";
my $phoneticvowels = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəoa~ːˈˌ";
my $phoneticvowels2 = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəoaT"; # T to stand for trap/bath
my $phoneticvowels2b = "ɐeæɑɒɛɔuʌɜoa";
my $phoneticvowels2noschwa = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜoa";
my $phoneticvowels3 = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəa";
my $phoneticvowels4 = "æaɒɛʌ";
my $phoneticvowels5 = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəoa~ː";
my $removeforstressdetection = "ɐiɪeæɑɒɔʊuʌɛɜəoaːpbtdkɡtʃʒfvθðszhmnŋlrjwx";

# we're going to need more context

while (<STDIN>) {

$line = $_;

chomp $line;
$line =~ s/\r//g;
$line =~ s/\n//g;

if ($line =~ /<orthography[^>]*?>([^<]+?)<\/orthography>/) { $orth = $1; } else { next; }

$norm = $orth;
$norm =~ tr/[A-Z]/[a-z]/;
$norm =~ s/[^a-z0-9]//g;
undef $hasbre;
if ($line =~ /<pronunciation_group[^>]+?model_and_variety="o[^_]+?_brit[^>]+?><pronunciation[^>]+?><transcription[^>]+?>[^<]/i) { $hasbre = "yes"; }

unless ($NEED{$orth}) {
if ($hasbre eq "yes") { $BYNORMFORM{$norm} = "$orth"; }
next; }

if ($line =~ /OED_AUSTRALIAN_ENGLISH/) { print "$orth\t####ALREADY_DEALT_WITH####\n"; delete($NEED{$orth}); next; } # already have AusE prongroup(s). no need to create.

# targeted devariant

@devariant = ($line =~ /(<pronunciation_group[^>]+?model_and_variety="OPTRA_brit".*?\/pronunciation_group>)/g);
@devarianttwo = ($line =~ /(<pronunciation_group[^>]+?model_and_variety="ODO_BRITISH".*?\/pronunciation_group>)/g);

push(@devariant,@devarianttwo);

foreach $prongroup(@devariant) {

$prongroupbefore = $prongroup;

$prongroup =~ s/<audio[^>]+?\/>//g; $prongroup =~ s/<audio[^>]+?><\/audio>//g;
$prongroup =~ s/<explicit_exclusion.*?\/explicit_exclusion>//g;

while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ɔː([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2ɒ\3(<\/transcription><\/pronunciation>)/$1$2ɒ$3$4/) { } #warn "-- ɔː then ɒ - keep ɒ\n"; 
while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ɒ([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2ɔː\3(<\/transcription><\/pronunciation>)/$1$2ɒ$3$4/) { } #warn "-- ɒ then ɔː - keep ɒ\n"; 

while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ʃ([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2ʒ\3(<\/transcription><\/pronunciation>)/$1$2ʒ$3$4/) { } #warn "-- ʃ then ʒ - keep ʒ\n"; 
while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ʒ([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2ʃ\3(<\/transcription><\/pronunciation>)/$1$2ʒ$3$4/) { } #warn "-- ʒ then ʃ - keep ʒ\n"; 

while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)i([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2eɪ\3(<\/transcription><\/pronunciation>)/$1$2eɪ$3$4/) { } #warn "-- i then eɪ - keep eɪ\n"; 
while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)eɪ([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2i\3(<\/transcription><\/pronunciation>)/$1$2eɪ$3$4/) { } #warn "-- eɪ then i - keep eɪ\n"; 

while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)trɑːn([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2tran\3(<\/transcription><\/pronunciation>)/$1$2tran$3$4/) { } #warn "-- i then eɪ - keep eɪ\n"; 
while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)tran([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2trɑːn\3(<\/transcription><\/pronunciation>)/$1$2tran$3$4/) { } #warn "-- eɪ then i - keep eɪ\n"; 

#attempt at trap bath
while ($prongroup =~ s/(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ɑː([^<]*?)(<\/transcription><\/pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2a\3(<\/transcription><\/pronunciation>)/$1$2T$3$4/) { } #warn "-- ɑː then a - trap bath\n"; 


$line =~ s/\Q$prongroupbefore\E/$prongroup/;

}

####

@selectbrits = (); @morebrits = (); @selectus = (); @moreus = ();

@selectbrits = ($line =~ /(<pronunciation_group[^>]+?model_and_variety="OPTRA_brit".*?\/pronunciation_group>)/g);
@morebrits = ($line =~ /(<pronunciation_group[^>]+?model_and_variety="ODO_BRITISH".*?\/pronunciation_group>)/g);

push(@selectbrits,@morebrits); $britchunk = join('',@selectbrits);

@selectus = ($line =~ /(<pronunciation_group[^>]+?model_and_variety="OPTRA_us".*?\/pronunciation_group>)/g);
@moreus = ($line =~ /(<pronunciation_group[^>]+?model_and_variety="ODO_US".*?\/pronunciation_group>)/g);

push(@selectus,@moreus); $uschunk = join('',@selectus);

#@brits = ($britchunk =~ /<transcription[^>]*?>([^<]+?)<\/transcription>/g);
@brits = ($britchunk =~ /<pronunciation_group[^>]+?><pronunciation[^>]+?><transcription[^>]*?>([^<]+?)<\/transcription>/g); # limit to first phon of group
@uses = ($uschunk =~ /<transcription[^>]*?>([^<]+?)<\/transcription>/g);

unless (@brits) { next; }
delete($NEED{$orth}); # if we've reached this point we can check it off the list

foreach $phon(@brits) {

@syllabs = split '(?=[\. ˈˌ])', $phon;

undef $newphon;

undef $iamsyllable;
undef $truenextcounter;

$needastress = "no";

foreach $bit(@syllabs) { 

if ($bit =~ /[^ˈˌ \.]/) { $iamsyllable++; }
$truenextcounter++;
#$iamsyllable++;

#$bit =~ s/ə\(ʊ\)/əʊ/;
$bit =~ s/ə\(ʊ\)/əʊ/;
$bit =~ s/s\(j\)uː/suː/;
#$bit =~ s/u$/ʊ/;
$bit =~ s/u$/uː/;

$nextsyl = $syllabs[$truenextcounter];

if (($bit !~ /[$phoneticvowels2]/) && ($bit =~ /[lmn]/) && ($bit !~ /̩/)) { $bit =~ s/^(.*?)([lmn])([^lmn]*?)$/$1(ə)$2$3/; }

if ($bit =~ s/eɪ/æe/) { }
elsif (($bit =~ /ʊə/) && ($nextsyl !~ /^[ˈˌ \.\(]*?r/)) { $bit =~ s/ʊə/uːə/; $needastress = "yes"; } #CURE
elsif (($bit =~ /ʊə/) && ($nextsyl =~ /^[ˈˌ \.\(]*?r/)) { $bit =~ s/ʊə/uː/; } #CURE
elsif ($bit =~ s/ʊə/CUREPANIC/) { } #CURE PANIC
elsif ($bit =~ s/ʌɪ/ɑe/) { }
elsif ($bit =~ s/ɔɪ/oɪ/) { }
elsif ($bit =~ s/aʊ/æɔ/) { }
elsif ($bit =~ s/əʊ/oʊ/) { }
elsif ($bit =~ s/ɛː/eə/) { }
elsif ($bit =~ s/əː/ɜː/) { }
elsif ($bit =~ s/ɑː/ʌː/) { }
#elsif ($bit =~ s/ᵻ/ə/) { }
elsif ($bit =~ s/ɛ/e/) { }
elsif ($bit =~ s/a/æ/) { }
elsif ($bit =~ s/ɒ/ɔ/) { }
elsif ($bit =~ s/ᵿ/ə/) { } 



#BECAUSE
if (($bit =~ /[ɪᵻ]/) && ($bit !~ /[ˌˈ]/)) {

$search1 = $bit;
$search2 = $bit;
$search1 =~ s/[ɪᵻ]/ə/;
$search2 =~ s/[ɪᵻ]/i/;

#lets try to refine this. once it's matched on one it can't match on the same one, e.g. elsewhere in the same ph

#if ((grep(/\Q$search1\E/,@uses)) && (grep(/\Q$search2\E/,@uses)) && $numuses) { $bit =~ s/[ɪᵻ]/X/; }
# ah yeah so this works by removing it once it's matched the first

@usescheck = @uses;

if ((grep(s/^.*?\Q$search1\E.*?$//,@usescheck)) && (grep(/\Q$search2\E/,@usescheck)) && ($nextsyl =~ /ˈ/)) { $bit =~ s/[ɪᵻ]/X/; }
# perhaps also limit to where next syl contains primary stress, secondary stress?

}





if ($bit =~ s/ᵻ/ə/) { }



$newphon .= $bit;

# piano - full i:
#because - need b@ bi like AmE #COPIES THE AMERICAN
#tap - grab from AmE - give both, untapped first
#rabbit - compare kits and schwas between BrE and AmE

}



#-ity fix
$newphon =~ s/(\.[^\.ˌˈ $phoneticvowels2]*?)ɪ(\.ti(?!ː))/$1ə$2/g;

#-ed -id fix
$newphon =~ s/(\.[^\.ˌˈ $phoneticvowels2]*?)ɪd$/$1əd/g;
$newphon =~ s/(\.[^\.ˌˈ $phoneticvowels2]*?)ɪd /$1əd /g;

#-et -it fix
$newphon =~ s/(\.[^\.ˌˈ $phoneticvowels2]*?)ɪt$/$1ət/g;
$newphon =~ s/(\.[^\.ˌˈ $phoneticvowels2]*?)ɪt /$1ət /g;

#-est -ist fix
$newphon =~ s/(\.[^\.ˌˈ $phoneticvowels2]*?)ɪst$/$1əst/g;
$newphon =~ s/(\.[^\.ˌˈ $phoneticvowels2]*?)ɪst /$1əst /g;

#q(?!u)

#print "newphon --> $newphon\n";

$newphon =~ s/\.//g;

@tappatterns = ();
undef $safetappattern;


if (grep(/ɾ/,@uses)) {

foreach $usphon(@uses) {

$usphon =~ s/[^tɾ]//g;

push(@tappatterns,$usphon);

}

@tappatterns = uniq(@tappatterns);
$numtappaterns = @tappatterns; if ($numtappaterns > 1) { @tappatterns = (); } else { $safetappattern = join('',@tappatterns); }

}

#check ts in the current state of BrE conversion

$currentts = $newphon;
$currentts =~ s/[^t]//g;

$safetappatterntest = $safetappattern; $safetappatterntest =~ s/ɾ/Y/g; # need to get away from a multipart character
#print length($currentts)." and ".length($safetappatterntest)."\n";
if ((length($currentts) == length($safetappatterntest)) && ($safetappattern)) { #print "DOING IT\n";

# we have the same number of ts in BrE (converted) and AmE, and the AmE looks safe as there weren't other patterns e.g. in variants
# so we can move through the BrE changing for taps

@treplacements = split('',$safetappatterntest); @treplacements = reverse @treplacements;
@charsofnewphon = split('',$newphon);
undef $newnewphon;
foreach $charofnewphon(@charsofnewphon) {

if ($charofnewphon =~ /t/) { $charofnewphon = pop(@treplacements); }

$newnewphon .= $charofnewphon;

}

$newphon = $newnewphon;

}

if ($newphon =~ /X/) {

$out1 = $newphon;
$out2 = $newphon;
$out1 =~ s/X/ə/g;
$out2 =~ s/X/i/g;

#$newphon = "$out1|$out2"; # DON'T DO THIS FOR NOW BASED ON VIV'S SPEECH?
#$newphon = "$out1";
$newphon = "$out1#$out2"; # prep for thing that builds chunks

}

if ($newphon =~ /Y/) {

$out1 = $newphon;
$out2 = $newphon;
$out1 =~ s/Y/t/g;
$out2 =~ s/Y/ɾ/g;

#$newphon = "$out1|$out2";
#$newphon = "$out2"; # TRY JUST TAPPING FOR NOW
$newphon = "$out1#$out2"; # prep for thing that builds chunks

}



#bath trap

if ($newphon =~ /T/) {

$out1 = $newphon;
$out2 = $newphon;
$out1 =~ s/T/ʌː/g;
$out2 =~ s/T/æ/g;

$newphon = "$out1#$out2"; # prep for thing that builds chunks

}


@phonstooutput = split('\|',$newphon);

foreach $phontooutput(@phonstooutput) {
if (($needastress eq "yes") && ($phontooutput !~ /ˈ/)) { $phontooutput = "ˈ".$phontooutput; }


$key = "$orth$phontooutput";

unless ($SEENCOMBINATION{$key}) { print "$orth\t$phontooutput\n"; }

$SEENCOMBINATION{$key} = "yes";

#print "$orth\t$phontooutput\n";
}

}

}

foreach $needed (sort keys %NEED) {

$norm = $NEED{$needed};
$norm =~ tr/[A-Z]/[a-z]/;
$norm =~ s/[^a-z0-9]//g;
undef $decl;
if ($BYNORMFORM{$norm}) { $decl = "*"; }

warn "$decl$NEED{$needed} (norm form $norm)\n";

}

sub uniq { my %seen; grep !$seen{$_}++, @_ }
