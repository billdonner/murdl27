# /// script
# dependencies = ["cryptography", "pyjwt", "requests"]
# ///
"""
Create MURDL's two Xcode Cloud workflows once the Cloud product exists.

The product itself must be created once in Xcode (Product > Xcode Cloud > Create
Workflow); the API cannot do that. Everything after is scripted here, following the
KinFlash playbook: a BUILD workflow on every push to main, and an ARCHIVE workflow on
pushes to the release branch that uploads to App Store Connect. Both pinned to Xcode 26.6
(Latest Release becomes 27 the day it ships and resurrects ITMS-90111).

    uv run scripts/xcode-cloud-workflows.py            # create or report
"""
import jwt, time, requests, sys
from pathlib import Path

ISSUER = "69a6de6f-2572-47e3-e053-5b8c7c11a4d1"
KID = "MN6H2P6385"
XCODE_26_6 = "42533094-17d3-46b2-ada5-1f94ceb94b61"
REPO_NAME = "murdl27"
SCHEME = "Murdl"
B = "https://api.appstoreconnect.apple.com/v1/"

key = (Path.home() / ".private_keys" / f"AuthKey_{KID}.p8").read_text()
tok = jwt.encode({"iss": ISSUER, "exp": int(time.time()) + 1200, "aud": "appstoreconnect-v1"}, key, algorithm="ES256", headers={"kid": KID})
h = {"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}


def get(path, **params):
    r = requests.get(B + path, params=params, headers=h, timeout=30)
    r.raise_for_status()
    return r.json()


products = [p for p in get("ciProducts", limit=50)["data"] if "murdl" in p["attributes"]["name"].lower()]
if not products:
    print("No Xcode Cloud product for MURDL yet. Create it once in Xcode, then rerun.")
    sys.exit(1)
product = products[0]
print("product", product["id"], product["attributes"]["name"])

repos = [r for r in get("scmRepositories", limit=50)["data"] if r["attributes"]["repositoryName"].lower() == REPO_NAME]
if not repos:
    print("Repository murdl27 is not connected to Xcode Cloud; the product wizard should have done that.")
    sys.exit(1)
repo = repos[0]
print("repository", repo["id"])

macos = next(v for v in get("ciMacOsVersions", limit=50)["data"] if "Latest" in v["attributes"]["name"] and "Release" in v["attributes"]["name"])
print("macOS", macos["id"], macos["attributes"]["name"])

existing = {w["attributes"]["name"]: w for w in get(f"ciProducts/{product['id']}/workflows", limit=50)["data"]}


def workflow(name, branch, archive):
    if name in existing:
        print(f"exists: {name} ({existing[name]['id']})")
        return
    actions = [{
        "name": "Archive - macOS" if archive else "Build - macOS",
        "actionType": "ARCHIVE" if archive else "BUILD",
        "destination": "ANY_MAC",
        "buildDistributionAudience": "APP_STORE_ELIGIBLE" if archive else None,
        "scheme": SCHEME,
        "platform": "MACOS",
        "isRequiredToPass": True,
    }]
    body = {"data": {"type": "ciWorkflows", "attributes": {
        "name": name,
        "description": "Created by scripts/xcode-cloud-workflows.py",
        "branchStartCondition": {"source": {"isAllMatch": False, "patterns": [{"pattern": branch, "isPrefix": False}]},
                                 "filesAndFoldersRule": None, "autoCancel": True},
        "isEnabled": True, "isLockedForEditing": False, "clean": False,
        "containerFilePath": "Murdl.xcodeproj",
        "actions": actions,
    }, "relationships": {
        "product": {"data": {"type": "ciProducts", "id": product["id"]}},
        "repository": {"data": {"type": "scmRepositories", "id": repo["id"]}},
        "xcodeVersion": {"data": {"type": "ciXcodeVersions", "id": XCODE_26_6}},
        "macOsVersion": {"data": {"type": "ciMacOsVersions", "id": macos["id"]}},
    }}}
    r = requests.post(B + "ciWorkflows", json=body, headers=h, timeout=30)
    print(f"{name} ->", r.status_code, r.json().get("errors") or r.json()["data"]["id"])


workflow("Build - main", "main", archive=False)
workflow("Archive - App Store", "release", archive=True)

for w in get(f"ciProducts/{product['id']}/workflows", limit=50, **{"fields[ciWorkflows]": "name,isEnabled"})["data"]:
    x = get(f"ciWorkflows/{w['id']}/xcodeVersion")["data"]["attributes"]["name"]
    print(f"  {w['attributes']['name']}: enabled={w['attributes']['isEnabled']} xcode={x}")
