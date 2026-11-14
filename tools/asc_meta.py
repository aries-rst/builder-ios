import os, sys, time, json, jwt, requests
KID=os.environ["ASC_KEY_ID"]; ISS=os.environ["ASC_ISSUER_ID"]; KEY=os.environ["ASC_KEY"]; APP="6834818658"; B="https://api.appstoreconnect.apple.com"
def H():
    t=jwt.encode({"iss":ISS,"iat":int(time.time()),"exp":int(time.time())+900,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID}); return {"Authorization":"Bearer "+t,"Content-Type":"application/json"}
def call(m,p,body=None):
    r=requests.request(m,B+p,headers=H(),data=json.dumps(body) if body else None)
    if r.status_code>=300: print("ERR",m,p,r.status_code,r.text[:500]); return {}
    return r.json() if r.text else {}
PRIV="https://claude.ai/artifact/UDf2ks9Dh8YXW2TC39TuuK"; SUP="mailto:games.dev4u@gmail.com"
EN=dict(desc="""Home Builder is a complete planner for building a house, from the empty plot to the finished look.

PLOT
• Draw your plot of any shape and place several buildings: house, garage, bathhouse, shed, fence and trees
• Move, rotate and resize objects with your fingers, with exact dimensions

PLAN AND 3D
• Floor plans with rooms, walls, doors, windows and stairs on every level, plus basement and attic
• Roof types with automatic valleys and hips
• Rotate, zoom and look inside your house in 3D, both outside and room by room

ESTIMATE
• Material quantities and costs from your own price list for foundation, walls, roof, finishing, engineering, fence and extras
• Work schedule (Gantt chart) for the whole build
• Choose your currency: USD by default

PREMIUM (one-time purchase)
• No ads
• Export the estimate to PDF and CSV
• Unlimited projects (free version: 2 projects)

18 languages, including right-to-left languages. Your projects are stored on your device.""",
 kw="house,build,construction,plan,estimate,cost,3D,floor plan,home,calculator,materials,roof,fence,plot",
 promo="Plan your house from plot to 3D view and get a full material estimate.",
 sub="Plot, 3D plan, cost estimate", name="Home Builder: Plan & Estimate")
RU=dict(desc="""«Строитель» — полный планировщик строительства дома: от пустого участка до готового вида.

УЧАСТОК
• Нарисуйте участок любой формы и расставьте несколько построек: дом, гараж, баню, сарай, забор и деревья
• Двигайте, поворачивайте и меняйте размеры пальцами, с точными размерами

ПЛАНИРОВКА И 3D
• Планы этажей с комнатами, стенами, дверями, окнами и лестницами на каждом уровне, плюс подвал и мансарда
• Типы крыш с автоматическими ендовами и скатами
• Вращайте, приближайте и смотрите дом в 3D снаружи и внутри, комната за комнатой

СМЕТА
• Количество и стоимость материалов по вашему прайс-листу: фундамент, стены, кровля, отделка, инженерия, забор и дополнительные работы
• График работ (диаграмма Ганта) на всю стройку
• Выбор валюты: по умолчанию доллары США

PREMIUM (разовая покупка)
• Без рекламы
• Экспорт сметы в PDF и CSV
• Неограниченное число проектов (в бесплатной версии — 2)

18 языков, включая языки с письмом справа налево. Проекты хранятся на вашем устройстве.""",
 kw="дом,стройка,строительство,план,смета,расчёт,3D,планировка,материалы,крыша,забор,участок,калькулятор",
 promo="Спланируйте дом от участка до 3D-вида и получите полную смету материалов.",
 sub="Участок, 3D-план, смета", name="Строитель: план и смета дома")
