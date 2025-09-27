#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import io
import re
import sys
from collections import OrderedDict, defaultdict

def uniq(seq):
    seen = set()
    out = []
    for x in seq:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out

def devaryant_pass_identity(x: str) -> str:
    # For IndE we don’t need the AusE de-variant dance; still strip noisy bits for safety
    x = re.sub(r"<audio[^>]+?/>", "", x)
    x = re.sub(r"<audio[^>]+?></audio>", "", x)
    x = re.sub(r"<explicit_exclusion.*?/explicit_exclusion>", "", x)
    return x

def extract_pos_labels(group_html: str) -> str:
    m = re.search(r"<pos_evidenced[^>]*?>(.*?)</pos_evidenced>", group_html, re.DOTALL)
    if not m:
        return ""
    inner = m.group(1)
    tags = re.findall(r"<\s*([A-Za-z]+)\b", inner)
    tags = [t.lower() for t in tags]
    return "#".join(uniq(tags))

def iter_optra_entries(path):
    """Yield one minified <entry>…</entry> at a time, even if input isn't minified."""
    buf = ""
    with io.open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n\r")
            line = line.replace("\t", "")
            line = re.sub(r" {2,}", " ", line)
            line = line.replace("> <", "><")
            buf += line
            while True:
                start = buf.find("<entry")
                end = buf.find("</entry>")
                if start == -1 or end == -1:
                    break
                end += len("</entry>")
                entry = buf[start:end]
                buf = buf[end:]
                yield entry
    # flush any remaining complete entry
    while True:
        start = buf.find("<entry")
        end = buf.find("</entry>")
        if start == -1 or end == -1:
            break
        end += len("</entry>")
        entry = buf[start:end]
        buf = buf[end:]
        yield entry

