#!/usr/bin/env python3
"""Stage the reviewed HF snapshots anonymously; verify every downloaded file.

Uses only Python's standard library. Does not modify installed software.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.request

SELECTIONS = [
    ("asr", "parakeet-tdt-0.6b-v3-coreml",
     "7dd20fe6b1797d35f5e3307e8b1732d9a178edfe",
     ["Preprocessor.mlmodelc/", "Encoder_v2.mlmodelc/", "Decoder.mlmodelc/",
      "JointDecisionv3.mlmodelc/", "parakeet_vocab.json"]),
    ("diarizer", "speaker-diarization-coreml",
     "df2625ac79a7ac6b65ad868fee6d80f320da4232",
     ["Segmentation.mlmodelc/", "Embedding.mlmodelc/", "FBank.mlmodelc/",
      "PldaRho.mlmodelc/", "plda-parameters.json"]),
]


def digest(path, algorithm, git_blob=False):
    h = hashlib.new(algorithm)
    if git_blob:
        h.update(("blob %d\0" % path.stat().st_size).encode())
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model_root", type=Path)
    args = parser.parse_args()
    os.umask(0o077)
    manifest = []
    for folder, repo, revision, prefixes in SELECTIONS:
        api = f"https://huggingface.co/api/models/FluidInference/{repo}/revision/{revision}?blobs=true"
        with urllib.request.urlopen(api, timeout=60) as response:
            metadata = json.load(response)
        assert metadata["sha"] == revision
        files = [f for f in metadata["siblings"]
                 if any(f["rfilename"].startswith(p) for p in prefixes)]
        assert all(any(f["rfilename"].startswith(p) for f in files) for p in prefixes)
        # Preserve source and attribution documents alongside the models.
        files += [f for f in metadata["siblings"] if f["rfilename"] in
                  {"README.md", "NOTICE.md", "LICENSE", "LICENSE.md", "PROVENANCE.md", "provenance.json"}]
        for item in files:
            name = item["rfilename"]
            assert not Path(name).is_absolute() and ".." not in Path(name).parts
            path = args.model_root / folder / name
            path.parent.mkdir(parents=True, exist_ok=True)
            lfs = item.get("lfs")
            expected = lfs["sha256"] if lfs else item["blobId"]
            algorithm = "sha256" if lfs else "sha1"

            def valid(candidate):
                return (candidate.exists() and candidate.stat().st_size == item["size"]
                        and digest(candidate, algorithm, git_blob=not lfs) == expected)

            if path.exists() and not valid(path):
                raise RuntimeError(f"Existing file differs: {path}; refusing to overwrite")
            if not path.exists():
                temporary = path.with_name(path.name + ".owl-download")
                # A prior interrupted download may be replaced; final files never are.
                url = f"https://huggingface.co/FluidInference/{repo}/resolve/{revision}/{name}"
                with urllib.request.urlopen(url, timeout=120) as response, temporary.open("wb") as target:
                    for block in iter(lambda: response.read(1024 * 1024), b""):
                        target.write(block)
                if not valid(temporary):
                    raise RuntimeError(f"Integrity check failed: {name}")
                temporary.rename(path)
            manifest.append({"repository": "FluidInference/" + repo, "revision": revision,
                             "file": folder + "/" + name, "bytes": item["size"],
                             "sha256": digest(path, "sha256")})
            print(f"Verified {folder}/{name} ({item['size']} bytes)", flush=True)
    destination = args.model_root / "owl-model-manifest.json"
    content = json.dumps(manifest, indent=2) + "\n"
    if destination.exists():
        if destination.read_text() != content:
            raise RuntimeError("Existing manifest differs; refusing to overwrite")
    else:
        destination.write_text(content)
    print(f"Verified {len(manifest)} files; total {sum(f['bytes'] for f in manifest)} bytes", flush=True)


if __name__ == "__main__":
    main()
