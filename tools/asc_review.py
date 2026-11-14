import os,time,json,jwt,requests
KID=os.environ["ASC_KEY_ID"];ISS=os.environ["ASC_ISSUER_ID"];KEY=os.environ["ASC_KEY"];APP="6834818658";B="https://api.appstoreconnect.apple.com"
def H():
    t=jwt.encode({"iss":ISS,"iat":int(time.time()),"exp":int(time.time())+900,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID});return {"Authorization":"Bearer "+t,"Content-Type":"application/json"}
def call(m,p,b=None):
    r=requests.request(m,B+p,headers=H(),data=json.dumps(b) if b else None)
    if r.status_code>=300: print("ERR",m,p,r.status_code,r.text[:400]); return {}
    return r.json() if r.text else {}
vs=call("GET",f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS&limit=5")["data"]
v=[x for x in vs if x["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION","DEVELOPER_REJECTED","REJECTED","METADATA_REJECTED")][0]["id"]
at={"contactFirstName":"Rustamjon","contactLastName":"Suvanqulov","contactPhone":"+998507332414","contactEmail":"games.dev4u@gmail.com","demoAccountRequired":False,
 "notes":"No sign-in is required. All features work offline. Premium ($3.99, one-time) removes ads and unlocks PDF/CSV export and unlimited projects: Settings > Premium. Ads are not shown in this version."}
ex=call("GET",f"/v1/appStoreVersions/{v}/appStoreReviewDetail").get("data")
if ex: call("PATCH",f"/v1/appStoreReviewDetails/{ex['id']}",{"data":{"type":"appStoreReviewDetails","id":ex["id"],"attributes":at}})
else: call("POST","/v1/appStoreReviewDetails",{"data":{"type":"appStoreReviewDetails","attributes":at,"relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":v}}}}})
bs=call("GET",f"/v1/builds?filter[app]={APP}&sort=-uploadedDate&limit=3")["data"]
print("builds",[(b["attributes"]["version"],b["attributes"]["processingState"]) for b in bs])
ok=[b for b in bs if b["attributes"]["processingState"]=="VALID"]
if ok: call("PATCH",f"/v1/appStoreVersions/{v}/relationships/build",{"data":{"type":"builds","id":ok[0]["id"]}}); print("build",ok[0]["attributes"]["version"])
ss=call("GET",f"/v1/appStoreVersions/{v}/appStoreVersionLocalizations")["data"]
for l in ss:
    sets=call("GET",f"/v1/appStoreVersionLocalizations/{l['id']}/appScreenshotSets")["data"]
    print(l["attributes"]["locale"],[(s["attributes"]["screenshotDisplayType"],len(call("GET",f"/v1/appScreenshotSets/{s['id']}/appScreenshots")["data"])) for s in sets])
print("DONE")
