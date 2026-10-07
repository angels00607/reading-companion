"""Independent reader of the actual Swift-produced portable ZIP, not a SQLite dump."""
import hashlib
import json
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None, "ZIP CRC mismatch"
    manifest = json.loads(archive.read("manifest.json"))
    assert manifest["backupFormatVersion"] == 1
    assert manifest["schemaVersion"] == 1
    assert manifest["checksumAlgorithm"] == "SHA-256"
    assert manifest["sourceDevice"] == "iOS"
    assert manifest["createdAt"].endswith("Z")
    assert set(archive.namelist()) == {"manifest.json", *[item["path"] for item in manifest["files"]]}
    for item in manifest["files"]:
        data = archive.read(item["path"])
        assert len(data) == item["byteCount"]
        assert hashlib.sha256(data).hexdigest() == item["sha256"]
    payload = json.loads(archive.read("data.json"))
    assert payload["schemaVersion"] == manifest["schemaVersion"]
    assert {name: len(rows) for name, rows in payload["entities"].items()} == manifest["entityCounts"]
    assert payload["entities"]["books"][0]["pages"] is None
    assert payload["entities"]["readings"][0]["pagePosition"] is None
    assert payload["entities"]["readings"][0]["percentage"] == 70
print("PASS: Swift ZIP readable independently; CRC, SHA-256, inventory, counts and unknown/unit facts verified")
