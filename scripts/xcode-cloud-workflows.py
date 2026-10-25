# /// script
# dependencies = ["cryptography", "pyjwt", "requests"]
# ///
"""
Create MURDL's Xcode Cloud workflows once the Cloud product exists.

The product itself must be created once in Xcode (Product > Xcode Cloud > Create
Workflow); the API cannot do that. Everything after is scripted here, following the
KinFlash playbook: a BUILD workflow for main and an ARCHIVE workflow for the release branch
that uploads to App Store Connect. Builds run per platform (Mac scheme Murdl, iOS scheme
MurdlIOS); one archive workflow archives both, so Mac and iOS get the same build number. All pinned to Xcode 26.6 (Latest Release becomes 27 the day it ships and
resurrects ITMS-90111). Per house policy every workflow is started manually.

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


MAC = (SCHEME, "MACOS", "ANY_MAC")
IOS = ("MurdlIOS", "IOS", "ANY_IOS_DEVICE")


def workflow(name, branch, archive, targets=(MAC,)):
    if name in existing:
        print(f"exists: {name} ({existing[name]['id']})")
        return
    actions = [{
        "name": f"{'Archive' if archive else 'Build'} - {platform.replace('MACOS', 'macOS').replace('IOS', 'iOS')}",
        "actionType": "ARCHIVE" if archive else "BUILD",
        "destination": destination,
        "buildDistributionAudience": "APP_STORE_ELIGIBLE" if archive else None,
        "scheme": scheme,
        "platform": platform,
        "isRequiredToPass": True,
    } for scheme, platform, destination in targets]
    body = {"data": {"type": "ciWorkflows", "attributes": {
        "name": name,
        "description": "Created by scripts/xcode-cloud-workflows.py",
        # Manual start only (house policy): the branch is recorded in the name and chosen at start time.
        "branchStartCondition": None,
        "manualBranchStartCondition": {"source": {"isAllMatch": False, "patterns": [{"pattern": branch, "isPrefix": False}]}},
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
workflow("Build iOS - main", "main", archive=False, targets=(IOS,))
# One archive run for both platforms: every run takes the next number from the product's
# shared counter, so separate Mac and iOS runs could never share a build number. The old
# iOS-only "Archive iOS - App Store" workflow is disabled (2026-10-25).
workflow("Archive - App Store (Mac + iOS)", "release", archive=True, targets=(MAC, IOS))

for w in get(f"ciProducts/{product['id']}/workflows", limit=50, **{"fields[ciWorkflows]": "name,isEnabled"})["data"]:
    # The /xcodeVersion related link answers 403 for this key; include= returns the same record.
    x = get(f"ciWorkflows/{w['id']}", include="xcodeVersion")["included"][0]["attributes"]["name"]
    print(f"  {w['attributes']['name']}: enabled={w['attributes']['isEnabled']} xcode={x}")
