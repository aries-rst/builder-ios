import os,time,json,jwt,requests
KID=os.environ["ASC_KEY_ID"];ISS=os.environ["ASC_ISSUER_ID"];KEY=os.environ["ASC_KEY"];APP="6834818658";B="https://api.appstoreconnect.apple.com"
def H():
    t=jwt.encode({"iss":ISS,"iat":int(time.time()),"exp":int(time.time())+900,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID});return {"Authorization":"Bearer "+t,"Content-Type":"application/json"}
def call(m,p,b=None):
    r=requests.request(m,B+p,headers=H(),data=json.dumps(b) if b else None)
    if r.status_code>=300: print("ERR",m,p,r.status_code,r.text[:400]); return {}
    return r.json() if r.text else {}
NOTES="""Home Builder is a free construction planner for individual house builders and small contractors. It walks the user from marking out a plot, through fence, foundation, walls, roof and finishing, to a material and cost estimate and a work schedule. Value: the user can plan a house and outbuildings on a plot, see it in 2D and 3D, and get an estimate before buying materials. Target audience: private builders, owners of plots, small building crews.

HOW TO USE (no account, no login, no demo credentials, no sample files needed; everything works offline):
1. Launch the app. The home screen lists the construction stages. Tap "Ready-made templates" and pick any plot, then "Create my project from it" (or start with an empty project).
2. Site: set plot size, tap "Add to the site" to place a house or outbuildings, drag them; pinch with two fingers to zoom, drag empty space to pan.
3. Floor plan / Roof / Fence & gates / Walls: choose building and parameters (all are simple selectors and number fields).
4. 3D view: Outside / Inside; rotate with one finger, zoom with two. The corner button opens it full screen.
5. Estimate: prices come from the built-in price list; the user can enter their own prices. Schedule shows work dates.
6. Paid feature (screen recording shows it): Settings > "Builder Premium" ($3.99 one-time, non-consumable In-App Purchase "com.ariesrst.builder.app.premium"). Premium removes ads, enables PDF/CSV export of the estimate and unlimited projects (free: 2 projects). Use the Sandbox Apple ID for purchase testing; "Restore purchase" is available in the same place.

EXTERNAL SERVICES: Apple StoreKit (In-App Purchase) only. Google AdMob SDK is included but ads are DISABLED in this version. No servers, no analytics, no user accounts, no user-generated content, no data leaves the device (projects are stored locally). Currency conversion uses fixed rates stored inside the app.

REGIONAL DIFFERENCES: none. The app works identically in all regions; the interface has 18 languages (selectable in Settings) and the user may pick the estimate currency. Only the App Store price of Premium is localized by Apple.

REGULATED / THIRD-PARTY MATERIAL: none. The app is not in a regulated industry and contains no third-party protected material. Estimates are indicative planning figures, not engineering advice.

Screen recording from a physical iPhone (launch, typical flow, Premium purchase) is attached in the Resolution Center reply."""
vs=call("GET",f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS&limit=5")["data"]
print([(x["id"],x["attributes"]["appStoreState"],x["attributes"]["versionString"]) for x in vs])
v=vs[0]["id"]
ex=call("GET",f"/v1/appStoreVersions/{v}/appStoreReviewDetail").get("data")
print("detail",ex and ex["id"])
if ex: call("PATCH",f"/v1/appStoreReviewDetails/{ex['id']}",{"data":{"type":"appStoreReviewDetails","id":ex["id"],"attributes":{"notes":NOTES}}}); print("notes updated",len(NOTES))
