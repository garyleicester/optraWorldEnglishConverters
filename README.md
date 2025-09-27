Of limited value publicly, but maybe of passing interest to those interested in linguistics / phonetics / lexicography - two ('thinking outloud' Perl) scripts from my OPTRA days resurrected as Python, in theory so I can pass them back to the people who work with this now in a way they can at least run, maybe even add to/alter/improve.

Each script reads in a copy of OPTRA (a large proprietary XML dataset describing British, American and other varieties of English pronunciation), a 'to generate' wordlist, and - if a British English (BrE) and American English (AmE) information can be found for that word (or compound, whatever, see boring angry Xitter comments about how today's WOTD is a compound etc. etc.) - outputs suggested Australian English (AusE) or Indian English (IndE) pronunciations, according to the phonemic models defined here - https://www.oed.com/information/understanding-entries/pronunciation/world-englishes

In my time this was done to ensure some large-scale audio recording sessions for AusE and IndE were guided by and anchored in data - i.e. orthography is not a reliable guide to or suggestion of pronunciation, but a phonemic transcription is data representing pronunciation to some degree of accuracy, that the resulting audio file will either match tolerably or deviate from for either valid ('we don't actually say it like that, let's change the transcription') or invalid reasons ('oops, got that one wrong, let's redo it'). Between programatically generating AusE/IndE transcriptions according to expected changes (and represented in an phonetically appropriate phonemic system) and the process of recording an appropriate speaker working to that data, adjusting and correcting along the way, a decent dataset (new transcriptions, new audio files, new XML for OPTRA) is created.

`/testData` contains a (mock, single entry) `optra_sample.xml` containing a nonsense word and input word list (`list.txt`) matching that single entry.
`--optra {file}.xml` is ideally a full export of OPTRA from the database that holds it, in the form (as I remember) that database exports - one `<entry ... <\/entry>` per line (minified, not pretty printed), held in a batch structure, with full internal `e:id` attributes on tags. The new Python conversions are a touch more tolerant of unexpected input than the original scripts.
`list.txt` should contain each desired 'word' (wordform, headword, compound, phrasem, whatever ...) on a separate line.

`python3 optraAusEConverter.py --optra optra.xml --wordlist list.txt >australian_test_output.txt`
`python3 optraIndEConverter.py --optra optra.xml --wordlist list.txt >indian_test_output.txt`

output is tab separated - `input[TAB]pronunciations[TAB]part(s) of speech`

e.g.

`Sperlugulong	spə(r)ˈluː.ɡjuː.lɔːŋɡ	noun`

If multiple pronunciations are generated (e.g., pronunciations with both 'tapped' and 'non-tapped' intervocalic `<t>` for AusE) pronunciations are presented with a # separator

The output can/should then be further processed to generate and inject into OPTRA in new XML structures

**Note for easily queasy**: contains regex-based XML parsing, and however Python these scripts now are, they still reflect a Perl mindset / they're not truly Pythonic. They're rapid resurrections of some old Perl 'one-off workings, not replicable processes' scripts.  
**Note for queasy in general**: `originalPerl` contains the original Perl scripts.
