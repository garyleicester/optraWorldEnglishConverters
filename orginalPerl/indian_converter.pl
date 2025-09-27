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

push(@wanted,$line);

$norm = $line;
$norm =~ tr/[A-Z]/[a-z]/;
$norm =~ s/[^a-z0-9]//g;
push(@normforms,$norm);
$BYNORM{$norm} .= "$line\t";

}

close(WORDLIST);

require "/data_new/PHONS_TOOLS/STR/better_orth_proc/orthographic_processor_subroutine.pl";

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
my $phoneticvowels2 = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəoa";
my $phoneticvowels2b = "ɐeæɑɒɛɔuʌɜoa";
my $phoneticvowels2noschwa = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜoa";
my $phoneticvowels3 = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəa";
my $phoneticvowels4 = "æaɒɛʌ";
my $phoneticvowels5 = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəoa~ː";
my $removeforstressdetection = "ɐiɪeæɑɒɔʊuʌɛɜəoaːpbtdkɡtʃʒfvθðszhmnŋlrjwx";

#@wanted = ("kit", "dress", "trap", "bath", "lot", "cloth", "strut", "foot", "fleece", "goose", "palm", "start", "nurse", "north", "force", "thought", "near", "square", "cure", "sure", "face", "pride", "voice", "mouth", "goat", "happy", "letter", "rabbit", "added", "beautiful", "piano", "ago", "because");

#@wanted = ("across the board");

# we're going to need more context