def main():
    parser = argparse.ArgumentParser(description="Generate IndE prons from OPTRA XML + wordlist (Perl-port).")
    parser.add_argument("--optra", required=True, help="OPTRA XML (minified or not; one or many lines).")
    parser.add_argument("--wordlist", required=True, help="Wordlist (one headword per line).")
    args = parser.parse_args()

    # Load wanted words and their normalized forms
    wanted_list = []
    normforms = []
    bynorm = defaultdict(list)

    with io.open(args.wordlist, "r", encoding="utf-8") as f:
        for line in f:
            w = line.rstrip("\n\r").replace("\r", "").replace("\n", "")
            if not w or w == "Headword":
                continue
            wanted_list.append(w)
            norm = re.sub(r"[^a-z0-9]", "", w.lower())
            normforms.append(norm)
            bynorm[norm].append(w)

    wanted_set = set(wanted_list)
    norm_set = set(normforms)

    # Precompiled regexes and classes
    re_orth = re.compile(r"<orthography[^>]*?>([^<]+?)</orthography>")
    re_hasbre = re.compile(
        r'<pronunciation_group[^>]+?model_and_variety="o[^_]+?_brit[^>]+?><pronunciation[^>]+?><transcription[^>]+?>[^<]',
        re.I,
    )
    re_grp_brit = re.compile(r'(<pronunciation_group[^>]+?model_and_variety="OPTRA_brit".*?/pronunciation_group>)')
    re_grp_brit2 = re.compile(r'(<pronunciation_group[^>]+?model_and_variety="ODO_BRITISH".*?/pronunciation_group>)')
    re_grp_us = re.compile(r'(<pronunciation_group[^>]+?model_and_variety="OPTRA_us".*?/pronunciation_group>)')
    re_grp_us2 = re.compile(r'(<pronunciation_group[^>]+?model_and_variety="ODO_US".*?/pronunciation_group>)')
    re_brit_first_of_group = re.compile(
        r"<pronunciation_group[^>]+?><pronunciation[^>]+?><transcription[^>]*?>([^<]+?)</transcription>"
    )
    re_uses_all = re.compile(r"<transcription[^>]*?>([^<]+?)</transcription>")

    phoneticvowels2 = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəoa"

    printed_lines = set()
    # Track found items for leftovers
    found_wanted = set()

    for entry in iter_optra_entries(args.optra):
        morth = re_orth.search(entry)
        if not morth:
            continue
        orth = morth.group(1)
        norm = re.sub(r"[^a-z0-9]", "", orth.lower())
        hasbre = bool(re_hasbre.search(entry))
        # selection filter (orth OR norm match), otherwise skip unless no wanted filter was given
        if wanted_set:
            if orth not in wanted_set and norm not in norm_set:
                continue

        # strip noise in groups
        entry_clean = entry
        for g in (re_grp_brit.findall(entry) + re_grp_brit2.findall(entry)):
            entry_clean = entry_clean.replace(g, devaryant_pass_identity(g), 1)

        brit_groups = re_grp_brit.findall(entry_clean) + re_grp_brit2.findall(entry_clean)
        if not brit_groups:
            continue

        uschunk = "".join(re_grp_us.findall(entry_clean) + re_grp_us2.findall(entry_clean))
        uses = re_uses_all.findall(uschunk)

        # Mark this (and same-norm words) as found for leftover reporting
        if orth in wanted_set:
            found_wanted.add(orth)
        if norm in bynorm:
            for w in bynorm[norm]:
                found_wanted.add(w)

        # Process each BrE group independently
        for group in brit_groups:
            m = re_brit_first_of_group.search(group)
            if not m:
                continue
            phon = m.group(1)
            pos_labels = extract_pos_labels(group)

            # Split before delimiters . space primary/secondary stress
            syllabs = re.split(r"(?=[\. ˈˌ])", phon)
            newphon = ""

            for idx, bit in enumerate(syllabs):
                nextsyl = syllabs[idx + 1] if idx + 1 < len(syllabs) else ""

                # --- pre-chain normalizations (mirror Perl) ---
                bit = re.sub(r"t(?!ʃ)", "ʈ", bit)
                bit = re.sub(r"d(?!ʒ)", "ɖ", bit)
                bit = bit.replace("v", "ʋ")
                # u at end of syllable -> uː
                bit = re.sub(r"u$", "uː", bit)
                bit = bit.replace("w", "ʋ")
                bit = bit.replace("n̩", "ən").replace("m̩", "əm").replace("l̩", "əl")
                bit = bit.replace("(d)ʒ", "dʒ")
                bit = re.sub(r"(?<!d)ʒ", "dʒ", bit)
                bit = bit.replace("ə(ʊ)", "əʊ")

                # ŋ -> ŋɡ before vowel-starting next syllable
                if bit.endswith("ŋ") and re.match(r"^[ˈˌ \.]*?[{}]".format(re.escape(phoneticvowels2)), nextsyl or ""):
                    bit = bit[:-1] + "ŋɡ"

                # Insert schwa before l/m/n if no vowel in this chunk
                if not re.search(r"[{}]".format(re.escape(phoneticvowels2)), bit) and re.search(r"[lmn]", bit):
                    bit = re.sub(r"^(.*?)([lmn])([^lmn]*?)$", r"\1ə\2\3", bit)

                # --- elsif ladder (preserve order/short-circuit semantics) ---
                ladder_done = False
                def hit():
                    nonlocal ladder_done
                    ladder_done = True

                if re.search(r"ʌɪ", bit):
                    bit = re.sub(r"ʌɪ", "aɪ", bit); hit()
                elif "iː" in bit:
                    # no-op, but short-circuits
                    bit = bit; hit()
                elif "uː" in bit:
                    bit = bit; hit()
                elif "iː" in bit:
                    bit = bit; hit()
                elif "uː" in bit:
                    bit = bit; hit()
                elif "ɑː" in bit and "{r}" not in bit:
                    bit = bit.replace("ɑː", "ɑː"); hit()
                elif "ɑː" in bit and "{r}" in bit:
                    bit = bit.replace("ɑː", "ɑː(r)"); hit()
                elif "əː" in bit:
                    bit = bit.replace("əː", "ɜː"); hit()
                elif "ɪə" in bit and "{r}" in bit:
                    bit = bit.replace("ɪə", "ɪə(r)"); hit()
                elif "ɛː" in bit:
                    bit = bit.replace("ɛː", "ɛː(r)"); hit()
                elif "jʊə" in bit:
                    bit = bit.replace("jʊə", "ɪjoː(r)"); hit()
                elif "ʊə" in bit:
                    bit = bit.replace("ʊə", "oː(r)"); hit()
                elif "eɪ" in bit:
                    bit = bit.replace("eɪ", "eː"); hit()
                elif "ɔɪ" in bit:
                    bit = bit; hit()
                elif "aʊ" in bit and not re.match(r"^[ˈˌ \.\(]*?[{}]".format(re.escape(phoneticvowels2)), nextsyl or ""):
                    bit = bit; hit()
                elif "aʊ" in bit and re.match(r"^[ˈˌ \.\(]*?[{}]".format(re.escape(phoneticvowels2)), nextsyl or ""):
                    bit = bit.replace("aʊ", "aːʋ"); hit()
                elif "əʊ" in bit:
                    bit = bit.replace("əʊ", "oː"); hit()
                elif "ɪ" in bit:
                    bit = bit; hit()
                elif "ɛ" in bit:
                    bit = bit.replace("ɛ", "e"); hit()
                elif "a" in bit:
                    bit = bit.replace("a", "æ"); hit()
                elif "(ə)" in bit:
                    bit = bit.replace("(ə)", "ə"); hit()
                elif "ɒ" in bit:
                    bit = bit.replace("ɒ", "ɔː")
                    # LOT/CLOTH via US check
                    searchbit = bit.replace("ɔ", "ɑ")
                    if any(searchbit in u for u in uses) and any(bit in u for u in uses):
                        bit = re.sub(r"ɔ(?!ː)", "ɔː", bit)
                    hit()
                elif re.search(r"i(?!ː)", bit):
                    bit = re.sub(r"i(?!ː)", "ɪ", bit); hit()
                elif re.search(r"i(?!ː)", bit):
                    bit = re.sub(r"i(?!ː)", "ɪ", bit); hit()
                elif "ʌ" in bit:
                    bit = bit; hit()
                elif "ʊ" in bit:
                    bit = bit; hit()
                elif "ɔː" in bit and "{r}" in bit:
                    bit = bit.replace("ɔː", "ɔː(r)"); hit()
                elif "ɔː" in bit:
                    bit = bit; hit()
                elif "ə" in bit and "{r}" in bit:
                    bit = bit.replace("ə", "ə(r)"); hit()
                elif "ə" in bit:
                    bit = bit; hit()
                elif "ɪ" in bit:
                    bit = bit; hit()
                elif "ᵻ" in bit:
                    bit = bit; hit()
                elif "ᵿ" in bit:
                    bit = bit.replace("ᵿ", "ʊ"); hit()

                # {r} normalization inside the syllable
                bit = re.sub(r"\(r\)\{r\}", "(r)", bit)
                bit = bit.replace("{r}", "(r)")

                # “BECAUSE” (IndE): if US has both ə- and i- variants (after de-retroflexing),
                # choose KIT (ɪ) here; no stress-lookahead condition.
                if re.search(r"[ɪᵻ]", bit) and not re.search(r"[ˌˈ]", bit):
                    s1 = re.sub(r"[ɪᵻ]", "ə", bit)
                    s1 = s1.replace("ɖ", "d").replace("ʈ", "t")
                    s2 = re.sub(r"[ɪᵻ]", "i", bit)
                    s2 = s2.replace("ɖ", "d").replace("ʈ", "t")
                    if any(s1 in u for u in uses) and any(s2 in u for u in uses):
                        bit = re.sub(r"[ɪᵻ]", "ɪ", bit)

                newphon += bit

            # --- post-syllable cleanup (mirror Perl) ---
            newphon = newphon.replace("(ʊ)l", "ʊl")
            newphon = re.sub(r"\([ᵻɪ]\)l", "ɪl", newphon)
            newphon = re.sub(r"\([ᵻɪ]\)n", "ɪn", newphon)
            newphon = newphon.replace("(ə)", "ə")
            newphon = newphon.replace("(ə(r))", "ə(r)")
            newphon = re.sub(r"ŋ$", "ŋɡ", newphon)
            newphon = newphon.replace("(r)r", "r")
            newphon = re.sub(r"\(r\)([ˌˈ]+?)r", r"\1r", newphon)
            newphon = re.sub(r"ə ", "a ", newphon)
            newphon = re.sub(r"ə$", "a", newphon)

            # Output (with PoS as 3rd cell if present), dedup whole line
            if newphon:
                if pos_labels:
                    line_str = f"{orth}\t{newphon}\t{pos_labels}\n"
                else:
                    line_str = f"{orth}\t{newphon}\n"
                if line_str not in printed_lines:
                    sys.stdout.write(line_str)
                    printed_lines.add(line_str)

    # Leftovers (like Perl's final warn loop)
    remaining = [w for w in wanted_list if w not in found_wanted]
    for w in remaining:
        sys.stderr.write(f"{w}\n")

if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
    main()
