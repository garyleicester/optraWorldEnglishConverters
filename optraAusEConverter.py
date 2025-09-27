#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import io
import re
import sys
from collections import OrderedDict

def uniq(seq):
    seen = set()
    out = []
    for x in seq:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out

def devaryant_pass(prongroup: str) -> str:
    # Strip audio + explicit_exclusion
    prongroup = re.sub(r"<audio[^>]+?/>", "", prongroup)
    prongroup = re.sub(r"<audio[^>]+?></audio>", "", prongroup)
    prongroup = re.sub(r"<explicit_exclusion.*?/explicit_exclusion>", "", prongroup)

    # Series of while-substitutions (mirror Perl)
    defs = [
        # keep ɒ when paired with ɔː
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ɔː([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2ɒ\3(</transcription></pronunciation>)",
         r"\1\2ɒ\3\4"),
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ɒ([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2ɔː\3(</transcription></pronunciation>)",
         r"\1\2ɒ\3\4"),
        # keep ʒ when paired with ʃ
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ʃ([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2ʒ\3(</transcription></pronunciation>)",
         r"\1\2ʒ\3\4"),
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ʒ([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2ʃ\3(</transcription></pronunciation>)",
         r"\1\2ʒ\3\4"),
        # keep eɪ when paired with i
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)i([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2eɪ\3(</transcription></pronunciation>)",
         r"\1\2eɪ\3\4"),
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)eɪ([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2i\3(</transcription></pronunciation>)",
         r"\1\2eɪ\3\4"),
        # trɑːn vs tran → keep tran
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)trɑːn([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2tran\3(</transcription></pronunciation>)",
         r"\1\2tran\3\4"),
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)tran([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2trɑːn\3(</transcription></pronunciation>)",
         r"\1\2tran\3\4"),
        # trap-bath marker T when both ɑː and a exist
        (r"(<pronunciation[^>]+?><transcription[^>]+?>)([^<]*?)ɑː([^<]*?)(</transcription></pronunciation>.*?)(<pronunciation[^>]+?><transcription[^>]+?>)\2a\3(</transcription></pronunciation>)",
         r"\1\2T\3\4"),
    ]
    for patt, repl in defs:
        rx = re.compile(patt)
        while True:
            new = rx.sub(repl, prongroup)
            if new == prongroup:
                break
            prongroup = new
    return prongroup

def extract_pos_labels(group_html: str) -> str:
    """Return 'adjective#noun' style labels from <pos_evidenced>…</pos_evidenced>, or ''."""
    m = re.search(r"<pos_evidenced[^>]*?>(.*?)</pos_evidenced>", group_html, re.DOTALL)
    if not m:
        return ""
    inner = m.group(1)
    tags = re.findall(r"<\s*([A-Za-z]+)\b", inner)
    tags = [t.lower() for t in tags]
    return "#".join(uniq(tags))

def iter_optra_entries(path):
    """Yield one minified <entry>…</entry> string at a time, even if input isn't minified."""
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
    parser = argparse.ArgumentParser(description="Generate AusE prons from OPTRA XML + wordlist (Perl-port).")
    parser.add_argument("--optra", required=True, help="OPTRA XML (minified or not; one or many lines).")
    parser.add_argument("--wordlist", required=True, help="Wordlist (one headword per line).")
    args = parser.parse_args()

    # Load NEED (words to generate for)
    NEED = OrderedDict()
    with io.open(args.wordlist, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n\r")
            line = line.replace("\r", "").replace("\n", "")
            if line == "Headword" or not line:
                continue
            NEED[line] = line

    BYNORMFORM = {}

    phoneticvowels2 = "ɐiɪeæɑɒɛɔᵿʊᵻuʌɜəoaT"

    # Precompiled regexes
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

    # new: global line-level dedup
    printed_lines = set()

    for line in iter_optra_entries(args.optra):
        morth = re_orth.search(line)
        if not morth:
            continue
        orth = morth.group(1)
        norm = re.sub(r"[^a-z0-9]", "", orth.lower())
        hasbre = bool(re_hasbre.search(line))

        if orth not in NEED:
            if hasbre:
                BYNORMFORM[norm] = orth
            continue

        # targeted de-variant on BrE groups
        for prongroup in (re_grp_brit.findall(line) + re_grp_brit2.findall(line)):
            before = prongroup
            after = devaryant_pass(prongroup)
            if before != after:
                line = line.replace(before, after, 1)

        # Gather groups separately (to keep PoS-distinct lines)
        brit_groups = re_grp_brit.findall(line) + re_grp_brit2.findall(line)
        uschunk = "".join(re_grp_us.findall(line) + re_grp_us2.findall(line))
        uses = re_uses_all.findall(uschunk)

        if not brit_groups:
            continue

        # we’re going to output something for this word; remove from NEED
        NEED.pop(orth, None)

        # Process EACH BrE group independently, emit one line per group
        for group in brit_groups:
            m = re_brit_first_of_group.search(group)
            if not m:
                continue
            phon = m.group(1)
            pos_labels = extract_pos_labels(group)  # e.g., "adjective#noun" or ""

            # Split before delimiters . space primary/secondary stress
            syllabs = re.split(r"(?=[\. ˈˌ])", phon)

            newphon = ""
            needastress = False

            for idx, bit in enumerate(syllabs):
                # Normalizations
                bit = re.sub(r"ə\(ʊ\)", "əʊ", bit)
                bit = re.sub(r"s\(j\)uː", "suː", bit)
                bit = re.sub(r"u$", "uː", bit)

                nextsyl = syllabs[idx + 1] if idx + 1 < len(syllabs) else ""

                # Insert (ə) before syllabic l/m/n if no vowel (incl. schwa) and not already syllabic
                if not re.search(r"[{}]".format(re.escape(phoneticvowels2)), bit) and re.search(r"[lmn]", bit) and "̩" not in bit:
                    bit = re.sub(r"^(.*?)([lmn])([^lmn]*?)$", r"\1(ə)\2\3", bit)

                # elsif ladder start
                if re.search(r"eɪ", bit):
                    bit = re.sub(r"eɪ", "æe", bit)
                    newphon += bit
                    continue
                if "ʊə" in bit and not re.match(r"^[ˈˌ \.\(]*?r", nextsyl or ""):
                    bit = bit.replace("ʊə", "uːə")
                    needastress = True
                    newphon += bit
                    continue
                if "ʊə" in bit and re.match(r"^[ˈˌ \.\(]*?r", nextsyl or ""):
                    bit = bit.replace("ʊə", "uː")
                    newphon += bit
                    continue
                if "ʊə" in bit:
                    bit = bit.replace("ʊə", "CUREPANIC")
                    newphon += bit
                    continue

                # Remaining simple swaps (mirror Perl elsif chain)
                for patt, repl in [
                    (r"ʌɪ", "ɑe"),
                    (r"ɔɪ", "oɪ"),
                    (r"aʊ", "æɔ"),
                    (r"əʊ", "oʊ"),
                    (r"ɛː", "eə"),
                    (r"əː", "ɜː"),
                    (r"ɑː", "ʌː"),
                    (r"ɛ", "e"),
                    (r"a", "æ"),
                    (r"ɒ", "ɔ"),
                    (r"ᵿ", "ə"),
                ]:
                    if re.search(patt, bit):
                        bit = re.sub(patt, repl, bit)
                        break

                # BECAUSE rule — only if US has two different variants (one ə, one i) and next syll has primary stress
                if re.search(r"[ɪᵻ]", bit) and not re.search(r"[ˌˈ]", bit):
                    search1 = re.sub(r"[ɪᵻ]", "ə", bit)
                    search2 = re.sub(r"[ɪᵻ]", "i", bit)
                    has_s1 = any(search1 in u for u in uses)
                    uses_wo_s1 = [u for u in uses if search1 not in u]
                    has_s2 = any(search2 in u for u in uses_wo_s1)
                    if has_s1 and has_s2 and re.search(r"ˈ", nextsyl or ""):
                        bit = re.sub(r"[ɪᵻ]", "X", bit)

                # After BECAUSE: convert remaining ᵻ -> ə
                bit = bit.replace("ᵻ", "ə")

                # We can remove any suggested/potential rhoticity for AusE
                bit = bit.replace("{r}", "")

                newphon += bit

            # Post-syllable fixes
            newphon = re.sub(r"(\.[^\.ˌˈ " + re.escape(phoneticvowels2) + r"]*?)ɪ(\.ti(?!ː))", r"\1ə\2", newphon)  # -ity
            newphon = re.sub(r"(\.[^\.ˌˈ " + re.escape(phoneticvowels2) + r"]*?)ɪd$", r"\1əd", newphon)            # -id
            newphon = re.sub(r"(\.[^\.ˌˈ " + re.escape(phoneticvowels2) + r"]*?)ɪd ", r"\1əd ", newphon)
            newphon = re.sub(r"(\.[^\.ˌˈ " + re.escape(phoneticvowels2) + r"]*?)ɪt$", r"\1ət", newphon)            # -it
            newphon = re.sub(r"(\.[^\.ˌˈ " + re.escape(phoneticvowels2) + r"]*?)ɪt ", r"\1ət ", newphon)
            newphon = re.sub(r"(\.[^\.ˌˈ " + re.escape(phoneticvowels2) + r"]*?)ɪst$", r"\1əst", newphon)          # -ist
            newphon = re.sub(r"(\.[^\.ˌˈ " + re.escape(phoneticvowels2) + r"]*?)ɪst ", r"\1əst ", newphon)

            # Tapping: map t/ɾ pattern from US if single consistent pattern
            if any("ɾ" in u for u in uses):
                pattset = [re.sub(r"[^tɾ]", "", u) for u in uses]
                pattset = uniq(pattset)
                safetappattern = pattset[0] if len(pattset) == 1 else ""
            else:
                safetappattern = ""
            currentts = re.sub(r"[^t]", "", newphon)
            safetest = safetappattern.replace("ɾ", "Y") if safetappattern else ""
            if safetest and len(currentts) == len(safetest):
                treplacements = list(reversed(list(safetest)))
                chars = []
                for ch in newphon:
                    if ch == "t":
                        ch = treplacements.pop()
                    chars.append(ch)
                newphon = "".join(chars)

            # Marker expansion with Perl-like string order (X → Y → T)
            variant_str = newphon
            if "X" in variant_str:
                variant_str = variant_str.replace("X", "ə") + "#" + variant_str.replace("X", "i")
            if "Y" in variant_str:
                variant_str = variant_str.replace("Y", "t") + "#" + variant_str.replace("Y", "ɾ")
            if "T" in variant_str:
                variant_str = variant_str.replace("T", "ʌː") + "#" + variant_str.replace("T", "æ")

            # Split by '#' then by '|', add stress if needed, dedup within this group
            candidates = []
            for chunk in variant_str.split("#"):
                for p in chunk.split("|"):
                    if not p:
                        continue
                    if needastress and "ˈ" not in p:
                        p = "ˈ" + p
                    candidates.append(p)
            final_prons = uniq(candidates)

            if final_prons:
                if pos_labels:
                    line_str = f"{orth}\t{'#'.join(final_prons)}\t{pos_labels}\n"
                else:
                    line_str = f"{orth}\t{'#'.join(final_prons)}\n"

                # <<< NEW: suppress exact duplicate lines >>>
                if line_str not in printed_lines:
                    sys.stdout.write(line_str)
                    printed_lines.add(line_str)

    # After processing all lines, report remaining needed words (stderr), with '*' if decl by norm
    for needed in sorted(NEED.keys()):
        norm = re.sub(r"[^a-z0-9]", "", needed.lower())
        decl = "*" if norm in BYNORMFORM else ""
        sys.stderr.write(f"{decl}{NEED[needed]} (norm form {norm})\n")

if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
    main()