while (<STDIN>) {

$line = $_;

chomp $line;
$line =~ s/\r//g;
$line =~ s/\n//g;

unless ($line =~ /<pronunciation_group[^>]+?model_and_variety="o[^_]+?_brit[^>]+?><pronunciation[^>]+?><transcription[^>]+?>[^<]/i) { next; } ## absolutely do nothing if no brit transcription

if ($line =~ /<orthography[^>]*?>([^<]+?)<\/orthography>/) { $orth = $1; } else { next; }

$norm = $orth;
$norm =~ tr/[A-Z]/[a-z]/;
$norm =~ s/[^a-z0-9]//g;

# supercrude north/force
#undef $north; undef $force;
#if (($orth =~ /or$/) || ($orth =~ /ar$/) || ($orth =~ /or[$phoneticconsonants2]/) || ($orth =~ /uar/) || ($orth =~ /aur/)) { $north = "north"; }
#if (($orth =~ /ore/) || ($orth =~ /oar$/) || ($orth =~ /oor$/)  || ($orth =~ /our$/) || ($orth =~ /our[$phoneticconsonants2]/) || ($orth =~ /oar[$phoneticconsonants2]/) || ($orth =~ /our[$phoneticconsonants2]/)) { $force = "force"; }
#if (($north) && ($force)) { undef $force; }

if (@wanted) {

unless ((grep(/^\Q$orth\E$/,@wanted)) || (grep(/^\Q$norm\E$/,@normforms))) { next; }

}

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

grep(s/^\Q$orth\E$//,@wanted); # if we've reached this point we can check it off the list

@tocheckoff = split('\t',$BYNORM{$norm});
foreach $checkoff(@tocheckoff) {
grep(s/^\Q$checkoff\E$//,@wanted);
}

foreach $phon(@brits) {

@toorthographicprocessor = ("$orth", "$phon", "British");
orthographic_processor(@toorthographicprocessor);
@orthvowelclusters = ();
#print "-- $fromorthprocessor -- ";
if ($fromorthprocessor =~ /one solution \[/) { $fromorthprocessor =~ /^[^<]+?<[^>]+?>[^<]+?<([^<]+?)>/; $grab = $1; $grab =~ s/#//g; @orthvowelclusters = split(' ',$grab); } #one solution, use reliably
if ($fromorthprocessor =~ /using \[/) { $fromorthprocessor =~ /^[^<]+?<[^>]+?>[^<]+?<([^<]+?)>/; $grab = $1; $grab =~ s/#//g; @orthvowelclusters = split(' ',$grab); } #several solutions, how to resolve?
if ($fromorthprocessor =~ /failed \[/) { } #bad

#print "$fromorthprocessor\n";
#black hearted ------------------------------------------- you need to verify position of rhot against the AmE.
#print "$fromorthprocessor\t@orthvowelclusters\n";

undef $syllabcountrhotic;
foreach $checkem(@orthvowelclusters) {

$syllabcountrhotic++;

if ($checkem =~ /r/) { $rhoticsyllab .= "$syllabcountrhotic#"; }


}

$rhoticsyllab = "#".$rhoticsyllab."#";

@amerhotpatterns = ();

@usescheck = @uses;
grep(s/[\(\)]//g, @usescheck);
grep(s/ˈˌ/ˌ/g, @usescheck);
grep(s/ ([ˌˈ])/$1/g, @usescheck);
$phonforcount = $phon; $phonforcount =~ s/ ([ˌˈ])/$1/g;
$nosyllsinbre = split '(?=[\. ˈˌ])', $phonforcount;

foreach $us(@usescheck) {

@ussyllabbits = split '(?=[\. ˈˌ])', $us;

$noussyllabbits = @ussyllabbits;
if ($noussyllabbits ne $nosyllsinbre) { next; }

undef $uscount;
undef $pattern;

foreach $ussyllabbit(@ussyllabbits) {

unless (($ussyllabbit =~ /^ $/) || ($ussyllabbit =~ /^[\(\)ˈˌ]+?$/)) { $uscount++; } # CHECK THIS CHANGE

if ($ussyllabbit =~ /[$phoneticvowels2]r/) { $pattern .= "$uscount#"; }

}

$pattern = "#".$pattern."#";
push (@amerhotpatterns,$pattern);

}

grep(s/^##$//g, @amerhotpatterns);
@amerhotpatterns = grep { $_ ne '' } @amerhotpatterns;
@amerhotpatterns = uniq(@amerhotpatterns);

$noamerrhotpatterns = @amerhotpatterns;

if ($noamerrhotpatterns == 1) { $rhoticsyllab = pop(@amerhotpatterns); $rhoticsyllab = $rhoticsyllab."(from AmE)"; }

@syllabs = split '(?=[\. ˈˌ])', $phon;

undef $newphon;

undef $iamsyllable;
undef $truenextcounter;

#print "syllables broken up as ".join('#',@syllabs)."\n";

undef $primaryseen;

foreach $bit(@syllabs) { 

unless (($bit =~ /^ $/) || ($bit =~ /^[\(\)ˈˌ]+?$/)) { $iamsyllable++; }
#if ($bit =~ /[^ˈˌ \.]/) { $iamsyllable++; }
$truenextcounter++;
#$iamsyllable++;

$nextsyl = $syllabs[$truenextcounter];

$bit =~ s/t(?!ʃ)/ʈ/g;
$bit =~ s/d(?!ʒ)/ɖ/g;
$bit =~ s/d(?!ʒ)/ɖ/g;
$bit =~ s/v/ʋ/g;
$bit =~ s/u$/uː/g;
$bit =~ s/w/ʋ/g;
#$bit =~ s/ŋ/ŋɡ/g; # final or before a vowel
$bit =~ s/n̩/ən/g;
$bit =~ s/m̩/əm/g;
$bit =~ s/l̩/əl/g;
$bit =~ s/\(d\)ʒ/dʒ/;
$bit =~ s/(?<!d)ʒ/dʒ/;
$bit =~ s/ə\(ʊ\)/əʊ/;

# disable this after feedback
#if (($iamsyllable == 1) && ($orth =~ /^[$orthconsonants]*?a/) && ($bit !~ /[ˌˈ]/) && ($bit =~ /ə/)) { $bit =~ s/ə/æ/; } #ago

if (($bit =~ /ŋ$/) && ($nextsyl =~ /^[ˈˌ \.]*?[$phoneticvowels2]/)) { $bit =~ s/ŋ$/ŋɡ/; } 

if (($bit !~ /[$phoneticvowels2]/) && ($bit =~ /[lmn]/)) { $bit =~ s/^(.*?)([lmn])([^lmn]*?)$/$1ə$2$3/; }

if ($bit =~ s/ʌɪ/aɪ/) { }
elsif ($bit =~ s/iː/iː/) { }
elsif ($bit =~ s/uː/uː/) { }
elsif ($bit =~ s/iː/iː/) { }
elsif ($bit =~ s/uː/uː/) { }
elsif (($bit =~ /ɑː/) && ($rhoticsyllab !~ /#$iamsyllable#/)) { $bit =~ s/ɑː/ɑː/; }
elsif (($bit =~ /ɑː/) && ($rhoticsyllab =~ /#$iamsyllable#/)) { $bit =~ s/ɑː/ɑː(r)/; }
elsif ($bit =~ s/əː/ɜː/) { } # which no rhot?
elsif (($bit =~ /ɪə/) && ($rhoticsyllab =~ /#$iamsyllable#/)) { $bit =~ s/ɪə/ɪə(r)/; } # look to american?
elsif ($bit =~ s/ɛː/ɛː(r)/) { } #syllable final
elsif ($bit =~ s/jʊə/ɪjoː(r)/) { } 
elsif ($bit =~ s/ʊə/oː(r)/) { } #e.ɡ. sure
elsif ($bit =~ s/eɪ/eː/) { } 
elsif ($bit =~ s/ɔɪ/ɔɪ/) { } 
elsif (($bit =~ /aʊ/) && ($nextsyl !~ /^[ˈˌ \.\(]*?[$phoneticvowels2]/)) { $bit =~ s/aʊ/aʊ/; } 
elsif (($bit =~ /aʊ/) && ($nextsyl =~ /^[ˈˌ \.\(]*?[$phoneticvowels2]/)) { $bit =~ s/aʊ/aːʋ/; } 
elsif ($bit =~ s/əʊ/oː/) { } 
elsif ($bit =~ s/ɪ/ɪ/) { }
elsif ($bit =~ s/ɛ/e/) { }
elsif ($bit =~ s/a/æ/) { } # BrE /a/ becomes /{/

elsif ($bit =~ s/\(ə\)/ə/g) { }
#elsif ($bit =~ s/ɒ/ɔ/) { $searchbit = $bit; $searchbit =~ s/ɔ/ɑ/; if ((grep(/\Q$searchbit\E/,@uses)) && (grep(/\Q$bit\E/,@uses))) { $bit =~ s/ɔ/ɔː/; } } # LOT / CLOTH handled by looking at AmE
elsif ($bit =~ s/ɒ/ɔː/) { $searchbit = $bit; $searchbit =~ s/ɔ/ɑ/; if ((grep(/\Q$searchbit\E/,@uses)) && (grep(/\Q$bit\E/,@uses))) { $bit =~ s/ɔ/ɔː/; } } # LOT / CLOTH handled by looking at AmE
elsif ($bit =~ s/i(?!ː)/ɪ/) { } #if before vowel
elsif ($bit =~ s/i(?!ː)/ɪ/) { } #piano
#elsif ($bit =~ s/ɒ/ɔː/) { } #cloth! spelling
elsif ($bit =~ s/ʌ/ʌ/) { }
elsif ($bit =~ s/ʊ/ʊ/) { }

#elsif (($bit =~ /ɔː/) && ($rhoticsyllab =~ /#$iamsyllable#/) && ($north)) { $bit =~ s/ɔː/ɔː(r)/; } #north
#elsif (($bit =~ /ɔː/) && ($rhoticsyllab =~ /#$iamsyllable#/) && ($force)) { $bit =~ s/ɔː/oː(r)/; } #force
elsif (($bit =~ /ɔː/) && ($rhoticsyllab =~ /#$iamsyllable#/)) { $bit =~ s/ɔː/ɔː(r)/; } #north
elsif (($bit =~ /ɔː/) && ($rhoticsyllab !~ /#$iamsyllable#/)) { $bit =~ s/ɔː/ɔː/; } #thought

elsif (($bit =~ /ə/) && ($rhoticsyllab =~ /#$iamsyllable#/)) { $bit =~ s/ə/ə(r)/; } 
elsif (($bit =~ /ə/) && ($rhoticsyllab !~ /#$iamsyllable#/)) { $bit =~ s/ə/ə/; } 

elsif ($bit =~ s/ɪ/ɪ/) { } #rabbit
elsif ($bit =~ s/ᵻ/ᵻ/) { } #added
elsif ($bit =~ s/ᵿ/ʊ/) { } #added
#aɡo - restore vowel
#comma - once done aɡo, non rhotic schwa = a
#because - barred kit before stress (consonant?) = lengthened? include kit? - but then this = piano

#because - need b@ bi like AmE

if (($bit =~ /[ɪᵻ]/) && ($bit !~ /[ˌˈ]/)) {

$search1 = $bit;
$search2 = $bit;
$search1 =~ s/[ɪᵻ]/ə/;
$search1 =~ s/ɖ/d/g;
$search1 =~ s/ʈ/t/g;
$search2 =~ s/[ɪᵻ]/i/;
$search2 =~ s/ɖ/d/;
$search2 =~ s/ʈ/t/;
#if ((grep(/\Q$search1\E/,@uses)) && (grep(/\Q$search2\E/,@uses))) { $bit =~ s/[ɪᵻ]/iː/; } ## not after feedback
if ((grep(/\Q$search1\E/,@uses)) && (grep(/\Q$search2\E/,@uses))) { $bit =~ s/[ɪᵻ]/ɪ/; }

}

$newphon .= $bit;


 }

# growing unease after feedback
#if (($newphon =~ /[$phoneticconsonants2]ʈ$/) && ($orth =~ /ed$/)) { $newphon =~ s/ʈ$/ɖ/; }
#if (($newphon =~ /z$/) && ($orth =~ /s$/)) { $newphon =~ s/z$/s/; }


#$line =~ /^([^\t]+?)\t/; $word = $1; $word =~ s/[\(\)]//g;

#if (grep(/^$word$/,@wanted)) { print "$orth\t$phon\tCONVERTED-->\t$newphon\trhotic syls - $rhoticsyllab\tus context was @uses\n"; }

#if (($orth =~ /^[$orthconsonants]*?a/) && ($newphon =~ /([^ˌˈ \.]*?)ə([ˌˈ])/)) { $one = $1; $two = $2; $newphon =~ s/\Q$one\Eə\Q$two\E/$one\æ*$two/; }

$newphon =~ s/\.//g;
#$newphon =~ s/æ$/a/g;
# beautiful etc. - never syllabic, unbracket. no syllabic consonants, implied or otherwise
$newphon =~ s/\(ʊ\)l/ʊl/g;
$newphon =~ s/\([ᵻɪ]\)l/ɪl/g;
$newphon =~ s/\([ᵻɪ]\)n/ɪn/g;
$newphon =~ s/\(ə\)/ə/g;
$newphon =~ s/\(ə\(r\)\)/ə(r)/g;
$newphon =~ s/ŋ$/ŋɡ/;
$newphon =~ s/\(r\)r/r/g;
$newphon =~ s/\(r\)([ˌˈ]+?)r/$1r/g;
# multiple r! drop the one that's inserted

$newphon =~ s/ə /a /g;
$newphon =~ s/ə$/a/g;
#comma





# do the devoicing bits again for multiword that can be split reliably

if ($newphon =~ / /) {

@wordchunks = split '(?=[ ])', $orth;
@phonchunks = split '(?=[ ])', $newphon;

$numwordchunks = @wordchunks; $numphonchunks = @phonchunks;

if ($numphonchunks == $numwordchunks) {

undef $rebuiltphon;
undef $thiscount;

foreach $spacedchunk(@phonchunks) {

# growing unease after feedback
#if (($spacedchunk =~ /[$phoneticconsonants2]ʈ$/) && ($wordchunks[$thiscount] =~ /ed$/)) { $spacedchunk =~ s/ʈ$/ɖ/; }
#if (($spacedchunk =~ /z$/) && ($wordchunks[$thiscount] =~ /s$/)) { $spacedchunk =~ s/z$/s/; }

$rebuiltphon .= $spacedchunk;

}

$newphon = $rebuiltphon;

}

}




$key = "$orth$newphon";

unless ($SEENCOMBINATION{$key}) { print "$orth\t$newphon\n"; }

$SEENCOMBINATION{$key} = "yes";

#print "$orth\t$phon\t$newphon\t$rhoticsyllab\n";
}

}

@wanted = grep { $_ ne '' } @wanted;

foreach $leftover(@wanted) {
warn "$leftover\n";
}

sub uniq { my %seen; grep !$seen{$_}++, @_ }


#Z should always become dZ DONE
#
#-ed endings always voiced - mIsd fl{pd DONE
#-s dogs kisses = /s/	
#
#Ng thing is WORD FINAL DONE
#
#<gh> /g/ = /gh/ I CAN'T DO THIS
#<wh> /w/ = /ʋh/ I CAN'T DO THIS
#
#linking r is found intrustive never
#
#jesuit - u.I DONE
#
#schwas - keep schwas DONE
#
#word final schwa = /a/ DONE
#
#power - next syllable ignore ( DONE
#
#DONE LOT/CLOTH!
#LOT/CLOTH - o or au with fricative following and rhyme with thought in AmE are cloth
#o rhymes with thought in AmE but never in RP
#or rhymes with north in AmE
#---- if AmE is /O/ *AND* /A/ it's a cloth.
#
#
#so if my CI or barred CI is matched by C@ Ci - BECAUSE DONE
#
#ago to do DONE
#
#break multiwords into chunks to do comma check NOT NEEDED - even do ago check? AND the -ed and -s check? DONE