# categories
ai=call("GET",f"/v1/apps/{APP}/appInfos")["data"]
print("appInfos",[(a["id"],a["attributes"].get("appStoreState")) for a in ai])
info=[a for a in ai if a["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION","DEVELOPER_REJECTED","REJECTED","METADATA_REJECTED")] or ai
info=info[0]["id"]
call("PATCH",f"/v1/appInfos/{info}",{"data":{"type":"appInfos","id":info,"relationships":{"primaryCategory":{"data":{"type":"appCategories","id":"PRODUCTIVITY"}},"secondaryCategory":{"data":{"type":"appCategories","id":"UTILITIES"}}}}})
ls={l["attributes"]["locale"]:l["id"] for l in call("GET",f"/v1/appInfos/{info}/appInfoLocalizations")["data"]}
for loc,t in (("en-US",EN),("ru",RU)):
    at={"name":t["name"],"subtitle":t["sub"],"privacyPolicyUrl":PRIV}
    if loc in ls: call("PATCH",f"/v1/appInfoLocalizations/{ls[loc]}",{"data":{"type":"appInfoLocalizations","id":ls[loc],"attributes":at}})
    else: call("POST","/v1/appInfoLocalizations",{"data":{"type":"appInfoLocalizations","attributes":dict(at,locale=loc),"relationships":{"appInfo":{"data":{"type":"appInfos","id":info}}}}})
# version
vs=call("GET",f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS&limit=5")["data"]
v=[x for x in vs if x["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION","DEVELOPER_REJECTED","REJECTED","METADATA_REJECTED")][0]["id"]
call("PATCH",f"/v1/appStoreVersions/{v}",{"data":{"type":"appStoreVersions","id":v,"attributes":{"copyright":"2026 Rustamjon Suvanqulov"}}})
vl={l["attributes"]["locale"]:l["id"] for l in call("GET",f"/v1/appStoreVersions/{v}/appStoreVersionLocalizations")["data"]}
for loc,t in (("en-US",EN),("ru",RU)):
    at={"description":t["desc"],"keywords":t["kw"],"promotionalText":t["promo"],"supportUrl":PRIV,"marketingUrl":PRIV}
    if loc in vl: call("PATCH",f"/v1/appStoreVersionLocalizations/{vl[loc]}",{"data":{"type":"appStoreVersionLocalizations","id":vl[loc],"attributes":at}})
    else: call("POST","/v1/appStoreVersionLocalizations",{"data":{"type":"appStoreVersionLocalizations","attributes":dict(at,locale=loc),"relationships":{"appStoreVersion":{"data":{"type":"appStoreVersions","id":v}}}}})
# age rating
ar=call("GET",f"/v1/appInfos/{info}/ageRatingDeclaration").get("data")
if ar:
    none={k:"NONE" for k in ["alcoholTobaccoOrDrugUseOrReferences","contests","gamblingSimulated","horrorOrFearThemes","matureOrSuggestiveThemes","medicalOrTreatmentInformation","profanityOrCrudeHumor","sexualContentGraphicAndNudity","sexualContentOrNudity","violenceCartoonOrFantasy","violenceRealistic","violenceRealisticProlongedGraphicOrSadistic"]}
    flags={"gambling":False,"unrestrictedWebAccess":False,"lootBox":False}
    at=dict(none,**flags,gunsOrOtherWeapons="NONE")
    import re
    for _ in range(12):
        r=requests.patch(B+f"/v1/ageRatingDeclarations/{ar['id']}",headers=H(),data=json.dumps({"data":{"type":"ageRatingDeclarations","id":ar["id"],"attributes":at}}))
        if r.status_code<300: print("age ok",at); break
        m=re.search(r"attribute '(\w+)'",r.text); u=re.search(r"Unknown attribute '?(\w+)",r.text)
        print("age retry",r.status_code,r.text[:300])
        if m: at[m.group(1)]= "NONE" if m.group(1) in ("advertising","parentalControls","healthOrWellnessTopics","messagingAndChat","userGeneratedContent","ageAssurance") and False else False
        elif u and u.group(1) in at: del at[u.group(1)]
        else: break
# build
bs=call("GET",f"/v1/builds?filter[app]={APP}&sort=-uploadedDate&limit=3")["data"]
print("builds",[(b["id"],b["attributes"]["version"],b["attributes"]["processingState"]) for b in bs])
ok=[b for b in bs if b["attributes"]["processingState"]=="VALID"]
if ok: call("PATCH",f"/v1/appStoreVersions/{v}/relationships/build",{"data":{"type":"builds","id":ok[0]["id"]}})
print("DONE")
